import XCTest
@testable import Distance_Measure_Test

/// Covers the spoken "skip" and no-input additions to the ETDRS voice test: the pure text
/// rules in `ETDRSSpokenResponseClassifier`, the `ETDRSNonLetterResponse` sentinels and how
/// they travel through the progression collector and CSV, the `ETDRSNoInputRules` deadline
/// decision, and the controller wiring that the UIKit-bound parts cannot exercise directly.
final class ETDRSSpokenResponseTests: XCTestCase {
    private let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private let sentinels = [ETDRSNonLetterResponse.skipped, ETDRSNonLetterResponse.noInput]

    // MARK: - Skip vocabulary

    /* A skip word resolves the trial as a scored miss, so every entry in the table has to
       do two things at once: classify as a skip, and never leak through the letter mapper
       (which would make the same utterance a miss on one path and a letter on the other).
       Whisper's casing and trailing punctuation vary from pass to pass, so the punctuated
       and padded forms have to normalize to the same answer as the bare table entry.
     */
    func testEverySkipPhraseIsASkipAndNeverALetter() {
        for phrase in ETDRSSpokenResponseClassifier.skipPhrases {
            XCTAssertTrue(ETDRSSpokenResponseClassifier.isSkipPhrase(phrase), phrase)
            XCTAssertNil(ETDRSSpokenResponseClassifier.normalizeLetter(from: phrase), phrase)
        }

        for spoken in ["skip", "Skip.", "SKIP!", "  skip  "] {
            XCTAssertTrue(ETDRSSpokenResponseClassifier.isSkipPhrase(spoken), spoken)
            XCTAssertNil(ETDRSSpokenResponseClassifier.normalizeLetter(from: spoken), spoken)
        }
    }

    /* Children rarely say a bare "skip": it arrives wrapped in hesitation ("um skip") or a
       polite tail ("skip it", "please skip"). None of those extra words is a letter
       pronunciation, so the utterance is unambiguous and must still resolve as a skip.
       Otherwise the participant is left talking into an open microphone until the no-input
       deadline scores the same miss five seconds later, with no sign they were heard.
       "skip thank you" and "skip, bye" belong here too: Whisper appends "Thank you." / "Bye."
       to real speech as a silence hallucination, and those words are filtered out before the
       letter check even though YOU doubles as the U pronunciation.
     */
    func testSkipWithFillerOrNonLetterTailStillSkips() {
        for spoken in ["um skip", "Uh, skip.", "skip it", "skip this one", "please skip", "skip thank you", "Skip, bye."] {
            XCTAssertTrue(ETDRSSpokenResponseClassifier.isSkipPhrase(spoken), spoken)
            XCTAssertNil(ETDRSSpokenResponseClassifier.normalizeLetter(from: spoken), spoken)
        }
    }

    /* A skip word beside a letter is a self-correction or a mis-hearing we cannot resolve,
       so the classifier must call it neither and keep listening rather than guess. The case
       that matters is "okay skip": OKAY is a K correction in the pronunciation table, and
       before the skip rule was added to normalizeLetter the last-mapped-token rule scored
       it as K — a wrong answer recorded for a child who said they could not see the letter.
     */
    func testSkipBesideALetterIsNeitherSkipNorLetter() {
        for spoken in ["c skip", "skip see", "okay skip", "S, skip"] {
            XCTAssertFalse(ETDRSSpokenResponseClassifier.isSkipPhrase(spoken), spoken)
            XCTAssertNil(ETDRSSpokenResponseClassifier.normalizeLetter(from: spoken), spoken)
        }
    }

