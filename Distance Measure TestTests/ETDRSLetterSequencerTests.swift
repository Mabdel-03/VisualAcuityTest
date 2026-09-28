import XCTest
@testable import Distance_Measure_Test

/// SplitMix64: a small seeded generator so every property test is reproducible. The tests assert
/// properties only, never exact sequences, because the standard library does not promise that
/// `randomElement(using:)` or `shuffled(using:)` consume a generator the same way across releases.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class ETDRSLetterSequencerTests: XCTestCase {
    private let bank = ["C", "D", "F", "H", "K", "N", "P", "R", "X", "J", "Z"]
    /// Mirrors ETDRSViewController.acuityList and the five start-size rows' indices in it.
    private let acuityList = [200, 160, 125, 100, 80, 63, 50, 40, 32, 20, 16]
    private let startIndices = [0, 2, 4, 6, 9]

    private var baseLogMAR: [Int: Double] {
        Dictionary(uniqueKeysWithValues: acuityList.map { ($0, log10(Double($0) / 20)) })
    }

    // MARK: - Rule checker

    /// Every broken rule in `rows`, described. `precedingLetter` is the letter shown just before
    /// the first row (the tapped start-size letter). R1 is checked per block of `bank.count`.
    private func violations(
        in rows: [[String]],
        precedingLetter: String?,
        bank: [String]
    ) -> [String] {
        var found: [String] = []
        var previous = precedingLetter
        var prefixes = Set<[String]>()
        for (rowIndex, row) in rows.enumerated() {
            for (slot, letter) in row.enumerated() {
                if !bank.contains(letter) { found.append("row \(rowIndex) slot \(slot): \(letter) not in bank") }
                if letter == previous { found.append("R2: row \(rowIndex) slot \(slot) repeats \(letter)") }
                previous = letter
                let blockStart = slot - slot % bank.count
                if row[blockStart..<slot].contains(letter) {
                    found.append("R1: row \(rowIndex) repeats \(letter) at slot \(slot)")
                }
                if rowIndex > 0, rows[rowIndex - 1].indices.contains(slot), rows[rowIndex - 1][slot] == letter {
                    found.append("R3: row \(rowIndex) slot \(slot) repeats \(letter)")
                }
            }
            if row.count >= ETDRSLetterSequencer.comparedPrefixLength {
                let prefix = Array(row.prefix(ETDRSLetterSequencer.comparedPrefixLength))
                if !prefixes.insert(prefix).inserted {
                    found.append("R4: row \(rowIndex) reopens with \(prefix)")
                }
            }
        }
        return found
    }

    private enum Responses {
        /// Mostly right above the threshold row, chance-like at it, mostly wrong below it.
        case threshold(Int)
        case always(Bool)
    }

    /// Runs one eye's test through the real engine the way ETDRSViewController does: a row opens
    /// whenever the engine's attempt counter is zero.
    private func simulateTest(
        startIndex: Int,
        responses: Responses,
        precedingLetter: String?,
        generator: inout SeededGenerator
    ) throws -> (rows: [[String]], sequencer: ETDRSLetterSequencer, descended: Bool) {
        var engine = try ETDRSProgressionEngine(
            configuration: .fiveLetterV1,
            acuityLevels: acuityList,
            startingAcuityIndex: startIndex,
            baseLogMARByAcuity: baseLogMAR
        )
        var sequencer = ETDRSLetterSequencer(precedingLetter: precedingLetter)
        var rows: [[String]] = []
        var descended = false

        while true {
            let opensRow = engine.attemptsInCurrentAcuity == 0
            let letter = sequencer.nextLetter(startingNewRow: opensRow, using: &generator)
            if opensRow { rows.append([]) }
            rows[rows.count - 1].append(letter)

            let index = engine.currentAcuityIndex
            let isCorrect: Bool
            switch responses {
            case .always(let answer):
                isCorrect = answer
            case .threshold(let thresholdIndex):
                let probability = index < thresholdIndex ? 0.9 : (index == thresholdIndex ? 0.5 : 0.1)
                isCorrect = Double.random(in: 0..<1, using: &generator) < probability
            }
            switch engine.recordResponse(isCorrect: isCorrect) {
            case .continueCurrentAcuity:
                continue
            case .changeAcuity:
                descended = descended || engine.currentAcuityIndex < index
            case .finish:
                return (rows, sequencer, descended)
            }
        }
    }

    // MARK: - Letter bank and start-size letters

    func testBankIsTheElevenLetterSetWithoutDuplicates() {
        XCTAssertEqual(ETDRSLetterBank.letters, bank)
        XCTAssertEqual(Set(ETDRSLetterBank.letters).count, ETDRSLetterBank.letters.count)
    }

    func testStartSizeRowsGetFiveDifferentLettersSpreadOverTheWholeBank() {
        let seeds = 11_000
        var countsByRow = Array(repeating: [String: Int](), count: 5)

        for seed in 0..<seeds {
            var generator = SeededGenerator(seed: UInt64(seed))
            let letters = ETDRSLetterBank.distinctLetters(count: 5, using: &generator)
            XCTAssertEqual(letters.count, 5)
            XCTAssertEqual(Set(letters).count, 5, "Two start-size rows showed the same letter.")
            XCTAssertTrue(Set(letters).isSubset(of: Set(bank)))
            for (row, letter) in letters.enumerated() {
                countsByRow[row][letter, default: 0] += 1
            }
        }

        let expected = Double(seeds) / Double(bank.count)
        for (row, counts) in countsByRow.enumerated() {
            XCTAssertEqual(Set(counts.keys), Set(bank), "Row \(row) never showed some letters.")
            for (letter, count) in counts {
                XCTAssertEqual(Double(count), expected, accuracy: expected * 0.15, "Row \(row), \(letter)")
            }
        }
    }

    // MARK: - Engine-driven tests

    func testEngineDrivenTestsNeverBreakAnyRule() throws {
        var generator = SeededGenerator(seed: 20_260_928)
        var letterCounts: [String: Int] = [:]
        var sawThreeLetterRow = false
        var sawDescendingPath = false
        var sawElevenRowTest = false
        var failures: [String] = []

        for _ in 0..<20_000 {
            let startIndex = startIndices.randomElement(using: &generator)!
            let thresholdIndex = Int.random(in: 0...acuityList.count, using: &generator)
            let precedingLetter = Bool.random(using: &generator) ? bank.randomElement(using: &generator) : nil
            let run = try simulateTest(
                startIndex: startIndex,
                responses: .threshold(thresholdIndex),
                precedingLetter: precedingLetter,
                generator: &generator
            )

            failures += violations(in: run.rows, precedingLetter: precedingLetter, bank: bank)
            if run.sequencer.relaxedDrawCount > 0 { failures.append("relaxed \(run.sequencer.relaxedDraws)") }
            sawThreeLetterRow = sawThreeLetterRow || run.rows.contains { $0.count == 3 }
            sawDescendingPath = sawDescendingPath || run.descended
            sawElevenRowTest = sawElevenRowTest || run.rows.count == acuityList.count
            XCTAssertTrue(run.rows.allSatisfy { $0.count == 3 || $0.count == 5 }, "\(run.rows)")
            run.rows.joined().forEach { letterCounts[$0, default: 0] += 1 }
        }

        XCTAssertEqual(Array(failures.prefix(10)), [], "\(failures.count) rule violations")
        XCTAssertTrue(sawThreeLetterRow, "No 3/3 shortcut row was exercised.")
        XCTAssertTrue(sawDescendingPath, "No descending path was exercised.")
        XCTAssertTrue(sawElevenRowTest, "No 11-row test was exercised.")

        let total = Double(letterCounts.values.reduce(0, +))
        for letter in bank {
            XCTAssertEqual(
                Double(letterCounts[letter] ?? 0) / total,
                1.0 / Double(bank.count),
                accuracy: 0.05 / Double(bank.count),
                "\(letter) is over- or under-drawn."
            )
        }
    }

    func testLongestPathsInEachDirectionNeverBreakAnyRule() throws {
        var failures: [String] = []
        for seed in 0..<5_000 {
            var generator = SeededGenerator(seed: UInt64(seed))
            // Always right from 20/200: eleven 3-letter rows.
            let climbing = try simulateTest(
                startIndex: 0,
                responses: .always(true),
                precedingLetter: "C",
                generator: &generator
            )
            // Always wrong from 20/20: ten 5-letter rows down to 20/200.
            let descending = try simulateTest(
                startIndex: 9,
                responses: .always(false),
                precedingLetter: "Z",
                generator: &generator
            )
            failures += violations(in: climbing.rows, precedingLetter: "C", bank: bank)
            failures += violations(in: descending.rows, precedingLetter: "Z", bank: bank)
            XCTAssertEqual(climbing.sequencer.relaxedDrawCount + descending.sequencer.relaxedDrawCount, 0)
            XCTAssertEqual(climbing.rows.count, 11)
            XCTAssertEqual(descending.rows.count, 10)
        }
        XCTAssertEqual(Array(failures.prefix(10)), [], "\(failures.count) rule violations")
    }

    func testRandomRowShapesNeverNeedARelaxation() {
        var generator = SeededGenerator(seed: 7)
        var failures: [String] = []

        for _ in 0..<20_000 {
            let precedingLetter = bank.randomElement(using: &generator)
            var sequencer = ETDRSLetterSequencer(precedingLetter: precedingLetter)
            var rows: [[String]] = []
            for _ in 0..<Int.random(in: 1...11, using: &generator) {
                let length = Bool.random(using: &generator) ? 3 : 5
                rows.append((0..<length).map { slot in
                    sequencer.nextLetter(startingNewRow: slot == 0, using: &generator)
                })
            }
            failures += violations(in: rows, precedingLetter: precedingLetter, bank: bank)
            if sequencer.relaxedDrawCount > 0 { failures.append("relaxed \(sequencer.relaxedDraws)") }
        }
        XCTAssertEqual(Array(failures.prefix(10)), [], "\(failures.count) rule violations")
    }

    // MARK: - Scripted rule cases

    private func scriptedSequencer(afterRows rows: [[String]], precedingLetter: String? = nil) -> ETDRSLetterSequencer {
        var sequencer = ETDRSLetterSequencer(precedingLetter: precedingLetter)
        for row in rows {
            for (slot, letter) in row.enumerated() {
                sequencer.record(letter, startingNewRow: slot == 0)
            }
        }
        return sequencer
    }

    private func bankExcluding(_ excluded: Set<String>) -> [String] {
        bank.filter { !excluded.contains($0) }
    }

    func testFirstLetterOfATestMayBeAnyLetter() {
        XCTAssertEqual(ETDRSLetterSequencer().allowedNextLetters(startingNewRow: true), bank)
    }

    func testTappedStartSizeLetterIsExcludedFromTrialOne() {
        XCTAssertEqual(
            ETDRSLetterSequencer(precedingLetter: "Z").allowedNextLetters(startingNewRow: true),
            bankExcluding(["Z"])
        )
    }

    func testALetterAppearsOnlyOncePerRow() {
        let sequencer = scriptedSequencer(afterRows: [["C", "D"]])
        XCTAssertEqual(sequencer.allowedNextLetters(startingNewRow: false), bankExcluding(["C", "D"]))
    }

    func testNewRowExcludesTheLastLetterAndThePreviousRowsFirstSlot() {
        let sequencer = scriptedSequencer(afterRows: [["C", "D", "F", "H", "K"]])
        XCTAssertEqual(sequencer.allowedNextLetters(startingNewRow: true), bankExcluding(["K", "C"]))
    }

    func testSlotRuleOnlyComparesSlotsThePreviousRowShowed() {
        // The 3/3 shortcut ended the previous row, so slot 3 has nothing to compare against.
        let sequencer = scriptedSequencer(afterRows: [["C", "D", "F"], ["H", "K", "N"]])
        XCTAssertEqual(sequencer.allowedNextLetters(startingNewRow: false), bankExcluding(["H", "K", "N"]))
    }

    func testNoRowReopensWithAnEarlierRowsFirstThreeLetters() {
        let sequencer = scriptedSequencer(afterRows: [
            ["C", "D", "F", "H", "K"],
            ["H", "K", "N", "P", "R"],
            ["C", "D"]
        ])
        // R1 removes C and D, R3 removes N (previous row's slot 2), R4 removes F.
        XCTAssertEqual(sequencer.allowedNextLetters(startingNewRow: false), bankExcluding(["C", "D", "N", "F"]))
    }

    func testRetriesDoNotAdvanceTheSequence() {
        // The controller only calls nextLetter from generateNewLetter(), so a re-shown letter
        // leaves the sequencer untouched; querying the allowed letters must not change state.
        let sequencer = scriptedSequencer(afterRows: [["C", "D", "F"]])
        let first = sequencer.allowedNextLetters(startingNewRow: true)
        let second = sequencer.allowedNextLetters(startingNewRow: true)
        XCTAssertEqual(first, second)
        XCTAssertEqual(sequencer.currentRow, ["C", "D", "F"])
    }

    // MARK: - Fallback and reproducibility

    func testTinyBankRelaxesOnlyTheSlotAndPrefixRules() {
        let tinyBank = ["A", "B", "C"]
        var generator = SeededGenerator(seed: 3)
        var sequencer = ETDRSLetterSequencer(bank: tinyBank)
        var rows: [[String]] = []
        // Only six orderings of three letters exist, so R4 must give way by the seventh row.
        for _ in 0..<10 {
            rows.append((0..<5).map { slot in
                sequencer.nextLetter(startingNewRow: slot == 0, using: &generator)
            })
        }

        let flattened = Array(rows.joined())
        XCTAssertNil(zip(flattened, flattened.dropFirst()).first { $0 == $1 }, "R2 must never be relaxed.")
        for row in rows {
            XCTAssertEqual(Set(row[0..<3]).count, 3, "R1 must hold within each block: \(row)")
            XCTAssertEqual(Set(row[3..<5]).count, 2, "R1 must hold within each block: \(row)")
        }
        XCTAssertGreaterThan(sequencer.relaxedDrawCount, 0)
    }

    func testSameSeedGivesTheSameSequence() {
        func sequence(seed: UInt64) -> [String] {
            var generator = SeededGenerator(seed: seed)
            var sequencer = ETDRSLetterSequencer()
            return (0..<200).map { index in
                sequencer.nextLetter(startingNewRow: index % 5 == 0, using: &generator)
            }
        }
        XCTAssertEqual(sequence(seed: 42), sequence(seed: 42))
        XCTAssertNotEqual(sequence(seed: 42), sequence(seed: 43))
    }
}
