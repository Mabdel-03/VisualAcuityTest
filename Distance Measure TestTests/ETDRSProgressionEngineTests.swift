import XCTest
@testable import Distance_Measure_Test

final class ETDRSProgressionEngineTests: XCTestCase {
    private let acuities = [200, 160, 125]
    private let baseLogMAR = [200: 1.0, 160: 0.9, 125: 0.8]

    func testFiveLetterConfigurationDerivesTwoHundredthsPerLetter() {
        let configuration = ETDRSProtocolConfiguration.fiveLetterV1

        XCTAssertEqual(configuration.identifier, "etdrs-five-letter-v1")
        XCTAssertEqual(configuration.trialsPerAcuity, 5)
        XCTAssertEqual(configuration.correctToAdvance, 3)
        XCTAssertEqual(configuration.earlyPerfectCount, 3)
        XCTAssertEqual(configuration.logMARPerLetter, 0.02, accuracy: 0.000_001)
    }

    func testConfigurationRejectsInconsistentCriteria() {
        XCTAssertThrowsError(
            try ETDRSProtocolConfiguration(
                identifier: "invalid",
                trialsPerAcuity: 5,
                correctToAdvance: 6,
                earlyPerfectCount: 3,
                lineLogMARIncrement: 0.1
            )
        ) { error in
            XCTAssertEqual(
                error as? ETDRSProtocolConfigurationError,
                .invalidCorrectToAdvance
            )
        }

        XCTAssertThrowsError(
            try ETDRSProtocolConfiguration(
                identifier: "invalid",
                trialsPerAcuity: 5,
                correctToAdvance: 3,
                earlyPerfectCount: 0,
                lineLogMARIncrement: 0.1
            )
        ) { error in
            XCTAssertEqual(
                error as? ETDRSProtocolConfigurationError,
                .invalidEarlyPerfectCount
            )
        }

        XCTAssertThrowsError(
            try ETDRSProtocolConfiguration(
                identifier: "invalid",
                trialsPerAcuity: 5,
                correctToAdvance: 3,
                earlyPerfectCount: 2,
                lineLogMARIncrement: 0.1
            )
        ) { error in
            XCTAssertEqual(
                error as? ETDRSProtocolConfigurationError,
                .invalidEarlyPerfectCount
            )
        }
    }

    func testThreeInitialCorrectResponsesUsePerfectShortcut() throws {
        var engine = try makeEngine(startingAt: 0)

        XCTAssertEqual(engine.recordResponse(isCorrect: true), .continueCurrentAcuity)
        XCTAssertEqual(engine.recordResponse(isCorrect: true), .continueCurrentAcuity)
        XCTAssertEqual(engine.recordResponse(isCorrect: true), .changeAcuity(160))

        XCTAssertEqual(
            engine.resultsByAcuity[200],
            ETDRSAcuityResult(
                acuity: 200,
                presentations: 3,
                actualCorrect: 3,
                progressionCorrect: 5,
                usedPerfectShortcut: true
            )
        )
        XCTAssertEqual(engine.currentAcuity, 160)
        XCTAssertEqual(engine.attemptsInCurrentAcuity, 0)
        XCTAssertEqual(engine.nextTrialNumber, 1)
    }

    func testAnyMissInFirstThreeRequiresAllFiveResponses() throws {
        var engine = try makeEngine(startingAt: 0)

        XCTAssertEqual(engine.recordResponse(isCorrect: true), .continueCurrentAcuity)
        XCTAssertEqual(engine.recordResponse(isCorrect: true), .continueCurrentAcuity)
        XCTAssertEqual(engine.recordResponse(isCorrect: false), .continueCurrentAcuity)
        XCTAssertEqual(engine.recordResponse(isCorrect: true), .continueCurrentAcuity)
        XCTAssertEqual(engine.recordResponse(isCorrect: true), .changeAcuity(160))

        XCTAssertEqual(
            engine.resultsByAcuity[200],
            ETDRSAcuityResult(
                acuity: 200,
                presentations: 5,
                actualCorrect: 4,
                progressionCorrect: 4,
                usedPerfectShortcut: false
            )
        )
    }

    func testThreeOfFiveAdvancesAndResetsLevelCounters() throws {
        var engine = try makeEngine(startingAt: 0)

        let outcome = record(
            [true, false, true, false, true],
            in: &engine
        )

        XCTAssertEqual(outcome, .changeAcuity(160))
        XCTAssertEqual(engine.correctByAcuity[200], 3)
        XCTAssertEqual(engine.attemptsInCurrentAcuity, 0)
        XCTAssertEqual(engine.correctInCurrentAcuity, 0)
    }