    /* The tier-2 near-misses (SKI, KIP, SKIT, SKID, SKIFF) are short real words Whisper can
       also produce by fusing an "S… K" self-correction, and a false skip costs a scored
       letter while a missed skip only keeps the microphone open. They stay out of the table
       until device logs justify them, and this pins that they are neither a skip nor a
       letter. The un-fused "S K" is pinned alongside: Visinear's last-single-letter rule
       still scores it K, untouched by the skip work — deliberately different from Myotect,
       which treats two letters in one utterance as ambiguous and retries.
     */
    func testTierTwoNearMissesAreNotSkipsAndSKStillScoresK() {
        for spoken in ["ski", "kip", "skit", "skid", "skiff"] {
            XCTAssertFalse(ETDRSSpokenResponseClassifier.isSkipPhrase(spoken), spoken)
            XCTAssertNil(ETDRSSpokenResponseClassifier.normalizeLetter(from: spoken), spoken)
        }

        XCTAssertFalse(ETDRSSpokenResponseClassifier.isSkipPhrase("S K"))
        XCTAssertEqual(ETDRSSpokenResponseClassifier.normalizeLetter(from: "S K"), "K")
    }

    /* The skip table is consulted after the letter tables in normalizeLetter and alongside
       them in isSkipPhrase, so a single shared spelling would make one utterance a letter on
       one path and a skip on the other. Every entry must also already be in cleaned form —
       uppercase letters only — because both lookups compare against cleanedTranscriptToken
       output, and a lowercase or punctuated entry could never match a transcript at all.
     */
    func testSkipPhrasesNeverCollideWithLetterTables() {
        XCTAssertFalse(ETDRSSpokenResponseClassifier.skipPhrases.isEmpty)

        for phrase in ETDRSSpokenResponseClassifier.skipPhrases {
            XCTAssertEqual(
                ETDRSSpokenResponseClassifier.cleanedTranscriptToken(from: phrase),
                phrase,
                "\(phrase) is not in cleaned form and could never match a transcript."
            )
            XCTAssertNil(ETDRSSpokenResponseClassifier.letterPronunciationMap[phrase], phrase)
            XCTAssertNil(ETDRSSpokenResponseClassifier.misidentificationMap[phrase], phrase)
            XCTAssertFalse(ETDRSSpokenResponseClassifier.fillerPhrases.contains(phrase), phrase)
            XCTAssertFalse(ETDRSSpokenResponseClassifier.ignorableNonAnswerPhrases.contains(phrase), phrase)
            XCTAssertFalse(ETDRSSpokenResponseClassifier.recognizedLetters.contains(phrase), phrase)
            XCTAssertFalse(ETDRSSpokenResponseClassifier.tokenMapsToLetter(phrase), phrase)
        }
    }

    /* The classifier used to live as private members of ETDRSWhisperLetterService with no
       coverage; moving it into a file-level enum was meant to change nothing but the two
       skip rules. These pin the behaviours the move carried over — whole-string lookup,
       misidentification recovery, the last-mapped-token rule, filler and silence-
       hallucination detection, and the punctuation-stripping cleaner — so a slip in the
       port shows up here rather than as a mis-scored letter on a device.
     */
    func testMovedClassifierRulesKeepTheirOriginalBehaviour() {
        XCTAssertEqual(ETDRSSpokenResponseClassifier.normalizeLetter(from: "SEE"), "C")
        XCTAssertEqual(ETDRSSpokenResponseClassifier.normalizeLetter(from: "eggs"), "X")
        XCTAssertEqual(ETDRSSpokenResponseClassifier.normalizeLetter(from: "okay"), "K")
        XCTAssertEqual(
            ETDRSSpokenResponseClassifier.normalizeLetter(from: "C-D"),
            "D",
            "Two mapped tokens resolve to the last one."
        )

        XCTAssertTrue(ETDRSSpokenResponseClassifier.isFillerPhrase("um"))
        XCTAssertFalse(ETDRSSpokenResponseClassifier.isFillerPhrase("um skip"))

        XCTAssertTrue(ETDRSSpokenResponseClassifier.isIgnorableNonAnswerPhrase("BLANK AUDIO"))
        XCTAssertTrue(ETDRSSpokenResponseClassifier.isIgnorableNonAnswerPhrase(""))
        XCTAssertFalse(ETDRSSpokenResponseClassifier.isIgnorableNonAnswerPhrase("skip"))
        XCTAssertFalse(ETDRSSpokenResponseClassifier.isIgnorableNonAnswerPhrase("C"))

        XCTAssertEqual(ETDRSSpokenResponseClassifier.cleanedTranscriptToken(from: "."), "")
        XCTAssertEqual(ETDRSSpokenResponseClassifier.cleanedTranscriptToken(from: "Skip."), "SKIP")
    }

