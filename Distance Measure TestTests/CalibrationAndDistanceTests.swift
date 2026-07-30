import XCTest
import UIKit
@testable import Distance_Measure_Test

final class CalibrationAndDistanceTests: XCTestCase {
    func testAutomaticCalibrationConvertsPhysicalPixelsToPoints() throws {
        let calibration = try XCTUnwrap(ScreenCalibrationProvider.automaticCalibration(
            ppi: 460,
            nativeScale: 3,
            screenSignature: "iPhone"
        ))

        XCTAssertEqual(calibration.pointsPerMillimeter, 460 / 3 / 25.4, accuracy: 0.000_001)
        XCTAssertEqual(calibration.source, .deviceDatabase)
        XCTAssertTrue(calibration.isValidated)
        XCTAssertEqual(calibration.halfPhysicalPixelInPoints, 1.0 / 6.0, accuracy: 0.000_001)
    }

    func testManualCalibrationValidationRejectsChangedScreenSignature() {
        XCTAssertNotNil(ScreenCalibrationProvider.manualCalibration(
            pointsPerMillimeter: 6.1,
            nativeScale: 3,
            storedScreenSignature: "screen-a",
            storedSchemaVersion: ScreenCalibration.schemaVersion,
            currentScreenSignature: "screen-a",
            currentNativeScale: 3
        ))
        XCTAssertNil(ScreenCalibrationProvider.manualCalibration(
            pointsPerMillimeter: 6.1,
            nativeScale: 3,
            storedScreenSignature: "screen-a",
            storedSchemaVersion: ScreenCalibration.schemaVersion,
            currentScreenSignature: "screen-b",
            currentNativeScale: 3
        ))
        XCTAssertNil(ScreenCalibrationProvider.manualCalibration(
            pointsPerMillimeter: 6.1,
            nativeScale: 3,
            storedScreenSignature: "screen-a",
            storedSchemaVersion: ScreenCalibration.schemaVersion + 1,
            currentScreenSignature: "screen-a",
            currentNativeScale: 3
        ))
        XCTAssertNil(ScreenCalibrationProvider.manualCalibration(
            pointsPerMillimeter: 6.1,
            nativeScale: 3,
            storedScreenSignature: "screen-a",
            storedSchemaVersion: ScreenCalibration.schemaVersion,
            currentScreenSignature: "screen-a",
            currentNativeScale: 2
        ))
    }

    func testUnknownDeviceRequiresManualCalibrationAndInvalidatesItPermanently() throws {
        let suiteName = "ScreenCalibrationProviderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var descriptor = ScreenDescriptor(
            machineIdentifier: "iPhone-test",
            nativeBounds: CGRect(x: 0, y: 0, width: 1179, height: 2556),
            nativeScale: 3
        )
        let originalSignature = descriptor.signature
        let provider = ScreenCalibrationProvider(
            defaults: defaults,
            notificationCenter: NotificationCenter(),
            ppiResolution: { .unknown(suggestedPPI: 460) },
            screenDescriptor: { descriptor }
        )

        XCTAssertNil(provider.currentCalibration)
        XCTAssertEqual(provider.suggestedPointsPerMillimeter, 460 / 3 / 25.4, accuracy: 0.000_001)
        guard case .manualCalibrationRequired(let requiredSignature) = provider.status else {
            return XCTFail("An unknown device must require manual calibration")
        }
        XCTAssertEqual(requiredSignature, originalSignature)

        let saved = try XCTUnwrap(provider.saveManualCalibration(pointsPerMillimeter: 6.05))
        XCTAssertEqual(saved.source, .manual)
        XCTAssertEqual(provider.currentCalibration, saved)

        descriptor = ScreenDescriptor(
            machineIdentifier: "iPhone-test",
            nativeBounds: CGRect(x: 0, y: 0, width: 1284, height: 2778),
            nativeScale: 3
        )
        XCTAssertNil(provider.currentCalibration)

