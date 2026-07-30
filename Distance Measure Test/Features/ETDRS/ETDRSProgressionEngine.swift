//
//  ETDRSProgressionEngine.swift
//  Distance Measure Test
//

import Foundation

enum ETDRSProtocolConfigurationError: Error, Equatable {
    case emptyIdentifier
    case invalidTrialsPerAcuity
    case invalidCorrectToAdvance
    case invalidEarlyPerfectCount
    case invalidLineLogMARIncrement
}

struct ETDRSProtocolConfiguration: Equatable {
    let identifier: String
    let trialsPerAcuity: Int
    let correctToAdvance: Int
    let earlyPerfectCount: Int?
    let lineLogMARIncrement: Double

    var logMARPerLetter: Double {
        lineLogMARIncrement / Double(trialsPerAcuity)
    }

    init(
        identifier: String,
        trialsPerAcuity: Int,
        correctToAdvance: Int,
        earlyPerfectCount: Int?,
        lineLogMARIncrement: Double
    ) throws {
        guard !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ETDRSProtocolConfigurationError.emptyIdentifier
        }
        guard trialsPerAcuity > 0 else {
            throw ETDRSProtocolConfigurationError.invalidTrialsPerAcuity
        }
        guard (1...trialsPerAcuity).contains(correctToAdvance) else {
            throw ETDRSProtocolConfigurationError.invalidCorrectToAdvance
        }
        if let earlyPerfectCount,
           (!(1...trialsPerAcuity).contains(earlyPerfectCount)
                || earlyPerfectCount < correctToAdvance) {
            throw ETDRSProtocolConfigurationError.invalidEarlyPerfectCount
        }
        guard lineLogMARIncrement.isFinite, lineLogMARIncrement > 0 else {
            throw ETDRSProtocolConfigurationError.invalidLineLogMARIncrement
        }

        self.identifier = identifier
        self.trialsPerAcuity = trialsPerAcuity
        self.correctToAdvance = correctToAdvance
        self.earlyPerfectCount = earlyPerfectCount
        self.lineLogMARIncrement = lineLogMARIncrement
    }

    static let fiveLetterV1: ETDRSProtocolConfiguration = {
        do {
            return try ETDRSProtocolConfiguration(
                identifier: "etdrs-five-letter-v1",
                trialsPerAcuity: 5,
                correctToAdvance: 3,
                earlyPerfectCount: 3,
                lineLogMARIncrement: 0.1
            )
        } catch {
            preconditionFailure("Invalid built-in ETDRS protocol: \(error)")
        }
    }()

    var metadata: TestProtocolMetadata {
        TestProtocolMetadata(
            protocolIdentifier: identifier,
            trialsPerAcuity: trialsPerAcuity,
            correctToAdvance: correctToAdvance,
            earlyPerfectCount: earlyPerfectCount,
            logMARPerLetter: logMARPerLetter
        )
    }
}

enum ETDRSProgressionEngineError: Error, Equatable {
    case tooFewAcuityLevels
    case invalidStartingAcuityIndex
    case missingBaseLogMAR(Int)
}

struct ETDRSFinalResult: Equatable {
    let primaryAcuity: Int
    let primaryCorrect: Int
    let secondaryAcuity: Int
    let secondaryCorrect: Int
    let logMAR: Double
}

struct ETDRSAcuityResult: Equatable {
    let acuity: Int
    let presentations: Int
    let actualCorrect: Int
    let progressionCorrect: Int
    let usedPerfectShortcut: Bool
}

enum ETDRSProgressionOutcome: Equatable {
    case continueCurrentAcuity
    case changeAcuity(Int)
    case finish(ETDRSFinalResult)
}

struct ETDRSProgressionEngine {
    let configuration: ETDRSProtocolConfiguration
    let acuityLevels: [Int]

    private let baseLogMARByAcuity: [Int: Double]

    private(set) var currentAcuityIndex: Int
    private(set) var attemptsInCurrentAcuity = 0
    private(set) var correctInCurrentAcuity = 0
    private(set) var resultsByAcuity: [Int: ETDRSAcuityResult] = [:]
    private(set) var isFinished = false

    var correctByAcuity: [Int: Int] {
        resultsByAcuity.mapValues(\.progressionCorrect)
    }

    var currentAcuity: Int {
        acuityLevels[currentAcuityIndex]
    }

    var nextTrialNumber: Int {
        attemptsInCurrentAcuity + 1
    }

    init(
        configuration: ETDRSProtocolConfiguration,
        acuityLevels: [Int],
        startingAcuityIndex: Int,
        baseLogMARByAcuity: [Int: Double]
    ) throws {
        guard acuityLevels.count >= 2 else {
            throw ETDRSProgressionEngineError.tooFewAcuityLevels
        }
        guard acuityLevels.indices.contains(startingAcuityIndex) else {
            throw ETDRSProgressionEngineError.invalidStartingAcuityIndex
        }
        for acuity in acuityLevels where baseLogMARByAcuity[acuity] == nil {
            throw ETDRSProgressionEngineError.missingBaseLogMAR(acuity)
        }

        self.configuration = configuration
        self.acuityLevels = acuityLevels
        self.currentAcuityIndex = startingAcuityIndex
        self.baseLogMARByAcuity = baseLogMARByAcuity
    }