    /* The no-input deadline transcribes up to five seconds of a silent room, which is exactly
       when Whisper invents text: "Thank you.", "you", "Bye.", "The end." Before this change
       none of those was in the ignorable set and "you" mapped to U, so a silent window could be
       recorded as a spoken U — an incorrect trial that also reset the consecutive-no-input
       backstop. They are ignorable now (the vocabulary Myotect uses for the same reason), they
       never map to a letter, and a real letter followed by a hallucinated tail keeps the letter.
     */
    func testSilenceHallucinationsAreIgnorableAndNeverMapToALetter() {
        for spoken in ["Thank you.", "you", "You", "Bye.", "The end.", "Thanks for watching!"] {
            XCTAssertTrue(ETDRSSpokenResponseClassifier.isIgnorableNonAnswerPhrase(spoken), spoken)
            XCTAssertNil(ETDRSSpokenResponseClassifier.normalizeLetter(from: spoken), spoken)
            XCTAssertFalse(ETDRSSpokenResponseClassifier.isSkipPhrase(spoken), spoken)
        }

        XCTAssertEqual(ETDRSSpokenResponseClassifier.normalizeLetter(from: "C, thank you."), "C")
        XCTAssertEqual(ETDRSSpokenResponseClassifier.normalizeLetter(from: "um, K"), "K")
        XCTAssertFalse(ETDRSSpokenResponseClassifier.isIgnorableNonAnswerPhrase("C, thank you."))
    }

    // MARK: - Non-letter sentinels

    /* scoreResponse decides correctness with a plain `response == currentLetter`, and the
       ETDRS letters are single uppercase characters, so a sentinel is incorrect by
       construction only while it stays lowercase and longer than one character.
       TestProgressionCSVFormatter.field quotes anything holding a comma, quote or line
       break; keeping the sentinels free of those keeps User_Response unquoted, which is
       what Myotect writes and what the shared analysis compares against.
     */
    func testNonLetterSentinelsCanNeverScoreCorrectOrBreakTheCSV() {
        XCTAssertNotEqual(ETDRSNonLetterResponse.skipped, ETDRSNonLetterResponse.noInput)

        for sentinel in sentinels {
            XCTAssertNotEqual(sentinel, sentinel.uppercased(), sentinel)
            XCTAssertGreaterThan(sentinel.count, 1, sentinel)
            for forbidden in [",", "\"", "\n", "\r"] {
                XCTAssertFalse(
                    sentinel.contains(forbidden),
                    "\(sentinel) contains a character the CSV formatter would quote."
                )
            }
            XCTAssertFalse(ETDRSSpokenResponseClassifier.recognizedLetters.contains(sentinel), sentinel)
        }
    }

