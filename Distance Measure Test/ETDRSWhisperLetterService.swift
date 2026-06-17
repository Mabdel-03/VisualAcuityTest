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

    private let expectedLanguage = "en"
    private let minimumRealtimeBufferSeconds: Float = 0.35
    private let forceRealtimeTranscriptionAfterSeconds: Float = 1.2
    private let realtimeTranscriptionWindowSeconds: Float = 2.4
    private let silenceThreshold: Float = 0.08
    private let modelName = WhisperKit.recommendedModels().default
    private let validLetters: Set<String> = ["C", "D", "F", "H", "K", "N", "P", "R", "U", "V", "Z"]
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
    private let misidentificationMap: [String: String] = [
        "CEE": "C", "SEA": "C", "SEE": "C",
        "DEE": "D", "DI": "D",
        "EF": "F", "EFF": "F",
        "AITCH": "H", "EACH": "H", "HATCH": "H", "ATCH": "H",
        "KAY": "K", "KEY": "K", "OKAY": "K",
        "EN": "N", "ENN": "N", "AN": "N",
        "PEA": "P", "PEE": "P", "PI": "P",
        "ARE": "R", "AR": "R", "ARR": "R", "OUR": "R",
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

    var isListening: Bool {
        transcriptionLoop != nil
    }

    func requestMicrophonePermission() async -> Bool {
        await AudioProcessor.requestRecordPermission()
    }

    func prepareIfNeeded() async throws {
        if whisperKit != nil {
            publishStatus("Speech engine ready.")
            return
        }

        if let prepareTask {
            whisperKit = try await prepareTask.value
            return
        }

        let task = Task<WhisperKit, Error> {
            self.publishStatus("Checking WhisperKit model files...")
            let modelFolder = try await WhisperKit.download(variant: self.modelName, progressCallback: { progress in
                let percentage = Int((progress.fractionCompleted * 100).rounded())
                self.publishStatus("Downloading WhisperKit model... \(percentage)%")
            })

            self.publishStatus("Initializing WhisperKit...")
            let config = WhisperKitConfig(
                model: self.modelName,
                modelFolder: modelFolder.path,
                verbose: false,
                prewarm: false,
                load: false,
                download: false
            )

            let whisperKit = try await WhisperKit(config)
            self.publishStatus("Prewarming WhisperKit model...")
            try await whisperKit.prewarmModels()
            self.publishStatus("Loading WhisperKit model...")
            try await whisperKit.loadModels()
            self.publishStatus("WhisperKit ready.")
            return whisperKit
        }

        prepareTask = task

        do {
            whisperKit = try await task.value
        } catch {
            prepareTask = nil
            publishStatus("WhisperKit failed to load: \(error.localizedDescription)")
            throw error
        }
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
            publishStatus(String(format: "Capturing audio... %.2fs recent audio buffered", recentBufferSeconds))
            return nil
        }

        if !isFinal {
            let voiceDetected = AudioProcessor.isVoiceDetected(
                in: whisperKit.audioProcessor.relativeEnergy,
                nextBufferInSeconds: newBufferSeconds,
                silenceThreshold: silenceThreshold
            )

            if !voiceDetected {
                let canForceFirstPass = lastObservedSampleCount == 0 && recentBufferSeconds >= forceRealtimeTranscriptionAfterSeconds
                if !canForceFirstPass {
                    publishStatus(String(format: "Audio captured (%.2fs), waiting for clearer speech...", recentBufferSeconds))
                    return nil
                }
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
            chunkingStrategy: nil
        )

        let start = CFAbsoluteTimeGetCurrent()
        let result = try await whisperKit.transcribe(audioArray: audioSamples, decodeOptions: decodeOptions) { [weak self] progress in
            guard let self else { return nil }

            let liveText = progress.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !liveText.isEmpty, !isFinal else { return nil }
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

        if let mapped = misidentificationMap[cleaned], validLetters.contains(mapped) {
            return mapped
        }

        let tokens = cleaned.split(separator: " ").map(String.init)
        if !tokens.isEmpty && tokens.allSatisfy({ fillerPhrases.contains($0) }) {
            return nil
        }

        if let mappedToken = tokens.compactMap({ misidentificationMap[$0] }).last,
           validLetters.contains(mappedToken) {
            return mappedToken
        }

        if let singleLetterToken = tokens.last(where: { $0.count == 1 }),
           validLetters.contains(singleLetterToken) {
            return singleLetterToken
        }

        let compactLetters = cleaned.replacingOccurrences(of: " ", with: "")
        if compactLetters.count == 1, validLetters.contains(compactLetters) {
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

    private func publishStatus(_ message: String) {
        guard message != lastStatusMessage else { return }
        lastStatusMessage = message
        print("[ETDRSWhisper] \(message)")
    }
}
