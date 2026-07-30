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
}