    /* The sentinels are only useful if they survive the trip a real trial takes: recorded
       through TestProgressionDataCollector, encoded into UserDefaults, decoded back by a
       fresh collector and formatted for the CSV that leaves the device. This drives that
       path end to end for a skip row and a no-input row against an isolated defaults suite,
       and checks the exported line still has one field per header with User_Response
       carrying the sentinel verbatim and Is_Correct FALSE — a quoted or shifted column
       would silently misalign every downstream analysis.
     */
    func testNonLetterResponsesRoundTripThroughTheCollectorUnquotedAndAligned() throws {
        let suiteName = "ETDRSSpokenResponseTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let collector = TestProgressionDataCollector(defaults: defaults)
        let provenance = SizingProvenance(
            sizingVersion: SizingProvenance.currentVersion,
            calibrationSource: .manual,
            pointsPerMillimeter: 6.05,
            screenSignature: "screen-v2",
            targetHeightMillimeters: 5.818,
            renderedHeightPoints: 35.1989
        )

        collector.startNewSession(eye: "Right", testType: "ETDRS")
        for (index, sentinel) in sentinels.enumerated() {
            collector.recordResponse(
                eye: "Right",
                testType: "ETDRS",
                acuityLevel: "20/200",
                letterDisplayed: "C",
                distanceCM: 40,
                responseTimeMS: 5_000,
                userResponse: sentinel,
                isCorrect: false,
                trialNumber: index + 1,
                sizingProvenance: provenance,
                protocolMetadata: ETDRSProtocolConfiguration.fiveLetterV1.metadata
            )
        }
        collector.endCurrentSession()

        let records = TestProgressionDataCollector(defaults: defaults).getAllStoredProgressionData()
        XCTAssertEqual(records.map(\.userResponse), sentinels)
        XCTAssertTrue(records.allSatisfy { !$0.isCorrect })

        let headers = TestProgressionCSVFormatter.responseHeaders
        let userResponseColumn = try XCTUnwrap(headers.firstIndex(of: "User_Response"))
        let isCorrectColumn = try XCTUnwrap(headers.firstIndex(of: "Is_Correct"))
        XCTAssertEqual(
            TestProgressionCSVFormatter.header()
                .split(separator: ",", omittingEmptySubsequences: false)
                .count,
            headers.count
        )

        for record in records {
            let columns = TestProgressionCSVFormatter.row(for: record)
                .split(separator: ",", omittingEmptySubsequences: false)
            guard columns.count == headers.count else {
                XCTFail("\(record.userResponse) row has \(columns.count) columns, expected \(headers.count).")
                continue
            }
            XCTAssertEqual(String(columns[userResponseColumn]), record.userResponse)
            XCTAssertEqual(String(columns[isCorrectColumn]), "FALSE", record.userResponse)
        }
    }

    // MARK: - No-input deadline

    /* The deadline decision is the one piece of the no-input flow that can be reasoned
       about without a microphone, and it encodes three commitments: silence is a miss
       straight away, even after a retry; unclear speech earns same-letter retries only up
       to the cap; and only the first retry carries the spoken "Try again." so a hesitant
       child is prompted once, not nagged. A cap of zero has to degrade to the plain miss so
       the constants can be tuned without touching the rule.
     */
    func testNoInputRuleRetriesOnlyForHeardSpeechWithinTheCap() {
        XCTAssertEqual(
            ETDRSNoInputRules.resolve(heardSpeech: false, retriesUsed: 0, maxRetries: 2),
            .scoreNoInput
        )
        XCTAssertEqual(
            ETDRSNoInputRules.resolve(heardSpeech: true, retriesUsed: 0, maxRetries: 2),
            .retry(withPrompt: true)
        )
        XCTAssertEqual(
            ETDRSNoInputRules.resolve(heardSpeech: true, retriesUsed: 1, maxRetries: 2),
            .retry(withPrompt: false)
        )
        XCTAssertEqual(
            ETDRSNoInputRules.resolve(heardSpeech: true, retriesUsed: 2, maxRetries: 2),
            .scoreNoInput
        )
        XCTAssertEqual(
            ETDRSNoInputRules.resolve(heardSpeech: false, retriesUsed: 1, maxRetries: 2),
            .scoreNoInput,
            "Silence after a retry is still a miss."
        )
        XCTAssertEqual(
            ETDRSNoInputRules.resolve(heardSpeech: true, retriesUsed: 0, maxRetries: 0),
            .scoreNoInput,
            "A zero retry cap degrades to the plain miss."
        )
    }

    // MARK: - Listening buffer bookkeeping

