import XCTest
@testable import Distance_Measure_Test

final class PersistenceAndArchitectureTests: XCTestCase {
    func testLegacyResponseDecodesAsUnknownSizing() throws {
        let json = """
        {
          "timestamp": 0,
          "eye": "Right",
          "testType": "ETDRS",
          "acuityLevel": "20/200",
          "letterDisplayed": "C",
          "distanceCM": 40,
          "responseTimeMS": 500,
          "userResponse": "C",
          "isCorrect": true,
          "trialNumber": 1,
          "sessionId": "legacy"
        }
        """
        let response = try JSONDecoder().decode(
            TestResponseData.self,
            from: Data(json.utf8)
        )

        XCTAssertNil(response.sizingVersion)
        XCTAssertEqual(response.calibrationSource, .legacyUnknown)
        XCTAssertNil(response.pointsPerMillimeter)
        XCTAssertNil(response.targetHeightMillimeters)
        XCTAssertNil(response.renderedHeightPoints)
        XCTAssertNil(response.protocolMetadata)
    }

    func testVersionTwoResponseRoundTripsWithSizingProvenance() throws {
        let response = TestResponseData(
            timestamp: Date(timeIntervalSinceReferenceDate: 123),
            eye: "Right",
            testType: "ETDRS",
            acuityLevel: "20/200",
            letterDisplayed: "C",
            distanceCM: 40,
            responseTimeMS: 500,
            userResponse: "C",
            isCorrect: true,
            trialNumber: 1,
            sessionId: "v2",
            sizingVersion: 2,
            calibrationSource: .deviceDatabase,
            pointsPerMillimeter: 460 / 3 / 25.4,
            screenSignature: "iPhone16,1|1179x2556|3.0000",
            targetHeightMillimeters: 5.818,
            renderedHeightPoints: 35.13,
            protocolMetadata: ETDRSProtocolConfiguration.fiveLetterV1.metadata
        )

        let decoded = try JSONDecoder().decode(
            TestResponseData.self,
            from: JSONEncoder().encode(response)
        )

        XCTAssertEqual(decoded.sizingVersion, 2)
        XCTAssertEqual(decoded.calibrationSource, .deviceDatabase)
        XCTAssertEqual(decoded.pointsPerMillimeter, response.pointsPerMillimeter)
        XCTAssertEqual(decoded.screenSignature, response.screenSignature)
        XCTAssertEqual(decoded.targetHeightMillimeters, response.targetHeightMillimeters)
        XCTAssertEqual(decoded.renderedHeightPoints, response.renderedHeightPoints)
        XCTAssertEqual(decoded.protocolMetadata, response.protocolMetadata)
    }

