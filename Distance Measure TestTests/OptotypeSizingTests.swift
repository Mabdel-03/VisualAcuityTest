import XCTest
import UIKit
@testable import Distance_Measure_Test

@MainActor
final class OptotypeSizingTests: XCTestCase {
    private let acuities = [16, 20, 32, 40, 50, 63, 80, 100, 125, 160, 200]

    func testAllSupportedAcuitiesAcrossAcceptedDistances() throws {
        let calibration = makeCalibration(pointsPerMillimeter: 6.1, nativeScale: 3)
        let font = UIFont.systemFont(ofSize: 100)

        for distance in stride(from: 10.0, through: 100.0, by: 1.0) {
            var previousHeight = 0.0
            for acuity in acuities {
                let spec = try OptotypeSizing.renderSpec(
                    distanceCM: distance,
                    snellenDenominator: acuity,
                    calibration: calibration,
                    font: font
                )
                XCTAssertGreaterThan(spec.targetHeightMillimeters, previousHeight)
                XCTAssertTrue(spec.fontPointSize.isFinite)
                let expectedArcMinutes = 5.0 * Double(acuity) / 20.0
                let expectedRadians = expectedArcMinutes / 60.0 * .pi / 180.0
                let expectedMillimeters = 2.0 * distance * 10.0 * tan(expectedRadians / 2.0)
                XCTAssertEqual(spec.targetAngleArcMinutes, expectedArcMinutes, accuracy: 0.000_001)
                XCTAssertEqual(spec.targetAngleRadians, expectedRadians, accuracy: 0.000_000_001)
                XCTAssertEqual(spec.targetHeightMillimeters, expectedMillimeters, accuracy: 0.000_001)
                XCTAssertEqual(
                    Double(spec.renderedHeightPoints) / calibration.pointsPerMillimeter,
                    spec.targetHeightMillimeters,
                    accuracy: 0.000_001
                )
                previousHeight = spec.targetHeightMillimeters
            }
        }
    }

    func testFortyCentimetersTwentyTwoHundredIs5818Millimeters() throws {
        let spec = try OptotypeSizing.renderSpec(
            distanceCM: 40,
            snellenDenominator: 200,
            calibration: makeCalibration(pointsPerMillimeter: 6, nativeScale: 3),
            font: UIFont.systemFont(ofSize: 100)
        )

        XCTAssertEqual(spec.targetAngleArcMinutes, 50, accuracy: 0.000_001)
        XCTAssertEqual(spec.targetHeightMillimeters, 5.818, accuracy: 0.001)
    }

    func testPhysicalHeightIsIndependentOfDisplayScale() throws {
        let displays = [
            (ppi: 326.0, scale: 2.0),
            (ppi: 460.0, scale: 3.0),
            (ppi: 401.0, scale: 2.6087)
        ]
        let font = UIFont.systemFont(ofSize: 100)
        for distance in stride(from: 10.0, through: 100.0, by: 10.0) {
            for acuity in acuities {
                var physicalHeights: [Double] = []
                for display in displays {
                    let calibration = try XCTUnwrap(ScreenCalibrationProvider.automaticCalibration(
                        ppi: display.ppi,
                        nativeScale: display.scale,
                        screenSignature: "mock-\(display.scale)"
                    ))
                    let spec = try OptotypeSizing.renderSpec(
                        distanceCM: distance,
                        snellenDenominator: acuity,
                        calibration: calibration,
                        font: font
                    )
                    physicalHeights.append(
                        Double(spec.renderedHeightPoints) / calibration.pointsPerMillimeter
                    )
                }
                for height in physicalHeights {
                    XCTAssertEqual(height, physicalHeights[0], accuracy: 0.000_001)
                }
            }
        }
    }

    func testSloanFontPointSizeProducesRequestedCapHeight() throws {
        let sloan = try XCTUnwrap(UIFont(name: "Sloan", size: 100))
        let calibration = makeCalibration(pointsPerMillimeter: 6.05, nativeScale: 3)
        let spec = try OptotypeSizing.renderSpec(
            distanceCM: 40,
            snellenDenominator: 200,
            calibration: calibration,
            font: sloan
        )
        let resized = sloan.withSize(spec.fontPointSize)

        XCTAssertEqual(resized.capHeight, spec.renderedHeightPoints, accuracy: 0.001)
    }