    func testTwoOfFiveMovesToUntestedLargerAcuity() throws {
        var engine = try makeEngine(startingAt: 1)

        let outcome = record(
            [true, false, true, false, false],
            in: &engine
        )

        XCTAssertEqual(outcome, .changeAcuity(200))
        XCTAssertEqual(engine.correctByAcuity[160], 2)
        XCTAssertEqual(engine.currentAcuity, 200)
    }

    func testRevisitingAdjacentAcuityFinishesTest() throws {
        var engine = try makeEngine(startingAt: 1)
        XCTAssertEqual(
            record([true, true, true], in: &engine),
            .changeAcuity(125)
        )

        let outcome = record(
            [true, true, false, false, false],
            in: &engine
        )

        guard case let .finish(result) = outcome else {
            return XCTFail("Expected the test to finish after revisiting 20/160.")
        }
        XCTAssertEqual(result.primaryAcuity, 125)
        XCTAssertEqual(result.primaryCorrect, 2)
        XCTAssertEqual(result.secondaryAcuity, 160)
        XCTAssertEqual(result.secondaryCorrect, 5)
        XCTAssertEqual(result.logMAR, 0.86, accuracy: 0.000_001)
    }

    func testLargestAndSmallestAcuityBoundariesFinishSafely() throws {
        var largestEngine = try makeEngine(startingAt: 0)
        let largestOutcome = record(
            [true, true, false, false, false],
            in: &largestEngine
        )
        guard case let .finish(largestResult) = largestOutcome else {
            return XCTFail("Expected failure at the largest acuity to finish.")
        }
        XCTAssertEqual(largestResult.primaryAcuity, 160)
        XCTAssertEqual(largestResult.primaryCorrect, 0)
        XCTAssertEqual(largestResult.secondaryAcuity, 200)
        XCTAssertEqual(largestResult.secondaryCorrect, 2)
        XCTAssertEqual(largestResult.logMAR, 1.06, accuracy: 0.000_001)

        var smallestEngine = try makeEngine(startingAt: 2)
        let smallestOutcome = record([true, true, true], in: &smallestEngine)
        guard case let .finish(smallestResult) = smallestOutcome else {
            return XCTFail("Expected success at the smallest acuity to finish.")
        }
        XCTAssertEqual(smallestResult.primaryAcuity, 125)
        XCTAssertEqual(smallestResult.primaryCorrect, 5)
        XCTAssertEqual(smallestResult.secondaryAcuity, 160)
        XCTAssertEqual(smallestResult.secondaryCorrect, 0)
        XCTAssertEqual(smallestResult.logMAR, 0.9, accuracy: 0.000_001)
    }

    func testMissedLettersAcrossTerminalLevelsAddPointZeroSix() throws {
        var engine = try makeEngine(startingAt: 1)
        XCTAssertEqual(
            record([true, true, false, true, true], in: &engine),
            .changeAcuity(125)
        )

        let outcome = record(
            [false, false, true, true, true],
            in: &engine
        )

        guard case let .finish(result) = outcome else {
            return XCTFail("Expected the smallest acuity to finish the test.")
        }
        XCTAssertEqual(result.primaryCorrect, 3)
        XCTAssertEqual(result.secondaryCorrect, 4)
        XCTAssertEqual(result.logMAR, 0.86, accuracy: 0.000_001)
    }

    func testEngineValidatesAcuityInputs() {
        XCTAssertThrowsError(
            try ETDRSProgressionEngine(
                configuration: .fiveLetterV1,
                acuityLevels: [200],
                startingAcuityIndex: 0,
                baseLogMARByAcuity: [200: 1.0]
            )
        ) { error in
            XCTAssertEqual(
                error as? ETDRSProgressionEngineError,
                .tooFewAcuityLevels
            )
        }

        XCTAssertThrowsError(
            try ETDRSProgressionEngine(
                configuration: .fiveLetterV1,
                acuityLevels: acuities,
                startingAcuityIndex: 0,
                baseLogMARByAcuity: [200: 1.0, 160: 0.9]
            )
        ) { error in
            XCTAssertEqual(
                error as? ETDRSProgressionEngineError,
                .missingBaseLogMAR(125)
            )
        }
    }

    private func makeEngine(startingAt index: Int) throws -> ETDRSProgressionEngine {
        try ETDRSProgressionEngine(
            configuration: .fiveLetterV1,
            acuityLevels: acuities,
            startingAcuityIndex: index,
            baseLogMARByAcuity: baseLogMAR
        )
    }

    @discardableResult
    private func record(
        _ responses: [Bool],
        in engine: inout ETDRSProgressionEngine
    ) -> ETDRSProgressionOutcome {
        var outcome: ETDRSProgressionOutcome = .continueCurrentAcuity
        for response in responses {
            outcome = engine.recordResponse(isCorrect: response)
        }
        return outcome
    }
}