    func testCollectorLoadsLegacyStorageAndExportsEverySizingColumn() throws {
        let suiteName = "TestProgressionDataCollectorTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacyJSON = """
        [{
          "timestamp": 0,
          "eye": "Right",
          "testType": "ETDRS",
          "acuityLevel": "20/200",
          "letterDisplayed": "C",
          "distanceCM": 40,
          "responseTimeMS": 500,
          "userResponse": "C",
          "isCorrect": true,
          "trialNumber": 1,
          "sessionId": "legacy"
        }]
        """
        defaults.set(Data(legacyJSON.utf8), forKey: "TestProgressionData")
        let collector = TestProgressionDataCollector(defaults: defaults)

        let records = collector.getAllStoredProgressionData()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.calibrationSource, .legacyUnknown)

        let csv = collector.generateCombinedCSV()
        XCTAssertTrue(csv.hasPrefix(
            "Timestamp,Eye,Test_Type,Acuity_Level,Letter_Displayed,Distance_CM,Response_Time_MS,User_Response,Is_Correct,Trial_Number,Session_ID,Sizing_Version,Calibration_Source,Points_Per_MM,Screen_Signature,Target_Height_MM,Rendered_Height_Points,Protocol_ID,Trials_Per_Acuity,Correct_To_Advance,Early_Perfect_Count,LogMAR_Per_Letter\n"
        ))
        let rows = csv.components(separatedBy: "\n")
        let legacyColumns = rows[1].split(
            separator: ",",
            omittingEmptySubsequences: false
        )
        XCTAssertEqual(legacyColumns.count, 22)
        XCTAssertTrue(legacyColumns.suffix(5).allSatisfy(\.isEmpty))
    }

    func testVersionTwoCSVExportsValuesAndEscapesTextFields() throws {
        let suiteName = "TestProgressionCSVTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let response = TestResponseData(
            timestamp: Date(timeIntervalSinceReferenceDate: 123),
            eye: "Right",
            testType: "ETDRS",
            acuityLevel: "20/200",
            letterDisplayed: "C",
            distanceCM: 40,
            responseTimeMS: 500,
            userResponse: "C, \"heard\"",
            isCorrect: true,
            trialNumber: 1,
            sessionId: "v2",
            sizingVersion: 2,
            calibrationSource: .manual,
            pointsPerMillimeter: 6.05,
            screenSignature: "screen-v2",
            targetHeightMillimeters: 5.818,
            renderedHeightPoints: 35.1989,
            protocolMetadata: ETDRSProtocolConfiguration.fiveLetterV1.metadata
        )
        defaults.set(try JSONEncoder().encode([response]), forKey: "TestProgressionData")

        let csv = TestProgressionDataCollector(defaults: defaults).generateCombinedCSV()
        XCTAssertTrue(csv.contains("\"C, \"\"heard\"\"\""))
        XCTAssertTrue(csv.contains(
            ",2,manual,6.050000,screen-v2,5.818000,35.198900,etdrs-five-letter-v1,5,3,3,0.020000\n"
        ))
    }

    func testNamedProgressionCSVUsesSameSchemaAndEscaping() throws {
        let response = TestResponseData(
            timestamp: Date(timeIntervalSinceReferenceDate: 123),
            eye: "Right",
            testType: "ETDRS",
            acuityLevel: "20/200",
            letterDisplayed: "C",
            distanceCM: 40,
            responseTimeMS: 500,
            userResponse: "C",
            isCorrect: true,
            trialNumber: 1,
            sessionId: "v2",
            sizingVersion: 2,
            calibrationSource: .manual,
            pointsPerMillimeter: 6.05,
            screenSignature: "screen-v2",
            targetHeightMillimeters: 5.818,
            renderedHeightPoints: 35.1989,
            protocolMetadata: ETDRSProtocolConfiguration.fiveLetterV1.metadata
        )

        let header = TestProgressionCSVFormatter.header(
            includeParticipantName: true
        )
        let row = TestProgressionCSVFormatter.row(
            for: response,
            participantName: "Doe, Jane"
        )

        XCTAssertEqual(
            header,
            "Name," + TestProgressionCSVFormatter.responseHeaders.joined(separator: ",")
        )
        XCTAssertTrue(row.hasPrefix("\"Doe, Jane\","))
        XCTAssertTrue(row.hasSuffix(
            ",etdrs-five-letter-v1,5,3,3,0.020000"
        ))
    }

    func testProgressionExportSurfacesUseSharedCSVFormatter() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let paths = [
            "Distance Measure Test/Features/Results/ResultViewController.swift",
            "Distance Measure Test/Features/Results/TestHistoryViewController.swift"
        ]

        for path in paths {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(path),
                encoding: .utf8
            )
            XCTAssertTrue(
                source.contains("TestProgressionCSVFormatter.header"),
                path
            )
            XCTAssertTrue(
                source.contains("TestProgressionCSVFormatter.row"),
                path
            )
            XCTAssertFalse(
                source.contains("Name,Timestamp,Eye,Test_Type"),
                path
            )
        }
    }

    func testEveryOptotypeControllerUsesSharedRendererOnly() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let controllerPaths = [
            "Distance Measure Test/Features/TestSetup/SelectAcuity.swift",
            "Distance Measure Test/Features/ETDRS/ETDRSViewController.swift",
            "Distance Measure Test/Features/LandoltC/TumblingEViewController.swift",
            "Distance Measure Test/Features/Results/DataCollectionViewController.swift"
        ]

        for path in controllerPaths {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(path),
                encoding: .utf8
            )
            XCTAssertTrue(source.contains("OptotypeRenderer.update"), path)
            XCTAssertTrue(source.contains("update.spec"), path)
            XCTAssertFalse(source.contains("OptotypeSizing.renderSpec"), path)
            XCTAssertFalse(source.contains("OptotypeRenderer.apply"), path)
            XCTAssertFalse(source.contains("VisualAcuitySession.devicePPI"), path)
            XCTAssertFalse(source.contains("Ppi.get"), path)
            XCTAssertFalse(source.contains("import DevicePpi"), path)
            XCTAssertFalse(source.contains("scaling_correction_factor"), path)
            XCTAssertFalse(source.contains("arcmin_per_letter"), path)
            XCTAssertFalse(source.contains("scaledBy(x:"), path)
            XCTAssertFalse(source.contains("distanceCM: averageDistanceCM"), path)
            XCTAssertFalse(source.contains("distanceCM: 40"), path)
        }
    }

    func testControllersUseCentralEyeDistanceProvider() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let controllerDirectory = repositoryRoot.appendingPathComponent("Distance Measure Test/Features")
        let paths = [
            "TestSetup/DistanceOptimization.swift",
            "TestSetup/SelectAcuity.swift",
            "ETDRS/ETDRSViewController.swift",
            "LandoltC/TumblingEViewController.swift",
            "Results/DataCollectionViewController.swift"
        ]

        for path in paths {
            let source = try String(
                contentsOf: controllerDirectory.appendingPathComponent(path),
                encoding: .utf8
            )
            XCTAssertTrue(source.contains("EyeDistanceProvider.shared"), path)
            XCTAssertFalse(source.contains("ARSCNViewDelegate"), path)
            XCTAssertFalse(source.contains("ARFaceTrackingConfiguration()"), path)
        }
    }

    /* The distance capture button must not carry its own storyboard segue: the
       tap only starts the hold countdown, and the push to acuity selection has
       to wait until the phone has been held steady long enough to trust the
       reading. Re-attaching a segue to the button in Interface Builder would
       silently restore the old capture-on-tap behavior, so this pins the
       wiring the countdown depends on — the button's action selector and the
       view controller's identified segue both existing as the code expects.
    */
    func testDistanceCaptureTapStartsTheHoldInsteadOfSeguingImmediately() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let storyboard = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Distance Measure Test/Base.lproj/Main.storyboard"
            ),
            encoding: .utf8
        )
        let controller = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Distance Measure Test/Features/TestSetup/DistanceOptimization.swift"
            ),
            encoding: .utf8
        )

        // The capture button's connection is the action that begins the hold.
        XCTAssertTrue(
            storyboard.contains(
                #"<action selector="captureDistanceTapped:" destination="BV1-FR-VrT" eventType="touchUpInside""#
            )
        )
        XCTAssertTrue(controller.contains("@IBAction func captureDistanceTapped(_ sender: Any)"))

        // The transition itself hangs off the view controller and is performed
        // in code, only once the held reading has been captured — so acuity
        // selection is reachable from this scene by exactly one segue, the
        // identified one, and never by an unidentified button-triggered push.
        let acuitySegues = storyboard
            .components(separatedBy: "<segue ")
            .dropFirst()
            .filter { $0.hasPrefix(#"destination="yoH-g8-Akd""#) }
        XCTAssertEqual(acuitySegues.count, 1)
        XCTAssertTrue(
            storyboard.contains(
                #"<segue destination="yoH-g8-Akd" kind="show" identifier="ShowAcuitySelection""#
            )
        )
        XCTAssertTrue(controller.contains(#"acuitySelectionSegueIdentifier = "ShowAcuitySelection""#))
        XCTAssertTrue(controller.contains("performSegue(withIdentifier: Self.acuitySelectionSegueIdentifier"))
    }

    func testEveryCSVPathIncludesSizingVersionTwoProvenanceColumns() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let formatterPath = "Distance Measure Test/Core/TestProgressionDataCollector.swift"
        let formatterSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(formatterPath),
            encoding: .utf8
        )
        let progressionExportPaths = [
            "Distance Measure Test/Features/Results/ResultViewController.swift",
            "Distance Measure Test/Features/Results/TestHistoryViewController.swift"
        ]
        let requiredColumns = [
            "Sizing_Version",
            "Calibration_Source",
            "Points_Per_MM",
            "Screen_Signature",
            "Target_Height_MM",
            "Rendered_Height_Points"
        ]

        for column in requiredColumns {
            XCTAssertTrue(
                formatterSource.contains(column),
                "\(formatterPath) is missing \(column)"
            )
        }

        for path in progressionExportPaths {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(path),
                encoding: .utf8
            )
            XCTAssertTrue(source.contains("TestProgressionCSVFormatter.header"), path)
            XCTAssertTrue(source.contains("TestProgressionCSVFormatter.row"), path)
        }

        let dataCollectionPath =
            "Distance Measure Test/Features/Results/DataCollectionViewController.swift"
        let dataCollectionSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(dataCollectionPath),
            encoding: .utf8
        )
        for column in requiredColumns {
            XCTAssertTrue(
                dataCollectionSource.contains(column),
                "\(dataCollectionPath) is missing \(column)"
            )
        }
    }

    func testAudioInstructionsDefaultOffWithoutOverwritingSavedPreference() throws {
        let suiteName = "AudioInstructionPreferencesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AudioInstructionPreferences.registerDefaults(in: defaults)
        XCTAssertFalse(AudioInstructionPreferences.isEnabled(in: defaults))

        AudioInstructionPreferences.setEnabled(true, in: defaults)
        AudioInstructionPreferences.registerDefaults(in: defaults)
        XCTAssertTrue(AudioInstructionPreferences.isEnabled(in: defaults))

        AudioInstructionPreferences.setEnabled(false, in: defaults)
        AudioInstructionPreferences.registerDefaults(in: defaults)
        XCTAssertFalse(AudioInstructionPreferences.isEnabled(in: defaults))
    }

    func testTestTypeDefaultsToETDRSWithoutOverwritingSavedPreference() throws {
        let suiteName = "TestTypePreferencesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        TestTypePreferences.registerDefaults(in: defaults)
        XCTAssertTrue(TestTypePreferences.isEnabled(in: defaults))

        TestTypePreferences.setEnabled(false, in: defaults)
        TestTypePreferences.registerDefaults(in: defaults)
        XCTAssertFalse(TestTypePreferences.isEnabled(in: defaults))

        TestTypePreferences.setEnabled(true, in: defaults)
        TestTypePreferences.registerDefaults(in: defaults)
        XCTAssertTrue(TestTypePreferences.isEnabled(in: defaults))
    }

    func testOneEyeInstructionContentUsesShutForBothEyes() {
        let rightEyeTest = OneEyeInstructionContent.make(for: 2)
        XCTAssertEqual(rightEyeTest.title, "Right Eye Test")
        XCTAssertEqual(
            rightEyeTest.visibleInstruction,
            "Shut left eye. Tap \"Begin\" when ready to start the test."
        )
        XCTAssertEqual(
            rightEyeTest.spokenInstruction,
            "Shut your left eye, test with right eye."
        )

        let leftEyeTest = OneEyeInstructionContent.make(for: 1)
        XCTAssertEqual(leftEyeTest.title, "Left Eye Test")
        XCTAssertEqual(
            leftEyeTest.visibleInstruction,
            "Shut right eye. Tap \"Begin\" when ready to start the test."
        )
        XCTAssertEqual(
            leftEyeTest.spokenInstruction,
            "Shut your right eye, test with left eye."
        )

        XCTAssertFalse(rightEyeTest.visibleInstruction.localizedCaseInsensitiveContains("cover"))
        XCTAssertFalse(rightEyeTest.spokenInstruction.localizedCaseInsensitiveContains("cover"))
        XCTAssertFalse(leftEyeTest.visibleInstruction.localizedCaseInsensitiveContains("cover"))
        XCTAssertFalse(leftEyeTest.spokenInstruction.localizedCaseInsensitiveContains("cover"))
    }

    // MARK: - ETDRS letter sequencing

    /// The letter pool the ETDRS test draws from, mirrored from
    /// ETDRSViewController.etdrsLetters so a silent edit there shows up here.
    private let etdrsPool = ["C", "D", "F", "H", "K", "N", "P", "R", "X", "J", "Z"]

    /* The no-repeat rule works by filtering the just-shown letter out of the
       pool, so it can only fail to return a letter if the pool holds nothing
       but that letter. Pinning the pool at two-or-more distinct entries is what
       makes that branch unreachable, and rules out a duplicated glyph slipping
       past the filter as two different array elements.
     */
    func testETDRSLetterPoolSupportsTheNoRepeatRule() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Distance Measure Test/Features/ETDRS/ETDRSViewController.swift"
            ),
            encoding: .utf8
        )

        let expectedDeclaration = "let etdrsLetters = ["
            + etdrsPool.map { "\"\($0)\"" }.joined(separator: ", ")
            + "]"

        XCTAssertTrue(
            source.contains(expectedDeclaration),
            "The controller's letter pool no longer matches the pool these tests exercise."
        )
        XCTAssertGreaterThanOrEqual(etdrsPool.count, 2)
        XCTAssertEqual(
            Set(etdrsPool).count,
            etdrsPool.count,
            "A duplicated pool entry would let the same glyph be drawn twice in a row."
        )
    }

    /* A subject who sees the same letter twice in a row can answer the second
       trial from memory rather than from vision, which inflates the score at
       the acuity level being measured. ETDRSViewController.generateNewLetter()
       is UIKit-bound and cannot be exercised directly, so this drives the pure
       selection it delegates to, chained exactly the way the controller chains
       it: the letter drawn for one trial becomes the exclusion for the next.
     */
    func testETDRSNeverPresentsTheSameLetterTwiceInARow() throws {
        // "" is what generateNewLetter() sees on the first trial in viewDidLoad.
        var previous = ""
        var drawn: [String] = []

        for _ in 0..<2_000 {
            previous = try XCTUnwrap(
                ETDRSViewController.nextLetter(in: etdrsPool, excluding: previous),
                "The 11-letter pool must always leave a candidate."
            )
            drawn.append(previous)
        }

        XCTAssertNil(
            zip(drawn, drawn.dropFirst()).first { $0 == $1 },
            "Two consecutive trials drew the same letter."
        )
        XCTAssertEqual(
            Set(drawn),
            Set(etdrsPool),
            "Every ETDRS letter must stay reachable; a missing one means the draw collapsed."
        )
    }

    /* The test above pins the selection rule; this pins the wiring. The rule
       only holds because generateNewLetter() passes the letter currently on
       screen as the exclusion — reverting to a bare randomElement(), or passing
       a constant instead of currentLetter, would restore the repeats while
       every other test still passed.
     */
    func testETDRSControllerRoutesLetterChoiceThroughTheNoRepeatHelper() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Distance Measure Test/Features/ETDRS/ETDRSViewController.swift"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(
            source.contains("Self.nextLetter(in: etdrsLetters, excluding: currentLetter)"),
            "generateNewLetter() must exclude the letter that is currently displayed."
        )
        XCTAssertTrue(
            source.contains("pool.filter { $0 != previous }.randomElement()"),
            "nextLetter(in:excluding:) must draw from the pool minus the previous letter."
        )
        XCTAssertFalse(
            source.contains("etdrsLetters.randomElement()"),
            "An unfiltered draw reintroduces back-to-back repeats."
        )
    }
}