    /* The consumed pointer decides what the next live pass and the deadline flush get to hear.
       Three commitments: a pass that produced text, and the final flush, consume everything they
       saw; an empty live pass ("." on near-silence) leaves the newest retained span unconsumed so
       an utterance straddling the pass boundary keeps its onset, but consumes the rest so the same
       noise is not re-transcribed back-to-back; and the pointer never moves backwards, so a late
       pass with a stale, smaller snapshot cannot re-open audio a newer pass already consumed.
     */
    func testConsumedPointerAdvancesForTextAndFinalButRetainsATailAfterAnEmptyPass() {
        XCTAssertEqual(
            ETDRSListeningBufferRules.consumedSampleCount(
                current: 1_000, bufferCount: 48_000, isFinal: false, producedAnswer: true, retainedSamples: 4_000),
            48_000
        )
        XCTAssertEqual(
            ETDRSListeningBufferRules.consumedSampleCount(
                current: 1_000, bufferCount: 48_000, isFinal: true, producedAnswer: false, retainedSamples: 4_000),
            48_000
        )
        XCTAssertEqual(
            ETDRSListeningBufferRules.consumedSampleCount(
                current: 1_000, bufferCount: 48_000, isFinal: false, producedAnswer: false, retainedSamples: 4_000),
            44_000,
            "An empty live pass keeps the newest retained span."
        )
        XCTAssertEqual(
            ETDRSListeningBufferRules.consumedSampleCount(
                current: 46_000, bufferCount: 48_000, isFinal: false, producedAnswer: false, retainedSamples: 4_000),
            46_000,
            "The pointer never moves backwards."
        )
        XCTAssertEqual(
            ETDRSListeningBufferRules.consumedSampleCount(
                current: 50_000, bufferCount: 48_000, isFinal: true, producedAnswer: true, retainedSamples: 4_000),
            50_000,
            "A stale, smaller snapshot cannot re-open consumed audio."
        )
        XCTAssertEqual(
            ETDRSListeningBufferRules.consumedSampleCount(
                current: 0, bufferCount: 2_000, isFinal: false, producedAnswer: false, retainedSamples: 4_000),
            0,
            "A buffer shorter than the retained span stays wholly unconsumed."
        )
    }

    /* The live loop used to hand Whisper the first syllable of an answer: WhisperKit's voice check
       looks at the OLDEST part of a span, so at the start of a window it fires the moment speech
       begins, and Whisper completes a truncated "C" into a word like "seat". A pass now waits for
       the utterance to END (a quiet 0.3 s tail after voice in the unconsumed span), transcribes
       a sound that stays continuous past the cap anyway, and never runs on silence.
     */
    func testLivePassWaitsForTheUtteranceToEnd() {
        let quietTail = 3
        let cap = 20
        let silence = Array(repeating: false, count: 10)
        XCTAssertFalse(ETDRSListeningBufferRules.shouldRunLivePass(
            voice: silence, unconsumedFromBlock: 0, quietTailBlocks: quietTail, maximumUtteranceBlocks: cap))

        let speaking = silence + [true, true, true]
        XCTAssertFalse(
            ETDRSListeningBufferRules.shouldRunLivePass(
                voice: speaking, unconsumedFromBlock: 0, quietTailBlocks: quietTail, maximumUtteranceBlocks: cap),
            "Mid-utterance: the newest blocks are still voice."
        )

        let ended = speaking + [false, false, false]
        XCTAssertTrue(ETDRSListeningBufferRules.shouldRunLivePass(
            voice: ended, unconsumedFromBlock: 0, quietTailBlocks: quietTail, maximumUtteranceBlocks: cap))

        XCTAssertFalse(
            ETDRSListeningBufferRules.shouldRunLivePass(
                voice: ended, unconsumedFromBlock: ended.count - 2, quietTailBlocks: quietTail, maximumUtteranceBlocks: cap),
            "Voice that an earlier pass already consumed does not trigger another."
        )

        let continuous = silence + Array(repeating: true, count: cap)
        XCTAssertTrue(
            ETDRSListeningBufferRules.shouldRunLivePass(
                voice: continuous, unconsumedFromBlock: 0, quietTailBlocks: quietTail, maximumUtteranceBlocks: cap),
            "A sound that never pauses is transcribed once it reaches the cap."
        )
        XCTAssertFalse(ETDRSListeningBufferRules.shouldRunLivePass(
            voice: silence + Array(repeating: true, count: cap - 1),
            unconsumedFromBlock: 0, quietTailBlocks: quietTail, maximumUtteranceBlocks: cap))

        // A pass that produced no answer retains exactly the quiet tail (3 blocks). The retained
        // region holds no voice, so it cannot re-trigger a pass on the fragment before it —
        // retaining more would, which is why retainedSecondsAfterNonAnswerPass equals
        // utteranceEndQuietSeconds.
        let fragment = silence + [true, true, true, true, false, false, false]
        XCTAssertFalse(ETDRSListeningBufferRules.shouldRunLivePass(
            voice: fragment, unconsumedFromBlock: fragment.count - 3, quietTailBlocks: quietTail, maximumUtteranceBlocks: cap))
        XCTAssertTrue(
            ETDRSListeningBufferRules.shouldRunLivePass(
                voice: fragment, unconsumedFromBlock: fragment.count - 5, quietTailBlocks: quietTail, maximumUtteranceBlocks: cap),
            "A retained span longer than the quiet tail re-triggers on the fragment."
        )
    }

