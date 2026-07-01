import Foundation
import WhisperKit

struct ETDRSWhisperPrediction {
    let rawTranscription: String
    let normalizedLetter: String?
    let latency: TimeInterval
    let isFinal: Bool
    let isFiller: Bool
    let isIgnorableNonAnswer: Bool
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
    private let modelName = WhisperKit.recommendedModels().default
    private let allowsDownloadedModelFallback = true
    private let recognizedLetters: Set<String> = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init))
    private let fillerPhrases: Set<String> = [
        "UH", "UHH", "UHHH", "UM", "UMM", "UMMM",
        "ER", "ERR", "ERM", "AH", "AHH", "AHHH",
        "EH", "EHH", "HM", "HMM", "HMMM", "MM",
        "MMM", "MHM", "HUH"
    ]
    private let ignorableNonAnswerPhrases: Set<String> = [
        "BLANK", "BLANK AUDIO", "BLANKAUDIO", "EMPTY",
        "NO AUDIO", "NO SPEECH", "NO SOUND", "SILENCE",
        "SILENT", "SILENT AUDIO", "SILENTAUDIO", "PAUSE",
        "NOISE", "MUSIC", "BACKGROUND NOISE", "BACKGROUND", "STATIC"
    ]
    private let letterPronunciationMap: [String: String] = [
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
    private let misidentificationMap: [String: String] = [
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
        "ZEE": "Z", "ZED": "Z", "ZI": "Z"
    ]

    private var whisperKit: WhisperKit?
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

    func startListening(onPrediction: @escaping (ETDRSWhisperPrediction) -> Void) async throws {
        guard await requestMicrophonePermission() else {
            throw ETDRSWhisperLetterServiceError.microphonePermissionDenied
        }

        try await prepareIfNeeded()

        guard let whisperKit else {
            throw ETDRSWhisperLetterServiceError.whisperUnavailable
        }

        stopListening()
        self.onPrediction = onPrediction
        lastObservedSampleCount = 0
        lastStatusMessage = ""
        isRunningInference = false

        try whisperKit.audioProcessor.startRecordingLive(inputDeviceID: nil) { [weak self] _ in
            Task { [weak self] in
                await self?.processCurrentBufferIfNeeded(isFinal: false)
            }
        }

        transcriptionLoop = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                _ = await self.processCurrentBufferIfNeeded(isFinal: false)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    func stopListening() {
        transcriptionLoop?.cancel()
        transcriptionLoop = nil
        whisperKit?.audioProcessor.stopRecording()
        onPrediction = nil
        isRunningInference = false
        lastObservedSampleCount = 0
    }

    func finalizeCurrentBufferIfNeeded() async -> ETDRSWhisperPrediction? {
        guard let whisperKit else { return nil }

        let pendingSampleCount = whisperKit.audioProcessor.audioSamples.count - lastObservedSampleCount
        let pendingSeconds = Float(max(pendingSampleCount, 0)) / Float(WhisperKit.sampleRate)
        guard pendingSeconds >= minimumFinalBufferSeconds else { return nil }

        return await processCurrentBufferIfNeeded(isFinal: true)
    }

    private func processCurrentBufferIfNeeded(isFinal: Bool) async -> ETDRSWhisperPrediction? {
        guard !isRunningInference, let whisperKit else { return nil }

        let fullBuffer = Array(whisperKit.audioProcessor.audioSamples)
        guard !fullBuffer.isEmpty else {
            publishStatus("Waiting for microphone audio...")
            return nil
        }

        let maxWindowSamples = Int(realtimeTranscriptionWindowSeconds * Float(WhisperKit.sampleRate))
        let consumedSampleCount = min(lastObservedSampleCount, fullBuffer.count)
        let bufferStartIndex = max(consumedSampleCount, fullBuffer.count - maxWindowSamples)
        let buffer = Array(fullBuffer[bufferStartIndex...])

        let newSampleCount = fullBuffer.count - lastObservedSampleCount
        let newBufferSeconds = Float(newSampleCount) / Float(WhisperKit.sampleRate)
        let recentBufferSeconds = Float(buffer.count) / Float(WhisperKit.sampleRate)

        if !isFinal, newBufferSeconds < minimumRealtimeBufferSeconds {
            publishStatus("Listening for your spoken letter...")
            return nil
        }

        if !isFinal {
            let voiceDetected = AudioProcessor.isVoiceDetected(
                in: whisperKit.audioProcessor.relativeEnergy,
                nextBufferInSeconds: newBufferSeconds,
                silenceThreshold: silenceThreshold
            )

            if !voiceDetected {
                publishStatus("Listening for your spoken letter...")
                return nil
            }
        }

        isRunningInference = true
        defer { isRunningInference = false }
        publishStatus(String(format: "Running WhisperKit on %.2fs recent audio...", recentBufferSeconds))

        do {
            let prediction = try await transcribe(buffer, isFinal: isFinal)
            if isFinal || !prediction.rawTranscription.isEmpty {
                lastObservedSampleCount = fullBuffer.count
            }

            if !isFinal {
                onPrediction?(prediction)
            }

            return prediction
        } catch {
            publishStatus("WhisperKit transcription error: \(error.localizedDescription)")
            return nil
        }
    }

    private func transcribe(_ audioSamples: [Float], isFinal: Bool) async throws -> ETDRSWhisperPrediction {
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
            guard !liveText.isEmpty, !isFinal, !self.looksLikePromptEcho(liveText) else { return nil }
            print("[ETDRSWhisper] Partial transcription: \(liveText)")

            let prediction = self.makePrediction(
                rawText: liveText,
                latency: CFAbsoluteTimeGetCurrent() - start,
                isFinal: false
            )
            self.onPrediction?(prediction)
            return nil
        }.first

        let latency = CFAbsoluteTimeGetCurrent() - start
        let rawText = result?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("[ETDRSWhisper] \(isFinal ? "Final" : "Completed") transcription: \(rawText.isEmpty ? "<empty>" : rawText)")

        return makePrediction(rawText: rawText, latency: latency, isFinal: isFinal)
    }

    private func makePrediction(rawText: String, latency: TimeInterval, isFinal: Bool) -> ETDRSWhisperPrediction {
        ETDRSWhisperPrediction(
            rawTranscription: rawText,
            normalizedLetter: normalizeLetter(from: rawText),
            latency: latency,
            isFinal: isFinal,
            isFiller: isFillerPhrase(rawText),
            isIgnorableNonAnswer: isIgnorableNonAnswerPhrase(rawText)
        )
    }

    private func normalizeLetter(from transcription: String) -> String? {
        let cleaned = cleanedTranscriptToken(from: transcription)
        guard !cleaned.isEmpty, !fillerPhrases.contains(cleaned) else { return nil }

        if let mapped = letterPronunciationMap[cleaned] ?? misidentificationMap[cleaned],
           recognizedLetters.contains(mapped) {
            return mapped
        }

        let tokens = cleaned.split(separator: " ").map(String.init)
        if !tokens.isEmpty && tokens.allSatisfy({ fillerPhrases.contains($0) }) {
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

    private func isFillerPhrase(_ transcription: String) -> Bool {
        let cleaned = cleanedTranscriptToken(from: transcription)
        guard !cleaned.isEmpty else { return false }
        if fillerPhrases.contains(cleaned) { return true }

        let tokens = cleaned.split(separator: " ").map(String.init)
        return !tokens.isEmpty && tokens.allSatisfy { fillerPhrases.contains($0) }
    }

    private func isIgnorableNonAnswerPhrase(_ transcription: String) -> Bool {
        let cleaned = cleanedTranscriptToken(from: transcription)
        let compact = cleaned.replacingOccurrences(of: " ", with: "")
        if cleaned.isEmpty { return true }
        if ignorableNonAnswerPhrases.contains(cleaned) || ignorableNonAnswerPhrases.contains(compact) {
            return true
        }

        let tokens = cleaned.split(separator: " ").map(String.init)
        return !tokens.isEmpty && tokens.allSatisfy { ignorableNonAnswerPhrases.contains($0) }
    }

    private func cleanedTranscriptToken(from transcription: String) -> String {
        let spaced = transcription
            .uppercased()
            .replacingOccurrences(of: "[^A-Z]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return spaced.split(separator: " ").joined(separator: " ")
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