    func testRendererAppliesAbsoluteSloanCapHeightToLabelsAndButtons() throws {
        let calibration = makeCalibration(pointsPerMillimeter: 6.05, nativeScale: 3)
        let label = UILabel()
        label.transform = CGAffineTransform(scaleX: 2, y: 2)
        let labelSpec = try OptotypeRenderer.apply(
            to: label,
            text: "C",
            distanceCM: 40,
            snellenDenominator: 200,
            calibration: calibration
        )

        XCTAssertEqual(label.text, "C")
        XCTAssertEqual(label.transform, .identity)
        XCTAssertEqual(label.font.capHeight, labelSpec.renderedHeightPoints, accuracy: 0.001)

        let button = UIButton(type: .system)
        button.titleLabel?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        let buttonSpec = try OptotypeRenderer.apply(
            to: button,
            text: "C",
            distanceCM: 40,
            snellenDenominator: 20,
            calibration: calibration
        )
        let titleLabel = try XCTUnwrap(button.titleLabel)

        XCTAssertEqual(button.title(for: .normal), "C")
        XCTAssertEqual(titleLabel.transform, .identity)
        XCTAssertEqual(titleLabel.font.capHeight, buttonSpec.renderedHeightPoints, accuracy: 0.001)
    }

    func testRendererUsesHalfPhysicalPixelThresholdAndCalibrationIdentity() throws {
        let calibration = makeCalibration(pointsPerMillimeter: 6.0, nativeScale: 3)
        let baseFont = try XCTUnwrap(UIFont(name: "Sloan", size: 100))
        let previous = try OptotypeSizing.renderSpec(
            distanceCM: 40,
            snellenDenominator: 200,
            calibration: calibration,
            font: baseFont
        )
        let renderedPointsPerCentimeter = previous.renderedHeightPoints / 40
        let belowThresholdDistance = 40
            + 0.99 * calibration.halfPhysicalPixelInPoints / renderedPointsPerCentimeter
        let thresholdDistance = 40
            + calibration.halfPhysicalPixelInPoints / renderedPointsPerCentimeter
        let belowThreshold = try OptotypeSizing.renderSpec(
            distanceCM: Double(belowThresholdDistance),
            snellenDenominator: 200,
            calibration: calibration,
            font: baseFont
        )
        let atThreshold = try OptotypeSizing.renderSpec(
            distanceCM: Double(thresholdDistance),
            snellenDenominator: 200,
            calibration: calibration,
            font: baseFont
        )

        XCTAssertFalse(OptotypeRenderer.needsRender(
            previousSpec: previous,
            candidateSpec: belowThreshold
        ))
        XCTAssertTrue(OptotypeRenderer.needsRender(
            previousSpec: previous,
            candidateSpec: atThreshold
        ))

        let changedScreen = ScreenCalibration(
            pointsPerMillimeter: calibration.pointsPerMillimeter,
            nativeScale: calibration.nativeScale,
            source: .manual,
            screenSignature: "different-screen",
            schemaVersion: ScreenCalibration.schemaVersion
        )
        let changedScreenSpec = try OptotypeSizing.renderSpec(
            distanceCM: 40,
            snellenDenominator: 200,
            calibration: changedScreen,
            font: baseFont
        )
        XCTAssertTrue(OptotypeRenderer.needsRender(
            previousSpec: previous,
            candidateSpec: changedScreenSpec
        ))
    }