    /* An answer already under way when the session arms (the participant started during the
       inter-letter gap, which the warm engine recorded) must be transcribed from its onset, not
       from the arm instant. The pre-roll is the run of voice immediately before the session that
       continues into its first block, and nothing when the session started in silence.
     */
    func testPreRollReachesBackOverContiguousVoiceOnly() {
        XCTAssertEqual(ETDRSListeningBufferRules.preRollBlocks(preSessionVoice: [false, true, true], sessionVoice: [true, false]), 2)
        XCTAssertEqual(ETDRSListeningBufferRules.preRollBlocks(preSessionVoice: [true, false, true], sessionVoice: [true]), 1)
        XCTAssertEqual(ETDRSListeningBufferRules.preRollBlocks(preSessionVoice: [true, true], sessionVoice: [false, true]), 0, "The session did not start in voice.")
        XCTAssertEqual(ETDRSListeningBufferRules.preRollBlocks(preSessionVoice: [true, true], sessionVoice: []), 0)
        XCTAssertEqual(ETDRSListeningBufferRules.preRollBlocks(preSessionVoice: [], sessionVoice: [true]), 0, "A cold engine has nothing before the session.")
    }

    /* The energies behind that decision are our own, computed WhisperKit's way (dB relative to the
       quietest of the previous 2 s) but without its two start-up artifacts: the first block has no
       reference and reads as silence rather than as voice, and a digital-zero buffer — which
       AVAudioEngine can deliver as it starts — is never used as the reference, so ordinary room
       noise does not read as voice for the whole window that follows.
     */
    func testRelativeEnergiesIgnoreDigitalZeroReferencesAndStartQuiet() {
        let room: Float = 0.003
        let speech: Float = 0.05

        let plain = ETDRSListeningBufferRules.relativeEnergies(blockEnergies: [room, room, speech, room])
        XCTAssertEqual(plain[0], 0, "No reference yet.")
        XCTAssertEqual(plain[1], 0, accuracy: 0.001, "Same level as the reference.")
        XCTAssertGreaterThan(plain[2], 0.10, "Speech well above the room floor.")
        XCTAssertEqual(plain[3], 0, accuracy: 0.001)

        let zeroStart = ETDRSListeningBufferRules.relativeEnergies(blockEnergies: [0, room, room, speech])
        XCTAssertEqual(zeroStart[1], 0, "A digital-zero block is not a reference.")
        XCTAssertEqual(zeroStart[2], 0, accuracy: 0.001, "Room noise stays quiet after a zero block.")
        XCTAssertGreaterThan(zeroStart[3], 0.10)

        let rampIn = ETDRSListeningBufferRules.relativeEnergies(blockEnergies: [1e-5, room, room, speech])
        XCTAssertEqual(rampIn[1], 0, "A near-silent ramp-in block (below -80 dBFS) is not a reference either.")
        XCTAssertEqual(rampIn[2], 0, accuracy: 0.001)
        XCTAssertGreaterThan(rampIn[3], 0.10)

        XCTAssertEqual(ETDRSListeningBufferRules.relativeEnergies(blockEnergies: [0, 0, 0]), [0, 0, 0])
        XCTAssertTrue(ETDRSListeningBufferRules.relativeEnergies(blockEnergies: []).isEmpty)

        let voice = ETDRSListeningBufferRules.voiceBlocks(relativeEnergies: plain, silenceThreshold: 0.10)
        XCTAssertEqual(voice, [false, false, true, false])
    }

