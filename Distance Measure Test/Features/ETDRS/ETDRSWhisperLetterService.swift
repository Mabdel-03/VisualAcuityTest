import AVFoundation
import Foundation
import WhisperKit

struct ETDRSWhisperPrediction {
    let rawTranscription: String
    /// The single ETDRS letter the transcript maps to, or nil. Nil whenever a skip word is
    /// present ("okay skip" must not score K) — see `ETDRSSpokenResponseClassifier.normalizeLetter`.
    let normalizedLetter: String?
    let latency: TimeInterval
    let isFinal: Bool
    let isFiller: Bool
    let isIgnorableNonAnswer: Bool
    /// The participant said they cannot see the letter ("skip" and Whisper's mis-hearings of it,
    /// `ETDRSSpokenResponseClassifier.skipPhrases`). Mutually exclusive with `normalizedLetter`:
    /// a skip word beside a letter is neither, and the test keeps listening.
    let isSkip: Bool
    /// True for a streaming partial from WhisperKit's progress callback — the first tokens of an
    /// utterance still being decoded. Partials are display and engagement only, never scored:
    /// the first tokens of "okay skip" are "Okay" (a K correction); only the completed pass
    /// carries the whole utterance.
    let isPartial: Bool
}

enum ETDRSWhisperLetterServiceError: LocalizedError {
    case microphonePermissionDenied
    case whisperUnavailable

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to recognize spoken ETDRS letters."
        case .whisperUnavailable:
            return "WhisperKit is not ready yet."
        }
    }
}

final class ETDRSWhisperLetterService {
    static let shared = ETDRSWhisperLetterService()

    static let loadingProgressDidChangeNotification = Notification.Name("ETDRSWhisperLoadingProgressDidChange")
    static let loadingProgressKey = "progress"
    static let loadingStatusKey = "status"

    private let expectedLanguage = "en"
    private let bundledModelsFolderName = "WhisperModels"
    private let minimumRealtimeBufferSeconds: Float = 0.35
    private let realtimeTranscriptionWindowSeconds: Float = 2.4
    private let silenceThreshold: Float = 0.10
    private let minimumFinalBufferSeconds: Float = 0.15
    /// A live pass runs only once the answer has ENDED: the newest `utteranceEndQuietSeconds` of
    /// the window must read as silence. Transcribing on the first syllable hands Whisper a
    /// truncated clip, which it completes into a non-letter word.
    private let utteranceEndQuietSeconds: Float = 0.3
    /// A sound that stays continuous for this long (a long answer, a noisy room) is transcribed
    /// anyway rather than waiting for a quiet tail that may never come.
    private let maximumUtteranceSeconds: Float = 2.0
    /// How much of the newest audio a live pass that produced no answer leaves unconsumed. Equal
    /// to `utteranceEndQuietSeconds` on purpose: a quiet-tail pass fires the moment the newest
    /// 0.3 s are quiet, so exactly those blocks are known to be silent — retaining more would
    /// hand the next pass the last fragment of the utterance and re-trigger on it. On the cap
    /// path the retained tail is voice and re-triggering is the intended continuation.
    private let retainedSecondsAfterNonAnswerPass: Float = 0.3
    /// The engine is kept running between letters (a fresh AVAudioEngine takes a few hundred
    /// milliseconds to deliver its first buffer — exactly when a participant who answers as soon
    /// as the letter appears is speaking). Once the buffer has grown past this, the engine is
    /// restarted during the inter-letter gap (`suspendListening`) so memory stays bounded and the
    /// restart never lands on the arm of a letter.
    private let maximumWarmBufferSeconds: Float = 60
    /// A session whose engine reports itself running yet delivers no samples for this long after
    /// arming is restarted in place, once. Long enough for a Bluetooth headset's first buffer; an
    /// engine that reports itself stopped is restarted at the next poll tick without waiting.
    private let engineStallSeconds: TimeInterval = 1.5
    /// Upper bound on waiting for an in-flight live inference to finish before the final flush
    /// runs (`finalizeCurrentBufferIfNeeded`).
    private let maximumInferenceDrainSeconds: TimeInterval = 1.5
    private let modelName = WhisperKit.recommendedModels().default
    private let allowsDownloadedModelFallback = true

    private var whisperKit: WhisperKit?
    /// Identity of the most recent `startListening` / `stopListening` call. A start that was still
    /// awaiting permission or model readiness when a newer start or a stop arrived must not arm
    /// the engine with its (stale) prediction handler, or the newer session would be deaf.
    private var startRequestToken = 0
    /// True once WhisperKit's voice-activity check has fired for the current listening session
    /// (live loop or deadline grace). The controller only accepts an answer found by the deadline
    /// flush when voice was actually detected — a 5 s decode of room noise can hallucinate text.
    private(set) var voiceDetectedThisSession = false
    /// The most recent `startListening` still arming. Starts are serialized on it so two
    /// `startRecordingLive` calls never interleave and a superseded start only ever tears down its
    /// own engine.
    private var inFlightStart: Task<Void, Error>?
    /// True while WhisperKit's audio engine is recording, whether or not a session is armed.
    private var isEngineLive = false
    /// Index into `audioSamples` where the current session began; nothing before it is inspected.
    private var sessionStartSampleIndex = 0
    /// The token of the session most recently armed; the engine tap reads it at spawn because the
    /// engine outlives sessions.
    private var armedSessionToken = 0
    /// When the current session armed, for the engine-stall watchdog.
    private var sessionArmedAt = Date()
    private var engineRestartedThisSession = false
    /// The previous session's consumed pointer on this engine's buffer. The onset pre-roll never
    /// reaches back past it, so audio the previous letter already scored is never re-heard.
    private var preRollFloorSampleIndex = 0
    /// Told when the microphone cannot be brought back for an armed session (a restart failed);
    /// the controller ends the window instead of letting it run out as "no input".
    var onMicrophoneLost: ((Error) -> Void)?
    private var prepareTask: Task<WhisperKit, Error>?
    private var transcriptionLoop: Task<Void, Never>?
    private var onPrediction: ((ETDRSWhisperPrediction) -> Void)?
    private var isRunningInference = false
    private var lastObservedSampleCount = 0
    private var lastStatusMessage = ""
    private(set) var loadingProgress: Double = 0.0
    private(set) var loadingStatus = "Preparing speech model..."