    func testSkippedSubpixelUpdatePreservesActualRenderedSpec() throws {
        let calibration = makeCalibration(pointsPerMillimeter: 6.0, nativeScale: 3)
        let label = UILabel()
        let first = try OptotypeRenderer.update(
            label: label,
            text: "C",
            distanceCM: 40,
            snellenDenominator: 200,
            calibration: calibration,
            previousSpec: nil
        )
        let renderedPointsPerCentimeter = first.spec.renderedHeightPoints / 40
        let distance = 40
            + 0.25 * calibration.halfPhysicalPixelInPoints / renderedPointsPerCentimeter
        let originalPointSize = label.font.pointSize
        let second = try OptotypeRenderer.update(
            label: label,
            text: "D",
            distanceCM: Double(distance),
            snellenDenominator: 200,
            calibration: calibration,
            previousSpec: first.spec
        )

        XCTAssertFalse(second.didRender)
        XCTAssertEqual(second.spec, first.spec)
        XCTAssertNotEqual(second.candidateSpec, first.spec)
        XCTAssertEqual(label.font.pointSize, originalPointSize, accuracy: 0.000_001)
        XCTAssertEqual(label.text, "D")
    }

    func testFiftyMillimeterCalibrationRulerFitsA320PointWideScreen() throws {
        let suiteName = "ScreenCalibrationLayoutTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let provider = ScreenCalibrationProvider(
            defaults: defaults,
            notificationCenter: NotificationCenter(),
            ppiResolution: { .unknown(suggestedPPI: 326) },
            screenDescriptor: {
                ScreenDescriptor(
                    machineIdentifier: "narrow-phone",
                    nativeBounds: CGRect(x: 0, y: 0, width: 640, height: 1136),
                    nativeScale: 2
                )
            }
        )
        let controller = ScreenCalibrationViewController(calibrationProvider: provider)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let expectedHeight = CGFloat(326 / 2 / 25.4 * 50)
        XCTAssertEqual(controller.rulerHeightPoints, expectedHeight, accuracy: 0.001)
        XCTAssertLessThan(controller.rulerHeightPoints, controller.view.bounds.height)
        assertUnambiguousLayout(in: controller.view)
    }

    func testInvalidInputsAreRejected() {
        let valid = makeCalibration(pointsPerMillimeter: 6, nativeScale: 3)
        let unknown = ScreenCalibration(
            pointsPerMillimeter: 6,
            nativeScale: 3,
            source: .legacyUnknown,
            screenSignature: "unknown",
            schemaVersion: ScreenCalibration.schemaVersion
        )
        let font = UIFont.systemFont(ofSize: 100)
        let staleSchema = ScreenCalibration(
            pointsPerMillimeter: 6,
            nativeScale: 3,
            source: .manual,
            screenSignature: "stale",
            schemaVersion: ScreenCalibration.schemaVersion + 1
        )

        XCTAssertThrowsError(try OptotypeSizing.renderSpec(
            distanceCM: 0,
            snellenDenominator: 20,
            calibration: valid,
            font: font
        ))
        XCTAssertThrowsError(try OptotypeSizing.renderSpec(
            distanceCM: 40,
            snellenDenominator: 0,
            calibration: valid,
            font: font
        ))
        XCTAssertThrowsError(try OptotypeSizing.renderSpec(
            distanceCM: 40,
            snellenDenominator: 20,
            calibration: unknown,
            font: font
        ))
        XCTAssertThrowsError(try OptotypeSizing.renderSpec(
            distanceCM: 40,
            snellenDenominator: 20,
            calibration: valid,
            font: UIFont.systemFont(ofSize: 0)
        ))
        XCTAssertThrowsError(try OptotypeSizing.renderSpec(
            distanceCM: .infinity,
            snellenDenominator: 20,
            calibration: valid,
            font: font
        ))
        XCTAssertThrowsError(try OptotypeSizing.renderSpec(
            distanceCM: 40,
            snellenDenominator: 20,
            calibration: staleSchema,
            font: font
        ))
    }

    private func makeCalibration(
        pointsPerMillimeter: Double,
        nativeScale: Double
    ) -> ScreenCalibration {
        ScreenCalibration(
            pointsPerMillimeter: pointsPerMillimeter,
            nativeScale: nativeScale,
            source: .manual,
            screenSignature: "test-screen",
            schemaVersion: ScreenCalibration.schemaVersion
        )
    }

    private func assertUnambiguousLayout(
        in view: UIView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(view.hasAmbiguousLayout, String(describing: type(of: view)), file: file, line: line)
        view.subviews.forEach { assertUnambiguousLayout(in: $0, file: file, line: line) }
    }
}