    /* Block energies are plain RMS per 1600 samples; the trailing partial block is dropped so the
       trace never contains a half-filled value that would read as quieter than it is.
     */
    func testBlockEnergiesAreRMSPerFullBlock() {
        let block = ETDRSListeningBufferRules.energyBlockSamples
        var samples = [Float](repeating: 0, count: block * 2 + 100)
        for index in block..<(block * 2) {
            samples[index] = index % 2 == 0 ? 0.5 : -0.5
        }
        let energies = ETDRSListeningBufferRules.blockEnergies(samples[...])
        XCTAssertEqual(energies.count, 2)
        XCTAssertEqual(energies[0], 0)
        XCTAssertEqual(energies[1], 0.5, accuracy: 0.0001)

        // The service passes slices that start mid-buffer (the session start, minus the
        // reference window); block boundaries follow the slice, not the parent array.
        let offset = ETDRSListeningBufferRules.blockEnergies(samples[block...])
        XCTAssertEqual(offset.count, 1)
        XCTAssertEqual(offset[0], 0.5, accuracy: 0.0001)
        XCTAssertTrue(ETDRSListeningBufferRules.blockEnergies([Float](repeating: 0.1, count: block - 1)[...]).isEmpty)
    }

    /* The deadline decides whether text found only by the final flush may be scored by asking
       whether the window held a speech-length sound: two consecutive voice blocks. A spoken letter
       spans several; a single click or chair creak does not.
     */
    func testWindowHadVoiceNeedsTwoConsecutiveVoiceBlocks() {
        XCTAssertFalse(ETDRSListeningBufferRules.windowHadVoice(voice: []))
        XCTAssertFalse(ETDRSListeningBufferRules.windowHadVoice(voice: [true]))
        XCTAssertFalse(ETDRSListeningBufferRules.windowHadVoice(voice: [false, true, false, true, false]))
        XCTAssertTrue(ETDRSListeningBufferRules.windowHadVoice(voice: [false, true, true, false]))
    }

    // MARK: - Controller wiring