    var isListening: Bool {
        transcriptionLoop != nil
    }

    private init() {
        // AVAudioEngine stops itself on an audio-session interruption (a call, Siri) and on an
        // input configuration change (a headset connecting). Neither tells WhisperKit. Record the
        // death — on the main queue, and without touching the engine here, so no third thread
        // ever tears an engine down — and let the next `startEngine` (a warm re-arm, or the
        // stall watchdog for a session armed at the time) replace it.
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: rawType) == .began else { return }
            self?.engineDidStopExternally(reason: "audio session interruption")
        }
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            self?.engineDidStopExternally(reason: "audio engine configuration change")
        }
    }

    private func engineDidStopExternally(reason: String) {
        guard isEngineLive else { return }
        print("[ETDRSWhisper] Microphone engine stopped (\(reason)); it will be restarted")
        isEngineLive = false
    }

    func requestMicrophonePermission() async -> Bool {
        await AudioProcessor.requestRecordPermission()
    }

    func prepareIfNeeded() async throws {
        if whisperKit != nil {
            publishStatus("Speech engine ready.", progress: 1.0)
            return
        }

        if let prepareTask {
            whisperKit = try await prepareTask.value
            return
        }

        let task = Task<WhisperKit, Error> {
            try await self.prepareWhisperKit()
        }

        prepareTask = task

        do {
            whisperKit = try await task.value
        } catch {
            prepareTask = nil
            publishStatus("WhisperKit failed to load: \(error.localizedDescription)", progress: loadingProgress)
            throw error
        }
    }

    private func prepareWhisperKit() async throws -> WhisperKit {
        publishStatus("Looking for bundled speech model...", progress: 0.05)

        if let bundledModelFolder = bundledModelFolderURL() {
            publishStatus("Using bundled WhisperKit model...", progress: 0.15)
            return try await initializeWhisperKit(
                model: nil,
                modelFolder: bundledModelFolder
            )
        }

        guard allowsDownloadedModelFallback else {
            throw NSError(
                domain: "ETDRSWhisperLetterService",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "No bundled Whisper model was found. Add a model folder under \(bundledModelsFolderName) in the app bundle."
                ]
            )
        }

        publishStatus("Bundled model not found. Downloading WhisperKit model...", progress: 0.08)
        let modelFolder = try await WhisperKit.download(variant: modelName, progressCallback: { progress in
            let percentage = Int((progress.fractionCompleted * 100).rounded())
            let mappedProgress = 0.10 + (progress.fractionCompleted * 0.50)
            self.publishStatus("Downloading WhisperKit model... \(percentage)%", progress: mappedProgress)
        })

        return try await initializeWhisperKit(
            model: modelName,
            modelFolder: modelFolder
        )
    }

    private func initializeWhisperKit(model: String?, modelFolder: URL) async throws -> WhisperKit {
        publishStatus("Initializing WhisperKit...", progress: 0.65)
        let config = WhisperKitConfig(
            model: model,
            modelFolder: modelFolder.path,
            verbose: false,
            prewarm: false,
            load: false,
            download: false
        )

        let whisperKit = try await WhisperKit(config)
        publishStatus("Prewarming WhisperKit model...", progress: 0.80)
        try await whisperKit.prewarmModels()
        publishStatus("Loading WhisperKit model...", progress: 0.95)
        try await whisperKit.loadModels()
        publishStatus("WhisperKit ready.", progress: 1.0)
        return whisperKit
    }

    private func bundledModelFolderURL() -> URL? {
        guard let bundledModelsRoot = Bundle.main.resourceURL?.appendingPathComponent(
            bundledModelsFolderName,
            isDirectory: true
        ) else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: bundledModelsRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        let exactCandidates = [
            bundledModelsRoot.appendingPathComponent("openai_whisper-\(modelName)", isDirectory: true),
            bundledModelsRoot.appendingPathComponent(modelName, isDirectory: true)
        ]

        for candidate in exactCandidates {
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
        }

        let childDirectories = (try? FileManager.default.contentsOfDirectory(
            at: bundledModelsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ))?
            .filter { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                return values?.isDirectory == true
            } ?? []

        if childDirectories.count == 1 {
            return childDirectories.first
        }

        let normalizedModelName = normalizedModelFolderToken(modelName)
        return childDirectories.first(where: { normalizedModelFolderToken($0.lastPathComponent).contains(normalizedModelName) })
    }

    private func normalizedModelFolderToken(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }

    /// Reserves the identity of the next listening session. The controller calls this
    /// synchronously at the moment it decides to listen, so a stop that follows on the main
    /// thread out-ranks the start no matter how late the start's async body actually runs — a
    /// start minted inside the async body could otherwise arm an engine nobody can stop.
    func reserveStart() -> Int {
        startRequestToken &+= 1
        return startRequestToken
    }

    /// Arms the microphone for the session `token` (from ``reserveStart()``). Returns without
    /// arming when the token has been superseded by a newer start or a stop.
    func startListening(token: Int, onPrediction: @escaping (ETDRSWhisperPrediction) -> Void) async throws {
        // A start that arrives while an earlier one is still arming waits for it to finish (arm
        // or bail) before touching the engine.
        let previous = inFlightStart
        let task = Task<Void, Error> { [weak self] in
            _ = await previous?.result
            guard let self else { return }
            try await self.performStart(token: token, onPrediction: onPrediction)
        }
        inFlightStart = task
        defer { if inFlightStart == task { inFlightStart = nil } }
        try await task.value
    }

    private func performStart(token: Int, onPrediction: @escaping (ETDRSWhisperPrediction) -> Void) async throws {
        guard await requestMicrophonePermission() else {
            throw ETDRSWhisperLetterServiceError.microphonePermissionDenied
        }

        try await prepareIfNeeded()

        // Superseded while awaiting (a newer start, or a stop): do not arm the engine with this
        // call's handler. The caller's own generation check finds the session gone.
        guard token == startRequestToken else { return }

        guard let whisperKit else {
            throw ETDRSWhisperLetterServiceError.whisperUnavailable
        }

        tearDownListening(keepEngine: true)
        self.onPrediction = onPrediction
        lastStatusMessage = ""
        isRunningInference = false
        voiceDetectedThisSession = false
        armedSessionToken = token

        // Re-arm on the engine that is already running whenever there is one: the session simply
        // starts at the current end of the buffer, so nothing recorded before this moment is ever
        // inspected, and the microphone is live the instant the letter appears. Our own flag is
        // not trusted alone — an interruption or route change stops the engine without telling
        // anyone — so the engine must actually report itself running.
        let engineRunning = (whisperKit.audioProcessor as? AudioProcessor)?.audioEngine?.isRunning == true
        if isEngineLive, engineRunning {
            sessionStartSampleIndex = whisperKit.audioProcessor.audioSamples.count
        } else {
            try startEngine(whisperKit)
        }
        lastObservedSampleCount = sessionStartSampleIndex
        sessionArmedAt = Date()
        engineRestartedThisSession = false

        // A stop that landed while the engine was starting must win: leave nothing recording.
        guard token == startRequestToken else {
            tearDownListening(keepEngine: false)
            return
        }

        transcriptionLoop = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                _ = await self.processCurrentBufferIfNeeded(isFinal: false, session: token)
                self.restartEngineIfStalled(session: token)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        // A stop that landed between the previous check and this assignment must not leave a
        // loop (and `isListening == true`) behind with no engine.
        if token != startRequestToken {
            tearDownListening(keepEngine: false)
        }
    }

    /// (Re)starts WhisperKit's live engine with a fresh buffer. Any engine still referenced —
    /// live, or dead after an interruption — is stopped first, on this thread. The tap reads the
    /// armed session at spawn because the engine outlives sessions.
    private func startEngine(_ whisperKit: WhisperKit) throws {
        isEngineLive = false
        whisperKit.audioProcessor.stopRecording()
        preRollFloorSampleIndex = 0
        try whisperKit.audioProcessor.startRecordingLive(inputDeviceID: nil) { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                // A pass belongs to whichever session is armed when it starts; audio before that
                // session's start index is never read.
                _ = await self.processCurrentBufferIfNeeded(isFinal: false, session: self.armedSessionToken)
            }
        }
        isEngineLive = true
        sessionStartSampleIndex = 0
    }

    /// A session whose engine has delivered no samples since arming is on a dead engine — an
    /// interruption or route change stopped it, or a warm engine died in the gap. Restart it in
    /// place, once: at the next poll tick when the engine reports itself stopped, or after
    /// `engineStallSeconds` when it claims to run but nothing arrives. A restart that fails is
    /// reported through `onMicrophoneLost` rather than left to run out as "no input".
    private func restartEngineIfStalled(session: Int) {
        guard session == startRequestToken, isListening, let whisperKit,
              !engineRestartedThisSession,
              whisperKit.audioProcessor.audioSamples.count <= sessionStartSampleIndex else { return }
        let engineReportsRunning = (whisperKit.audioProcessor as? AudioProcessor)?.audioEngine?.isRunning == true
        guard !engineReportsRunning || Date().timeIntervalSince(sessionArmedAt) >= engineStallSeconds else { return }

        engineRestartedThisSession = true
        print("[ETDRSWhisper] No audio since arming — restarting the microphone engine in place")
        do {
            try startEngine(whisperKit)
            // A stop that landed while the engine was starting must win, exactly as in performStart.
            guard session == startRequestToken, isListening else {
                tearDownListening(keepEngine: false)
                return
            }
            lastObservedSampleCount = 0
            sessionArmedAt = Date()
        } catch {
            publishStatus("Microphone restart failed: \(error.localizedDescription)")
            guard session == startRequestToken, isListening else { return }
            onMicrophoneLost?(error)
        }
    }

    /// Ends the session and releases the microphone: the engine stops and the audio session is
    /// free for playback. For pauses, the app's own speech, and leaving the screen.
    func stopListening() {
        startRequestToken &+= 1
        tearDownListening(keepEngine: false)
    }

    /// Ends the session but keeps the microphone running, so the next `startListening` arms
    /// instantly on the live engine. For the moment between letters; nothing recorded before the
    /// next session's start is ever inspected.
    func suspendListening() {
        startRequestToken &+= 1
        preRollFloorSampleIndex = max(lastObservedSampleCount, sessionStartSampleIndex)
        tearDownListening(keepEngine: true)
        // Bound memory: once the buffer has grown past the cap, restart the engine NOW, during
        // the inter-letter gap, so it is warm again before the next letter appears.
        if let whisperKit, isEngineLive,
           Float(whisperKit.audioProcessor.audioSamples.count) / Float(WhisperKit.sampleRate) >= maximumWarmBufferSeconds {
            try? startEngine(whisperKit)
        }
    }

    /// True while the engine is running with no session armed (between letters).
    var isMicrophoneWarm: Bool {
        isEngineLive && transcriptionLoop == nil
    }

    /// Clears session state; stops the engine too unless `keepEngine`.
    private func tearDownListening(keepEngine: Bool) {
        transcriptionLoop?.cancel()
        transcriptionLoop = nil
        onPrediction = nil
        isRunningInference = false
        if !keepEngine {
            whisperKit?.audioProcessor.stopRecording()
            isEngineLive = false
            sessionStartSampleIndex = 0
        }
        lastObservedSampleCount = sessionStartSampleIndex
    }

    /// Bounded wait for an utterance that is still in progress: while the newest audio reads as
    /// voice, keep waiting (100 ms steps, at most `maxGraceSeconds`). The controller calls this at
    /// the no-input deadline so a participant who started answering at 4.7 s is transcribed whole
    /// rather than truncated to an onset and scored as "no input".
    func waitForUtteranceToEnd(maxGraceSeconds: TimeInterval = 1.0) async {
        guard whisperKit != nil, isListening else { return }
        let session = startRequestToken

        var waited: TimeInterval = 0
        while waited < maxGraceSeconds, isListening, session == startRequestToken, tailHasVoice() {
            voiceDetectedThisSession = true
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 0.1
        }
    }

    /// Whether the newest `utteranceEndQuietSeconds` of this session's audio read as voice.
    private func tailHasVoice() -> Bool {
        guard let whisperKit else { return false }
        let samples = whisperKit.audioProcessor.audioSamples
        let voice = sessionVoiceAnalysis(in: samples, sessionStart: min(sessionStartSampleIndex, samples.count)).voice
        return voice.suffix(quietTailBlocks).contains(true)
    }

    private var quietTailBlocks: Int {
        max(1, Int((utteranceEndQuietSeconds * Float(WhisperKit.sampleRate)).rounded()) / ETDRSListeningBufferRules.energyBlockSamples)
    }

    private var maximumUtteranceBlocks: Int {
        max(1, Int((maximumUtteranceSeconds * Float(WhisperKit.sampleRate)).rounded()) / ETDRSListeningBufferRules.energyBlockSamples)
    }

    /// Voice activity per 100 ms block over the current session's audio, from our own energies
    /// (`ETDRSListeningBufferRules`). Blocks recorded shortly before the session started (the
    /// warm engine has them) serve as the silence reference, so an answer already under way when
    /// the session arms still stands out against the quiet gap that preceded it; `preRollBlocks`
    /// is how many of those pre-session blocks are voice contiguous with the session's first
    /// block, so the first pass can start its transcription window there and Whisper hears the
    /// onset rather than a clip that begins mid-word.
    private func sessionVoiceAnalysis(in samples: ContiguousArray<Float>, sessionStart: Int) -> (voice: [Bool], preRollBlocks: Int) {
        let blockSamples = ETDRSListeningBufferRules.energyBlockSamples
        let referenceBlocks = min(ETDRSListeningBufferRules.referenceWindowBlocks, sessionStart / blockSamples)
        let analysisStart = sessionStart - referenceBlocks * blockSamples
        let energies = ETDRSListeningBufferRules.blockEnergies(samples[analysisStart..<samples.count])
        let allVoice = ETDRSListeningBufferRules.voiceBlocks(
            relativeEnergies: ETDRSListeningBufferRules.relativeEnergies(blockEnergies: energies),
            silenceThreshold: silenceThreshold
        )
        let voice = Array(allVoice.dropFirst(referenceBlocks))
        // Never reach back past what the previous letter already consumed.
        let floorBlocks = max(0, (sessionStart - min(preRollFloorSampleIndex, sessionStart)) / blockSamples)
        let preRoll = min(
            floorBlocks,
            ETDRSListeningBufferRules.preRollBlocks(
                preSessionVoice: Array(allVoice.prefix(referenceBlocks)),
                sessionVoice: voice
            )
        )
        return (voice, preRoll)
    }

    /// What the deadline flush found.
    enum FinalFlushResult {
        /// The pending audio was transcribed; the controller classifies it.
        case prediction(ETDRSWhisperPrediction)
        /// Nothing pending worth inspecting, or listening has already stopped.
        case silence
        /// The audio could not be inspected yet — a live inference still holds it (its answer
        /// arrives through `onPrediction`) or the decode failed transiently. Ask again shortly
        /// rather than call the window silent.
        case pending
    }

    /// One final transcription of everything not yet consumed — the whole listening window when
    /// no live pass produced text (an empty live pass consumes all but
    /// `retainedSecondsAfterNonAnswerPass`). Returns `.silence` when there is too little pending audio
    /// to inspect (< `minimumFinalBufferSeconds`) or listening has already stopped, and `.pending`
    /// when the audio could not be inspected yet.
    ///
    /// Waits (bounded) for a live inference that may be running on the participant's answer right
    /// now: without the wait the final pass bounced off the `isRunningInference` guard and
    /// reported nothing — which the controller scores as a miss. If that live pass yields an
    /// answer it reaches `onPrediction` normally and the controller scores it instead.
    func finalizeCurrentBufferIfNeeded() async -> FinalFlushResult {
        guard let whisperKit else { return .silence }
        let session = startRequestToken

        var waited: TimeInterval = 0
        while isRunningInference, waited < maximumInferenceDrainSeconds {
            try? await Task.sleep(nanoseconds: 50_000_000)
            waited += 0.05
        }
        guard isListening, session == startRequestToken else { return .silence }
        if isRunningInference { return .pending }

        let pendingSampleCount = whisperKit.audioProcessor.audioSamples.count - lastObservedSampleCount
        let pendingSeconds = Float(max(pendingSampleCount, 0)) / Float(WhisperKit.sampleRate)
        guard pendingSeconds >= minimumFinalBufferSeconds else { return .silence }

        if let prediction = await processCurrentBufferIfNeeded(isFinal: true, session: session) {
            return .prediction(prediction)
        }
        // nil with the audio still unconsumed means the pass bounced (a live pass took the
        // inference slot first) or the decode threw — not that the window was quiet.
        guard isListening, session == startRequestToken else { return .silence }
        let stillPending = whisperKit.audioProcessor.audioSamples.count - lastObservedSampleCount
        return Float(max(stillPending, 0)) / Float(WhisperKit.sampleRate) >= minimumFinalBufferSeconds
            ? .pending
            : .silence
    }

    /// What a pass needs from the shared buffer, taken in one go so the buffer reference is
    /// released before inference runs (a held reference forces the engine tap to copy the buffer
    /// on every append).
    private struct SessionSnapshot {
        let totalCount: Int
        let consumed: Int
        let voice: [Bool]
        let buffer: [Float]
    }

    private func snapshotSession(isFinal: Bool, whisperKit: WhisperKit) -> SessionSnapshot? {
        let samples = whisperKit.audioProcessor.audioSamples
        let totalCount = samples.count
        let sessionStart = min(sessionStartSampleIndex, totalCount)
        guard totalCount > sessionStart else {
            publishStatus("Waiting for microphone audio...")
            return nil
        }

        let consumed = min(max(lastObservedSampleCount, sessionStart), totalCount)
        let newBufferSeconds = Float(totalCount - consumed) / Float(WhisperKit.sampleRate)
        if !isFinal, newBufferSeconds < minimumRealtimeBufferSeconds {
            publishStatus("Listening for your spoken letter...")
            return nil
        }

        // Voice activity from our own per-100 ms energies rather than WhisperKit's trace: that
        // trace normalizes against the quietest recent buffer, so a digital-zero buffer at engine
        // start-up makes room noise read as voice for two seconds, and its live check looks at the
        // OLDEST part of a span, which fires on the first syllable of an answer.
        let analysis = sessionVoiceAnalysis(in: samples, sessionStart: sessionStart)
        let voice = analysis.voice

        if !isFinal {
            // Transcribe once the answer has ENDED — voice somewhere in the unconsumed span and a
            // quiet tail — so Whisper sees the whole utterance, never a truncated first syllable
            // that it would complete into a non-letter word. A sound that stays continuous for
            // `maximumUtteranceSeconds` is transcribed anyway.
            let unconsumedFromBlock = (consumed - sessionStart) / ETDRSListeningBufferRules.energyBlockSamples
            guard ETDRSListeningBufferRules.shouldRunLivePass(
                voice: voice,
                unconsumedFromBlock: unconsumedFromBlock,
                quietTailBlocks: quietTailBlocks,
                maximumUtteranceBlocks: maximumUtteranceBlocks
            ) else {
                publishStatus("Listening for your spoken letter...")
                return nil
            }
        }

        let maxWindowSamples = Int(realtimeTranscriptionWindowSeconds * Float(WhisperKit.sampleRate))
        // An answer already under way when the session armed: the first pass reaches back over
        // the contiguous pre-session voice (the warm engine recorded it) so Whisper hears the
        // onset. The consumed pointer itself never moves before the session start.
        let preRollSamples = consumed == sessionStart
            ? analysis.preRollBlocks * ETDRSListeningBufferRules.energyBlockSamples
            : 0
        // Live passes look at the last rolling window past the consumed pointer. The final flush
        // re-examines everything not yet consumed — the whole window when no live pass ran — so a
        // quiet early answer that never crossed the live voice gate is heard before the trial is
        // called silent.
        let bufferStartIndex = isFinal
            ? consumed - preRollSamples
            : max(consumed - preRollSamples, totalCount - maxWindowSamples)
        return SessionSnapshot(
            totalCount: totalCount,
            consumed: consumed,
            voice: voice,
            buffer: Array(samples[bufferStartIndex..<totalCount])
        )
    }

    private func processCurrentBufferIfNeeded(isFinal: Bool, session: Int) async -> ETDRSWhisperPrediction? {
        // `session` is bound where the pass was spawned (poll loop, deadline flush) or read at
        // spawn from the armed session (engine tap). A pass that runs after its session ended —
        // or before the next one has armed — must not touch state.
        guard session == startRequestToken, isListening, !isRunningInference, let whisperKit else { return nil }
        guard let snapshot = snapshotSession(isFinal: isFinal, whisperKit: whisperKit) else { return nil }

        if !isFinal {
            voiceDetectedThisSession = true
        } else if ETDRSListeningBufferRules.windowHadVoice(voice: snapshot.voice) {
            // Whole-window voice presence for the controller's hallucination gate: a 5 s decode of
            // room noise can hallucinate text, so an answer found only by the deadline flush counts
            // only if a speech-length sound actually occurred in the window.
            voiceDetectedThisSession = true
        }

        isRunningInference = true
        // A pass that outlives its session must not clear the NEXT session's flag.
        defer { if session == startRequestToken { isRunningInference = false } }
        let recentBufferSeconds = Float(snapshot.buffer.count) / Float(WhisperKit.sampleRate)
        publishStatus(String(format: "Running WhisperKit on %.2fs recent audio...", recentBufferSeconds))

        do {
            let prediction = try await transcribe(snapshot.buffer, isFinal: isFinal, session: session)
            // The session may have been stopped or replaced while inference ran. This pass's
            // buffer count describes a buffer that may since have been emptied; writing it into
            // the new session's consumed pointer would leave that window deaf and score a false
            // miss.
            guard session == startRequestToken else { return nil }

            // An answer consumes everything the pass saw; anything else keeps the newest
            // `retainedSecondsAfterNonAnswerPass` so an utterance straddling the pass boundary
            // keeps its onset. The retained tail was quiet when the pass ran, so it cannot by
            // itself trigger another pass.
            lastObservedSampleCount = ETDRSListeningBufferRules.consumedSampleCount(
                current: lastObservedSampleCount,
                bufferCount: snapshot.totalCount,
                isFinal: isFinal,
                producedAnswer: prediction.normalizedLetter != nil || prediction.isSkip,
                retainedSamples: Int(retainedSecondsAfterNonAnswerPass * Float(WhisperKit.sampleRate))
            )

            if !isFinal {
                onPrediction?(prediction)
            }

            return prediction
        } catch {
            guard session == startRequestToken else { return nil }
            publishStatus("WhisperKit transcription error: \(error.localizedDescription)")
            return nil
        }
    }

    private func transcribe(_ audioSamples: [Float], isFinal: Bool, session: Int) async throws -> ETDRSWhisperPrediction {
        guard let whisperKit else {
            throw ETDRSWhisperLetterServiceError.whisperUnavailable
        }

        let decodeOptions = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: expectedLanguage,
            temperature: 0,
            sampleLength: 8,
            topK: 1,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            wordTimestamps: false,
            promptTokens: nil,
            compressionRatioThreshold: nil,
            logProbThreshold: nil,
            firstTokenLogProbThreshold: nil,
            noSpeechThreshold: nil,
            concurrentWorkerCount: 1,
            chunkingStrategy: ChunkingStrategy.none
        )

        let start = CFAbsoluteTimeGetCurrent()
        let result = try await whisperKit.transcribe(audioArray: audioSamples, decodeOptions: decodeOptions) { [weak self] progress in
            guard let self else { return nil }

            let liveText = progress.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !liveText.isEmpty, !isFinal, !self.looksLikePromptEcho(liveText),
                  session == self.startRequestToken else { return nil }
            print("[ETDRSWhisper] Partial transcription: \(liveText)")

            let prediction = self.makePrediction(
                rawText: liveText,
                latency: CFAbsoluteTimeGetCurrent() - start,
                isFinal: false,
                isPartial: true
            )
            self.onPrediction?(prediction)
            return nil
        }.first

        let latency = CFAbsoluteTimeGetCurrent() - start
        let rawText = result?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("[ETDRSWhisper] \(isFinal ? "Final" : "Completed") transcription: \(rawText.isEmpty ? "<empty>" : rawText)")

        return makePrediction(rawText: rawText, latency: latency, isFinal: isFinal, isPartial: false)
    }

    private func makePrediction(rawText: String, latency: TimeInterval, isFinal: Bool, isPartial: Bool) -> ETDRSWhisperPrediction {
        ETDRSWhisperPrediction(
            rawTranscription: rawText,
            normalizedLetter: ETDRSSpokenResponseClassifier.normalizeLetter(from: rawText),
            latency: latency,
            isFinal: isFinal,
            isFiller: ETDRSSpokenResponseClassifier.isFillerPhrase(rawText),
            isIgnorableNonAnswer: ETDRSSpokenResponseClassifier.isIgnorableNonAnswerPhrase(rawText),
            isSkip: ETDRSSpokenResponseClassifier.isSkipPhrase(rawText),
            isPartial: isPartial
        )
    }

    private func looksLikePromptEcho(_ text: String) -> Bool {
        let cleaned = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.contains("the speaker will say exactly one english alphabet letter")
            || cleaned.contains("return only that single uppercase letter")
    }

    private func publishStatus(_ message: String, progress: Double? = nil) {
        if let progress {
            loadingProgress = min(max(progress, 0.0), 1.0)
        }

        loadingStatus = message
        guard message != lastStatusMessage || progress != nil else { return }
        lastStatusMessage = message
        print("[ETDRSWhisper] \(message)")

        let userInfo: [String: Any] = [
            Self.loadingProgressKey: loadingProgress,
            Self.loadingStatusKey: loadingStatus
        ]

        Task { @MainActor in
            NotificationCenter.default.post(
                name: Self.loadingProgressDidChangeNotification,
                object: self,
                userInfo: userInfo
            )
        }
    }
}