    mutating func recordResponse(isCorrect: Bool) -> ETDRSProgressionOutcome {
        precondition(!isFinished, "Cannot record a response after the test has finished.")
        precondition(
            attemptsInCurrentAcuity < configuration.trialsPerAcuity,
            "Cannot record another response after the acuity level has completed."
        )

        attemptsInCurrentAcuity += 1
        if isCorrect {
            correctInCurrentAcuity += 1
        }

        let usedPerfectShortcut = configuration.earlyPerfectCount.map {
            attemptsInCurrentAcuity == $0 && correctInCurrentAcuity == $0
        } ?? false
        let completedFullLevel =
            attemptsInCurrentAcuity == configuration.trialsPerAcuity

        guard usedPerfectShortcut || completedFullLevel else {
            return .continueCurrentAcuity
        }

        let progressionCorrect = usedPerfectShortcut
            ? configuration.trialsPerAcuity
            : correctInCurrentAcuity
        let result = ETDRSAcuityResult(
            acuity: currentAcuity,
            presentations: attemptsInCurrentAcuity,
            actualCorrect: correctInCurrentAcuity,
            progressionCorrect: progressionCorrect,
            usedPerfectShortcut: usedPerfectShortcut
        )
        resultsByAcuity[currentAcuity] = result

        return completeCurrentAcuity(result)
    }

    private mutating func completeCurrentAcuity(
        _ completedResult: ETDRSAcuityResult
    ) -> ETDRSProgressionOutcome {
        let completedAcuity = completedResult.acuity
        let completedCorrect = completedResult.progressionCorrect

        if currentAcuityIndex == acuityLevels.count - 1 {
            return finish(
                primaryAcuity: completedAcuity,
                primaryCorrect: completedCorrect,
                secondaryAcuity: acuityLevels[currentAcuityIndex - 1],
                secondaryCorrect: resultsByAcuity[
                    acuityLevels[currentAcuityIndex - 1]
                ]?.progressionCorrect ?? 0
            )
        }

        if completedCorrect >= configuration.correctToAdvance {
            let nextIndex = currentAcuityIndex + 1
            let nextAcuity = acuityLevels[nextIndex]
            if let nextResult = resultsByAcuity[nextAcuity] {
                return finish(
                    primaryAcuity: nextAcuity,
                    primaryCorrect: nextResult.progressionCorrect,
                    secondaryAcuity: completedAcuity,
                    secondaryCorrect: completedCorrect
                )
            }

            move(to: nextIndex)
            return .changeAcuity(currentAcuity)
        }

        if currentAcuityIndex == 0 {
            let nextAcuity = acuityLevels[1]
            return finish(
                primaryAcuity: nextAcuity,
                primaryCorrect: resultsByAcuity[nextAcuity]?.progressionCorrect ?? 0,
                secondaryAcuity: completedAcuity,
                secondaryCorrect: completedCorrect
            )
        }

        let previousIndex = currentAcuityIndex - 1
        let previousAcuity = acuityLevels[previousIndex]
        if let previousResult = resultsByAcuity[previousAcuity] {
            return finish(
                primaryAcuity: completedAcuity,
                primaryCorrect: completedCorrect,
                secondaryAcuity: previousAcuity,
                secondaryCorrect: previousResult.progressionCorrect
            )
        }

        move(to: previousIndex)
        return .changeAcuity(currentAcuity)
    }

    private mutating func move(to index: Int) {
        currentAcuityIndex = index
        attemptsInCurrentAcuity = 0
        correctInCurrentAcuity = 0
    }

    private mutating func finish(
        primaryAcuity: Int,
        primaryCorrect: Int,
        secondaryAcuity: Int,
        secondaryCorrect: Int
    ) -> ETDRSProgressionOutcome {
        let trials = configuration.trialsPerAcuity
        let primaryWrong = max(0, trials - primaryCorrect)
        let secondaryWrong = max(0, trials - secondaryCorrect)
        let baseLogMAR = baseLogMARByAcuity[primaryAcuity]!
        let logMAR = baseLogMAR
            + Double(primaryWrong + secondaryWrong)
            * configuration.logMARPerLetter
        isFinished = true

        return .finish(
            ETDRSFinalResult(
                primaryAcuity: primaryAcuity,
                primaryCorrect: primaryCorrect,
                secondaryAcuity: secondaryAcuity,
                secondaryCorrect: secondaryCorrect,
                logMAR: logMAR
            )
        )
    }
}