        descriptor = ScreenDescriptor(
            machineIdentifier: "iPhone-test",
            nativeBounds: CGRect(x: 0, y: 0, width: 1179, height: 2556),
            nativeScale: 3
        )
        XCTAssertNil(provider.currentCalibration, "An invalidated calibration must not resurface")
    }

    func testDistanceSampleRejectsStaleAndOutOfRangeValues() {
        let now = Date()
        XCTAssertTrue(EyeDistanceSample(
            distanceCM: 40,
            eyeNumber: 2,
            timestamp: now.addingTimeInterval(-0.1)
        ).isValid(at: now))
        XCTAssertFalse(EyeDistanceSample(
            distanceCM: 40,
            eyeNumber: 2,
            timestamp: now.addingTimeInterval(-0.6)
        ).isValid(at: now))
        XCTAssertFalse(EyeDistanceSample(
            distanceCM: 9.9,
            eyeNumber: 2,
            timestamp: now
        ).isValid(at: now))
        XCTAssertFalse(EyeDistanceSample(
            distanceCM: 100.1,
            eyeNumber: 2,
            timestamp: now
        ).isValid(at: now))
        XCTAssertFalse(EyeDistanceSample(
            distanceCM: .nan,
            eyeNumber: 2,
            timestamp: now
        ).isValid(at: now))
        XCTAssertFalse(EyeDistanceSample(
            distanceCM: 40,
            eyeNumber: 2,
            timestamp: now.addingTimeInterval(0.1)
        ).isValid(at: now))
    }

    func testDistanceProviderValidityCoversEveryRuntimeState() {
        let now = Date()
        let current = EyeDistanceSample(distanceCM: 40, eyeNumber: 2, timestamp: now)
        let stale = EyeDistanceSample(
            distanceCM: 40,
            eyeNumber: 2,
            timestamp: now.addingTimeInterval(-0.6)
        )
        let outOfRange = EyeDistanceSample(distanceCM: 100.1, eyeNumber: 2, timestamp: now)

        XCTAssertEqual(validity(state: .idle, sample: nil, now: now), .missing)
        XCTAssertEqual(validity(state: .unsupported, sample: nil, now: now), .unsupported)
        XCTAssertEqual(validity(state: .interrupted, sample: nil, now: now), .interrupted)
        XCTAssertEqual(validity(state: .failed, sample: nil, now: now), .failed)
        XCTAssertEqual(validity(state: .tracking, sample: nil, now: now), .missing)
        XCTAssertEqual(validity(state: .tracking, sample: current, now: now), .valid)
        XCTAssertEqual(validity(state: .tracking, sample: stale, now: now), .stale)
        XCTAssertEqual(validity(state: .tracking, sample: outOfRange, now: now), .outOfRange)
        XCTAssertEqual(
            validity(state: .tracking, sample: current, outOfRange: true, now: now),
            .outOfRange
        )
        XCTAssertEqual(
            EyeDistanceProvider.validity(
                state: .tracking,
                latestSample: current,
                lastMeasurementWasOutOfRange: false,
                eyeNumber: 1,
                now: now
            ),
            .missing
        )
    }

    func testCapturedHoldingDistanceUsesTheAcceptedLiveRange() {
        XCTAssertNil(DistanceTracker.validatedHoldingDistance(nil))
        XCTAssertNil(DistanceTracker.validatedHoldingDistance(.nan))
        XCTAssertNil(DistanceTracker.validatedHoldingDistance(9.9))
        XCTAssertNil(DistanceTracker.validatedHoldingDistance(100.1))
        XCTAssertEqual(DistanceTracker.validatedHoldingDistance(10), 10)
        XCTAssertEqual(DistanceTracker.validatedHoldingDistance(40), 40)
        XCTAssertEqual(DistanceTracker.validatedHoldingDistance(100), 100)
    }

    func testIncomingDistanceClientCannotBeStoppedByOutgoingScreen() {
        let outgoing = NSObject()
        let incoming = NSObject()
        var lease = EyeDistanceClientLease()

        lease.claim(outgoing)
        lease.claim(incoming)

        XCTAssertFalse(lease.release(outgoing))
        XCTAssertTrue(lease.hasActiveClient)
        XCTAssertTrue(lease.release(incoming))
        XCTAssertFalse(lease.hasActiveClient)
    }

    private func validity(
        state: EyeDistanceState,
        sample: EyeDistanceSample?,
        outOfRange: Bool = false,
        now: Date
    ) -> EyeDistanceValidity {
        EyeDistanceProvider.validity(
            state: state,
            latestSample: sample,
            lastMeasurementWasOutOfRange: outOfRange,
            eyeNumber: 2,
            now: now
        )
    }
}