// MARK: - Spoken response classification

/// The pure text rules behind spoken-letter recognition: the vocabulary tables and the
/// classification of a Whisper transcript into a letter, a spoken "skip", filler, or one of
/// Whisper's silence hallucinations. Kept free of WhisperKit state so the rules are unit-testable
/// (`@testable import Distance_Measure_Test`); `ETDRSWhisperLetterService` delegates here.
enum ETDRSSpokenResponseClassifier {
    static let recognizedLetters: Set<String> = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init))

    /// "um", "uh" — the participant is engaged but has not answered yet. Ignored while listening;
    /// at the no-input deadline it earns a retry rather than a miss.
    static let fillerPhrases: Set<String> = [
        "UH", "UHH", "UHHH", "UM", "UMM", "UMMM",
        "ER", "ERR", "ERM", "AH", "AHH", "AHHH",
        "EH", "EHH", "HM", "HMM", "HMMM", "MM",
        "MMM", "MHM", "HUH", "WAIT"
    ]

    /// Whisper's classic silence hallucinations. Never engagement: a window that produced only
    /// these is a silent window. The second group is the text Whisper invents on silence
    /// (Myotect `WhisperTranscriptFilter.nonAnswerExact`); "YOU" is also the U pronunciation, but
    /// U is not an ETDRS letter and a silent window must never score as an answer.
    static let ignorableNonAnswerPhrases: Set<String> = [
        "BLANK", "BLANK AUDIO", "BLANKAUDIO", "EMPTY",
        "NO AUDIO", "NO SPEECH", "NO SOUND", "SILENCE",
        "SILENT", "SILENT AUDIO", "SILENTAUDIO", "PAUSE",
        "NOISE", "MUSIC", "BACKGROUND NOISE", "BACKGROUND", "STATIC",
        "YOU", "THANK YOU", "THANKS FOR WATCHING", "THANK YOU FOR WATCHING", "BYE", "THE END"
    ]

    static let letterPronunciationMap: [String: String] = [
        "A": "A", "AY": "A", "HEY": "A",
        "B": "B", "BEE": "B", "BE": "B",
        "C": "C", "CEE": "C", "SEA": "C", "SEE": "C",
        "D": "D", "DEE": "D", "DI": "D",
        "E": "E", "EE": "E",
        "F": "F", "EF": "F", "EFF": "F",
        "G": "G", "GEE": "G",
        "H": "H", "AITCH": "H", "EACH": "H", "HATCH": "H", "ATCH": "H",
        "I": "I", "EYE": "I", "AI": "I",
        "J": "J", "JAY": "J",
        "K": "K", "KAY": "K", "KEY": "K", "OKAY": "K",
        "L": "L", "EL": "L", "ELL": "L",
        "M": "M", "EM": "M",
        "N": "N", "EN": "N", "ENN": "N", "AN": "N", "AND": "N", "NAND": "N",
        "O": "O", "OH": "O",
        "P": "P", "PEA": "P", "PEE": "P", "PI": "P", "PEACE": "P",
        "Q": "Q", "CUE": "Q", "QUEUE": "Q",
        "R": "R", "ARE": "R", "AR": "R", "ARR": "R", "OUR": "R",
        "S": "S", "ESS": "S",
        "T": "T", "TEE": "T", "TEA": "T",
        "U": "U", "YOU": "U", "YEW": "U", "YOO": "U",
        "V": "V", "VEE": "V", "VI": "V", "VIE": "V",
        "W": "W", "DOUBLE U": "W", "DOUBLE YOU": "W", "DOUBLEYOU": "W",
        "X": "X", "EX": "X",
        "Y": "Y", "WHY": "Y",
        "Z": "Z", "ZEE": "Z", "ZED": "Z", "ZI": "Z"
    ]

    static let misidentificationMap: [String: String] = [
        "CEE": "C", "SEA": "C", "SEE": "C",
        "DEE": "D", "DI": "D",
        "EF": "F", "EFF": "F", "EARTH": "F",
        "AITCH": "H", "EACH": "H", "HATCH": "H", "ATCH": "H",
        "KAY": "K", "KEY": "K", "OKAY": "K",
        "EN": "N", "ENN": "N", "AN": "N", "AND": "N", "NAND": "N","IN": "N",
        "PEA": "P", "PEE": "P", "PI": "P", "PEACE": "P",
        "ARE": "R", "AR": "R", "ARR": "R", "OUR": "R", "OR": "R",
        "YOU": "U", "YEW": "U", "YOO": "U",
        "VEE": "V", "VI": "V", "VIE": "V",
        "ZEE": "Z", "ZED": "Z", "ZI": "Z",
        "EXCELLENT":"X", "EGGS":"X","EXCEL":"X","EXACTLY":"X"

    ]

    /// Spoken "skip" and the whole-word forms Whisper produces for it — tier 1, ported verbatim
    /// from Myotect's `LetterMappingTable.skipPhrases`. A skip resolves the trial as a MISS, so
    /// the list is deliberately conservative: a false skip costs a scored letter, a missed skip
    /// only keeps the microphone open. Entries are already normalized (uppercase, letters only)
    /// and must never collide with a letter table or the filler / non-answer sets — pinned by
    /// `ETDRSSpokenResponseTests.testSkipPhrasesNeverCollideWithLetterTables`.
    ///
    /// Deliberately NOT included until device logs justify them ("tier 2"): SKI, KIP, SKIT, SKID,
    /// SKIFF. Each is a short real word Whisper could also produce by fusing an "S… K"
    /// self-correction, which today keeps listening and would become a scored miss. SKYPE is the
    /// tier-1 entry to watch for the same reason.
    static let skipPhrases: Set<String> = [
        "SKIP", "SKIPP", "SKIIP", "SKIPPED", "SKIPS", "SKIPPING", "SKIPPY", "SKYPE",
        "SCIP", "SKEP", "SKUP"
    ]

    /// Uppercases and collapses every non-letter run to a single space, so "C-D" becomes the two
    /// tokens "C D" and a bare "." becomes "".
    static func cleanedTranscriptToken(from transcription: String) -> String {
        let spaced = transcription
            .uppercased()
            .replacingOccurrences(of: "[^A-Z]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return spaced.split(separator: " ").joined(separator: " ")
    }

    /// The single letter a transcript maps to, or nil. The original rules, unchanged — whole-string
    /// lookup, then the LAST mapped token, then the last single-letter token, then a single compact
    /// letter — with one addition: any skip word in the utterance ("okay skip", "c skip") returns
    /// nil, so a mixed utterance never scores a letter. "OKAY" is a K correction; without this
    /// rule "okay skip" scored K.
    static func normalizeLetter(from transcription: String) -> String? {
        let cleaned = cleanedTranscriptToken(from: transcription)
        guard !cleaned.isEmpty, !fillerPhrases.contains(cleaned) else { return nil }
        // Silence hallucinations ("Thank you.", "you") map to nothing.
        guard !isIgnorableNonAnswerPhrase(cleaned) else { return nil }

        if let mapped = letterPronunciationMap[cleaned] ?? misidentificationMap[cleaned],
           recognizedLetters.contains(mapped) {
            return mapped
        }

        let tokens = meaningfulTokens(in: cleaned)
        if tokens.contains(where: { skipPhrases.contains($0) }) {
            return nil
        }
        if tokens.isEmpty {
            return nil
        }

        if let mappedToken = tokens.compactMap({ letterPronunciationMap[$0] ?? misidentificationMap[$0] }).last,
           recognizedLetters.contains(mappedToken) {
            return mappedToken
        }

        if let singleLetterToken = tokens.last(where: { $0.count == 1 }),
           recognizedLetters.contains(singleLetterToken) {
            return singleLetterToken
        }

        let compactLetters = cleaned.replacingOccurrences(of: " ", with: "")
        if compactLetters.count == 1, recognizedLetters.contains(compactLetters) {
            return compactLetters
        }

        return nil
    }

    /// The tokens that carry meaning for classification: filler and the single-word silence
    /// hallucinations are dropped, so "skip thank you" is a skip and "C, thank you" is C rather
    /// than the U a trailing "you" would otherwise map to.
    static func meaningfulTokens(in cleaned: String) -> [String] {
        cleaned.split(separator: " ").map(String.init).filter {
            !fillerPhrases.contains($0) && !ignorableNonAnswerPhrases.contains($0)
        }
    }

    /// Whether a single token would be read as a letter by `normalizeLetter`'s token rules.
    static func tokenMapsToLetter(_ token: String) -> Bool {
        if let mapped = letterPronunciationMap[token] ?? misidentificationMap[token],
           recognizedLetters.contains(mapped) {
            return true
        }
        return token.count == 1 && recognizedLetters.contains(token)
    }

    /// True when the participant said "skip": the whole transcript is a skip word, or a skip word
    /// appears with no letter beside it ("um skip", "skip it", "please skip"). A skip word next to
    /// a letter ("c skip"; "okay skip", because OKAY is a K correction) is neither a skip nor a
    /// letter — the test keeps listening rather than guess.
    static func isSkipPhrase(_ transcription: String) -> Bool {
        let cleaned = cleanedTranscriptToken(from: transcription)
        guard !cleaned.isEmpty else { return false }
        if skipPhrases.contains(cleaned) { return true }

        let tokens = meaningfulTokens(in: cleaned)
        guard tokens.contains(where: { skipPhrases.contains($0) }) else { return false }
        return !tokens.contains(where: tokenMapsToLetter)
    }

    static func isFillerPhrase(_ transcription: String) -> Bool {
        let cleaned = cleanedTranscriptToken(from: transcription)
        guard !cleaned.isEmpty else { return false }
        if fillerPhrases.contains(cleaned) { return true }

        let tokens = cleaned.split(separator: " ").map(String.init)
        return !tokens.isEmpty && tokens.allSatisfy { fillerPhrases.contains($0) }
    }

    static func isIgnorableNonAnswerPhrase(_ transcription: String) -> Bool {
        let cleaned = cleanedTranscriptToken(from: transcription)
        let compact = cleaned.replacingOccurrences(of: " ", with: "")
        if cleaned.isEmpty { return true }
        if ignorableNonAnswerPhrases.contains(cleaned) || ignorableNonAnswerPhrases.contains(compact) {
            return true
        }

        let tokens = cleaned.split(separator: " ").map(String.init)
        return !tokens.isEmpty && tokens.allSatisfy { ignorableNonAnswerPhrases.contains($0) }
    }
}

