//
//  ETDRSLetterSequencer.swift
//  Distance Measure Test
//

import Foundation

/// The letters the ETDRS test and the ETDRS start-size screen present.
enum ETDRSLetterBank {
    static let letters = ["C", "D", "F", "H", "K", "N", "P", "R", "X", "J", "Z"]

    /// `count` different letters from `bank` in random order: one per start-size row.
    static func distinctLetters<G: RandomNumberGenerator>(
        count: Int,
        from bank: [String] = ETDRSLetterBank.letters,
        using generator: inout G
    ) -> [String] {
        precondition(Set(bank).count == bank.count, "The letter bank must not contain duplicates.")
        precondition((0...bank.count).contains(count), "Cannot draw \(count) distinct letters from \(bank.count).")
        return Array(bank.shuffled(using: &generator).prefix(count))
    }
}

/// Chooses each ETDRS letter at the moment it is presented. One instance per eye (one
/// ETDRSViewController), fed only by draws: retries and pauses re-show the current letter and never
/// reach it.
///
/// A row is one acuity level: the letters actually shown at that size, 3 when the 3/3 shortcut ends
/// it and 5 otherwise. The choice is uniformly random among the letters these rules allow:
/// - R1: a letter appears at most once within a row. The rule applies per block of `bank.count`
///   letters so it can never run out; a 5-letter row with the 11-letter bank never reaches a second
///   block.
/// - R2: never the same letter twice in succession, across row boundaries too. `precedingLetter`
///   seeds it, so trial 1 differs from the start-size letter the participant tapped at that size.
/// - R3: slot i never repeats slot i of the row shown immediately before.
/// - R4: no two rows open with the same three letters, so no row repeats an earlier row.
///
/// If R3 and R4 ever leave nothing (they cannot with this bank and the engine's 11 rows), R4 and
/// then R3 are relaxed and logged in `relaxedDraws`. R1 and R2 always hold. Myotect's
/// LetterSequencer applies the same rules in the same order.
struct ETDRSLetterSequencer {
    static let ruleIdentifier = "row-unique-no-repeat-slot-prefix3-v1"
    static let comparedPrefixLength = 3

    enum Relaxation: Equatable {
        case prefixRule
        case prefixAndSlotRules
    }

    struct RelaxedDraw: Equatable {
        let slot: Int
        let relaxation: Relaxation
    }

    let bank: [String]
    private(set) var currentRow: [String] = []
    /// The letters the row before `currentRow` actually showed (3 or 5).
    private(set) var previousRow: [String] = []
    private(set) var earlierRowPrefixes: Set<[String]> = []
    private(set) var lastShownLetter: String?
    private(set) var relaxedDraws: [RelaxedDraw] = []

    var relaxedDrawCount: Int { relaxedDraws.count }

    init(bank: [String] = ETDRSLetterBank.letters, precedingLetter: String? = nil) {
        precondition(bank.count >= 2, "The letter bank needs at least two letters.")
        precondition(Set(bank).count == bank.count, "The letter bank must not contain duplicates.")
        self.bank = bank
        self.lastShownLetter = precedingLetter
    }

    /// Draws and records the next letter. `startingNewRow` is true for the first letter of every row.
    mutating func nextLetter<G: RandomNumberGenerator>(
        startingNewRow: Bool,
        using generator: inout G
    ) -> String {
        var candidates = allowedNextLetters(startingNewRow: startingNewRow)
        if candidates.isEmpty {
            var relaxation = Relaxation.prefixRule
            candidates = candidateLetters(
                startingNewRow: startingNewRow,
                enforcesSlotRule: true,
                enforcesPrefixRule: false
            )
            if candidates.isEmpty {
                relaxation = .prefixAndSlotRules
                candidates = candidateLetters(
                    startingNewRow: startingNewRow,
                    enforcesSlotRule: false,
                    enforcesPrefixRule: false
                )
            }
            relaxedDraws.append(RelaxedDraw(
                slot: rowState(startingNewRow: startingNewRow).row.count,
                relaxation: relaxation
            ))
        }
        // R1 (per block) and R2 alone always leave a letter in a bank of two or more.
        guard let letter = candidates.randomElement(using: &generator) else {
            preconditionFailure("R1 and R2 left no letter; the bank invariant was broken.")
        }
        record(letter, startingNewRow: startingNewRow)
        return letter
    }

    /// The letters R1–R4 allow next, in bank order, without relaxing anything.
    func allowedNextLetters(startingNewRow: Bool) -> [String] {
        candidateLetters(startingNewRow: startingNewRow, enforcesSlotRule: true, enforcesPrefixRule: true)
    }

    /// Records `letter` as presented. `nextLetter` calls this; tests use it to script histories.
    mutating func record(_ letter: String, startingNewRow: Bool) {
        let state = rowState(startingNewRow: startingNewRow)
        currentRow = state.row + [letter]
        previousRow = state.previous
        earlierRowPrefixes = state.prefixes
        lastShownLetter = letter
    }

    private func candidateLetters(
        startingNewRow: Bool,
        enforcesSlotRule: Bool,
        enforcesPrefixRule: Bool
    ) -> [String] {
        let state = rowState(startingNewRow: startingNewRow)
        let slot = state.row.count
        let lettersInBlock = state.row[(slot - slot % bank.count)...]
        let previousSlotLetter = state.previous.indices.contains(slot) ? state.previous[slot] : nil
        return bank.filter { letter in
            guard letter != lastShownLetter, !lettersInBlock.contains(letter) else { return false }
            if enforcesSlotRule, letter == previousSlotLetter { return false }
            if enforcesPrefixRule,
               slot == Self.comparedPrefixLength - 1,
               state.prefixes.contains(state.row + [letter]) {
                return false
            }
            return true
        }
    }

    /// The row history as it stands for the next draw: when that draw opens a row, the current row
    /// closes and becomes the previous row.
    private func rowState(
        startingNewRow: Bool
    ) -> (row: [String], previous: [String], prefixes: Set<[String]>) {
        guard startingNewRow, !currentRow.isEmpty else {
            return (currentRow, previousRow, earlierRowPrefixes)
        }
        var prefixes = earlierRowPrefixes
        if currentRow.count >= Self.comparedPrefixLength {
            prefixes.insert(Array(currentRow.prefix(Self.comparedPrefixLength)))
        }
        return ([], currentRow, prefixes)
    }
}