    /* The controller and the model-ready screen are UIKit-bound, so the wiring the rules
       above depend on is pinned in source. The scoring path must record the shared
       sentinels rather than local strings; the no-input window must be 5 s and armed per
       listening generation so a stale timer cannot score a later letter; the old 15 s
       "Still listening" restart that never scored anything must be gone; the service must
       surface isSkip through the classifier; and the ready announcement must say "Tap",
       because Start Test is a single-tap control and the announcement is spoken to every
       participant with audio instructions on, not only to VoiceOver users.
     */
    func testSourcePinsForSpokenResponseWiring() throws {
        let controller = try source(at: "Distance Measure Test/Features/ETDRS/ETDRSViewController.swift")
        XCTAssertTrue(controller.contains("ETDRSNonLetterResponse.skipped"))
        XCTAssertTrue(controller.contains("ETDRSNonLetterResponse.noInput"))
        XCTAssertTrue(controller.contains("noInputWindowSeconds: TimeInterval = 5"))
        XCTAssertTrue(controller.contains("startNoInputTimer(generation: generation)"))
        XCTAssertFalse(controller.contains("withTimeInterval: 15.0"))
        XCTAssertFalse(controller.contains("Still listening"))
        // Streaming partials must never reach the scoring path — the first tokens of "okay skip"
        // are "Okay", a K correction — and must never count as engagement, or the "Thank" prefix
        // of a hallucinated "Thank you." would earn a silent participant two extra windows.
        let partialBranch = try XCTUnwrap(
            controller.range(of: "if prediction.isPartial {").flatMap { start in
                controller.range(of: "return\n        }", range: start.upperBound..<controller.endIndex)
                    .map { controller[start.lowerBound..<$0.upperBound] }
            }
        )
        XCTAssertFalse(partialBranch.contains("heardSpeechThisWindow = true"))
        XCTAssertFalse(partialBranch.contains("scoreResponse("))
        // An answer found only by the deadline flush counts only when voice was detected in the
        // window; the flush that could not inspect the audio is asked again, not scored.
        XCTAssertTrue(controller.contains("if isAnswer, voiceHeard {"))
        XCTAssertTrue(controller.contains("case .pending:"))
        // The retry cue survives the hidden transcription pill.
        XCTAssertTrue(controller.contains("instructionLabel.text = Self.retryInstruction"))
        // Nothing arms behind the End Test confirmation or during the inter-letter gap.
        XCTAssertTrue(controller.contains("guard !isConfirmingEndTest, !isBetweenLetters else { return }"))
        XCTAssertTrue(controller.contains("isConfirmingEndTest = true"))
        // The service session is reserved synchronously on the main thread, so a stop that lands
        // before the async start body runs out-ranks it; a start that finds itself superseded
        // with no session alive stops the engine it just armed.
        XCTAssertTrue(controller.contains("let sessionToken = whisperLetterService.reserveStart()"))
        XCTAssertTrue(controller.contains("if !self.isListening { self.whisperLetterService.stopListening() }"))
        // A failed start retries, then parks on the pause path — it never strands the letter.
        XCTAssertTrue(controller.contains("self.handleStartFailure(error)"))

        let service = try source(at: "Distance Measure Test/Features/ETDRS/ETDRSWhisperLetterService.swift")
        XCTAssertTrue(service.contains("isSkip: ETDRSSpokenResponseClassifier.isSkipPhrase(rawText)"))
        XCTAssertTrue(service.contains("isPartial: true"))
        // A pass from a superseded session must not write the next session's consumed pointer,
        // and starts are serialized so a superseded start tears down only its own engine.
        XCTAssertTrue(service.contains("guard session == startRequestToken else { return nil }"))
        XCTAssertTrue(service.contains("try await self.performStart(token: token, onPrediction: onPrediction)"))
        XCTAssertTrue(service.contains("private func tearDownListening(keepEngine: Bool)"))
        XCTAssertTrue(service.contains("func reserveStart() -> Int"))
        // The deadline judges voice over the whole window, and live passes wait for the end of
        // the utterance — both on our own energies, never on WhisperKit's prefix heuristic.
        XCTAssertTrue(service.contains("ETDRSListeningBufferRules.windowHadVoice(voice: snapshot.voice)"))
        XCTAssertTrue(service.contains("ETDRSListeningBufferRules.shouldRunLivePass("))
        XCTAssertFalse(service.contains("AudioProcessor.isVoiceDetected"))
        // A pass that produced no answer must not consume a straddling onset.
        XCTAssertTrue(service.contains("producedAnswer: prediction.normalizedLetter != nil || prediction.isSkip"))
        // The microphone stays warm between letters so the next session arms instantly; a warm
        // engine that died is detected and restarted; the retained tail equals the quiet tail.
        XCTAssertTrue(service.contains("func suspendListening()"))
        XCTAssertTrue(controller.contains("stopListening(keepMicrophoneWarm: true)"))
        XCTAssertTrue(service.contains("audioEngine?.isRunning == true"))
        XCTAssertTrue(service.contains("self.restartEngineIfStalled(session: token)"))
        XCTAssertTrue(service.contains("utteranceEndQuietSeconds: Float = 0.3"))
        XCTAssertTrue(service.contains("retainedSecondsAfterNonAnswerPass: Float = 0.3"))

        let loading = try source(at: "Distance Measure Test/Features/ETDRS/ETDRSWhisperLoadingViewController.swift")
        XCTAssertTrue(loading.contains("Tap Start Test to continue"))
        XCTAssertFalse(loading.contains("Double tap"))
    }

    private func source(at path: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(path),
            encoding: .utf8
        )
    }
}