// MARK: - Listening buffer bookkeeping

/// Pure bookkeeping for the live transcription buffer, kept off the service so it is testable.
enum ETDRSListeningBufferRules {
    /// 100 ms of 16 kHz audio — the granularity of the voice-activity trace.
    static let energyBlockSamples = 1600
    /// How many previous blocks (2 s) the silence reference is taken from.
    static let referenceWindowBlocks = 20

    /// Per-block RMS energy (0…1); the trailing partial block is dropped.
    static func blockEnergies(_ samples: ArraySlice<Float>) -> [Float] {
        let blockCount = samples.count / energyBlockSamples
        guard blockCount > 0 else { return [] }
        var energies: [Float] = []
        energies.reserveCapacity(blockCount)
        samples.withUnsafeBufferPointer { pointer in
            for block in 0..<blockCount {
                let base = block * energyBlockSamples
                var sum: Float = 0
                for offset in 0..<energyBlockSamples {
                    let value = pointer[base + offset]
                    sum += value * value
                }
                energies.append((sum / Float(energyBlockSamples)).squareRoot())
            }
        }
        return energies
    }

    /// WhisperKit's normalization — each block in dB relative to the quietest of the previous
    /// `referenceWindow` blocks, rescaled so the reference is 0 and full scale is 1 — with two
    /// guards: a block with no valid reference (the first block, or nothing but near-silence
    /// behind it) is 0, and blocks below `minimumReference` (-80 dBFS; real room floors sit well
    /// above it) are never used as the reference, because a zero or ramp-in buffer at engine
    /// start-up would otherwise make room noise read as voice for a whole window.
    static func relativeEnergies(
        blockEnergies: [Float],
        referenceWindow: Int = referenceWindowBlocks,
        minimumReference: Float = 1e-4
    ) -> [Float] {
        var result: [Float] = []
        result.reserveCapacity(blockEnergies.count)
        for (index, energy) in blockEnergies.enumerated() {
            let windowStart = max(0, index - referenceWindow)
            let reference = blockEnergies[windowStart..<index].filter { $0 >= minimumReference }.min()
            guard let reference, energy > 0 else {
                result.append(0)
                continue
            }
            let dbReference = 20 * log10(reference)
            guard dbReference < 0 else {
                result.append(0)
                continue
            }
            let dbEnergy = 20 * log10(energy)
            let normalized = (dbEnergy - dbReference) / (0 - dbReference)
            result.append(max(0, min(normalized, 1)))
        }
        return result
    }

    static func voiceBlocks(relativeEnergies: [Float], silenceThreshold: Float) -> [Bool] {
        relativeEnergies.map { $0 > silenceThreshold }
    }

    /// Whether a live pass should transcribe now: voice somewhere in the unconsumed span, and
    /// either the utterance has ended (the newest `quietTailBlocks` are quiet) or voice has been
    /// continuous for `maximumUtteranceBlocks` — a long answer, or a noisy room, is transcribed
    /// anyway rather than waiting forever for a quiet tail.
    static func shouldRunLivePass(
        voice: [Bool],
        unconsumedFromBlock: Int,
        quietTailBlocks: Int,
        maximumUtteranceBlocks: Int
    ) -> Bool {
        let from = max(0, min(unconsumedFromBlock, voice.count))
        guard let firstVoice = voice[from...].firstIndex(of: true) else { return false }
        let stillSpeaking = voice.suffix(max(1, quietTailBlocks)).contains(true)
        if !stillSpeaking { return true }
        return voice.count - firstVoice >= max(1, maximumUtteranceBlocks)
    }

    /// How many pre-session blocks the first transcription window should reach back over: the
    /// run of voice immediately before the session that continues into its first block, i.e. an
    /// answer already under way when the session armed. Zero when the session did not start in
    /// voice.
    static func preRollBlocks(preSessionVoice: [Bool], sessionVoice: [Bool]) -> Int {
        guard sessionVoice.first == true else { return 0 }
        var count = 0
        for isVoice in preSessionVoice.reversed() {
            guard isVoice else { break }
            count += 1
        }
        return count
    }

    /// Whether a session's trace holds a speech-length sound: two CONSECUTIVE voice blocks (a
    /// spoken letter spans several; a single click does not).
    static func windowHadVoice(voice: [Bool]) -> Bool {
        zip(voice, voice.dropFirst()).contains { $0 && $1 }
    }

    /// Where the consumed pointer moves after a pass. A pass that produced an answer, and the
    /// final flush, consume everything they saw. Any other live pass consumes all but the newest
    /// `retainedSamples`, so an utterance straddling the pass boundary keeps its onset. Never
    /// moves backwards.
    static func consumedSampleCount(
        current: Int,
        bufferCount: Int,
        isFinal: Bool,
        producedAnswer: Bool,
        retainedSamples: Int
    ) -> Int {
        if isFinal || producedAnswer {
            return max(current, bufferCount)
        }
        return max(current, bufferCount - max(0, retainedSamples))
    }
}
