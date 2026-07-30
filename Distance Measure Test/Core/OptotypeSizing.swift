import UIKit

public enum CalibrationSource: String, Codable {
    case deviceDatabase
    case manual
    case legacyUnknown
}

enum SizingMetadataFormat {
    private static let locale = Locale(identifier: "en_US_POSIX")

    static func decimal(_ value: Double, places: Int) -> String {
        String(format: "%.*f", locale: locale, places, value)
    }
}

struct ScreenCalibration: Codable, Equatable {
    static let schemaVersion = 1

    let pointsPerMillimeter: Double
    let nativeScale: Double
    let source: CalibrationSource
    let screenSignature: String
    let schemaVersion: Int

    var isValidated: Bool {
        pointsPerMillimeter.isFinite
            && pointsPerMillimeter > 0
            && nativeScale.isFinite
            && nativeScale > 0
            && source != .legacyUnknown
            && schemaVersion == Self.schemaVersion
    }

    var halfPhysicalPixelInPoints: CGFloat {
        CGFloat(0.5 / nativeScale)
    }
}

public struct SizingProvenance: Codable, Equatable {
    static let currentVersion = 2

    let sizingVersion: Int
    let calibrationSource: CalibrationSource
    let pointsPerMillimeter: Double
    let screenSignature: String
    let targetHeightMillimeters: Double
    let renderedHeightPoints: Double

    func matches(_ calibration: ScreenCalibration) -> Bool {
        sizingVersion == Self.currentVersion
            && calibrationSource == calibration.source
            && pointsPerMillimeter == calibration.pointsPerMillimeter
            && screenSignature == calibration.screenSignature
            && calibration.isValidated
    }
}

struct OptotypeRenderSpec: Equatable {
    let targetAngleArcMinutes: Double
    let targetAngleRadians: Double
    let targetHeightMillimeters: Double
    let renderedHeightPoints: CGFloat
    let fontPointSize: CGFloat
    let calibration: ScreenCalibration

    var provenance: SizingProvenance {
        SizingProvenance(
            sizingVersion: SizingProvenance.currentVersion,
            calibrationSource: calibration.source,
            pointsPerMillimeter: calibration.pointsPerMillimeter,
            screenSignature: calibration.screenSignature,
            targetHeightMillimeters: targetHeightMillimeters,
            renderedHeightPoints: Double(renderedHeightPoints)
        )
    }
}

struct OptotypeRenderUpdate: Equatable {
    /// The spec that is actually visible after this update. When a sub-pixel
    /// change is skipped, this remains the previous rendered spec.
    let spec: OptotypeRenderSpec
    let candidateSpec: OptotypeRenderSpec
    let didRender: Bool
}

enum OptotypeSizingError: LocalizedError, Equatable {
    case invalidDistance
    case invalidAcuity
    case invalidCalibration
    case invalidFontMetrics
    case sloanFontUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidDistance:
            return "A current positive viewing distance is required."
        case .invalidAcuity:
            return "A positive Snellen denominator is required."
        case .invalidCalibration:
            return "A validated screen calibration is required."
        case .invalidFontMetrics:
            return "The optotype font does not expose valid cap-height metrics."
        case .sloanFontUnavailable:
            return "The Sloan optotype font is unavailable."
        }
    }
}

enum OptotypeSizing {
    static let snellenNumerator = 20.0
    static let arcMinutesPerTwentyTwentyLetter = 5.0

    static func renderSpec(
        distanceCM: Double,
        snellenDenominator: Int,
        calibration: ScreenCalibration,
        font: UIFont
    ) throws -> OptotypeRenderSpec {
        guard distanceCM.isFinite, distanceCM > 0 else {
            throw OptotypeSizingError.invalidDistance
        }
        guard snellenDenominator > 0 else { throw OptotypeSizingError.invalidAcuity }
        guard calibration.isValidated else { throw OptotypeSizingError.invalidCalibration }
        guard font.pointSize.isFinite,
              font.pointSize > 0,
              font.capHeight.isFinite,
              font.capHeight > 0 else {
            throw OptotypeSizingError.invalidFontMetrics
        }

        let angleArcMinutes = (Double(snellenDenominator) / snellenNumerator)
            * arcMinutesPerTwentyTwentyLetter
        let angleRadians = angleArcMinutes / 60.0 * .pi / 180.0
        let distanceMillimeters = distanceCM * 10.0
        let targetHeightMillimeters = 2.0 * distanceMillimeters * tan(angleRadians / 2.0)
        let renderedHeightPoints = CGFloat(
            targetHeightMillimeters * calibration.pointsPerMillimeter
        )
        let capHeightRatio = font.capHeight / font.pointSize
        let fontPointSize = renderedHeightPoints / capHeightRatio

        return OptotypeRenderSpec(
            targetAngleArcMinutes: angleArcMinutes,
            targetAngleRadians: angleRadians,
            targetHeightMillimeters: targetHeightMillimeters,
            renderedHeightPoints: renderedHeightPoints,
            fontPointSize: fontPointSize,
            calibration: calibration
        )
    }
}

enum OptotypeRenderer {
    private static func sloanFont() throws -> UIFont {
        guard let font = UIFont(name: "Sloan", size: 100) else {
            throw OptotypeSizingError.sloanFontUnavailable
        }
        return font
    }

    static func needsRender(
        previousSpec: OptotypeRenderSpec?,
        candidateSpec: OptotypeRenderSpec,
        force: Bool = false
    ) -> Bool {
        guard !force, let previousSpec else { return true }
        guard previousSpec.calibration == candidateSpec.calibration else { return true }
        return abs(candidateSpec.renderedHeightPoints - previousSpec.renderedHeightPoints)
            >= candidateSpec.calibration.halfPhysicalPixelInPoints
    }

    @discardableResult
    static func update(
        label: UILabel,
        text: String,
        distanceCM: Double,
        snellenDenominator: Int,
        calibration: ScreenCalibration,
        previousSpec: OptotypeRenderSpec?,
        force: Bool = false
    ) throws -> OptotypeRenderUpdate {
        let baseFont = try sloanFont()
        let candidateSpec = try OptotypeSizing.renderSpec(
            distanceCM: distanceCM,
            snellenDenominator: snellenDenominator,
            calibration: calibration,
            font: baseFont
        )
        let shouldRender = needsRender(
            previousSpec: previousSpec,
            candidateSpec: candidateSpec,
            force: force
        )

        let textChanged = label.text != text
        label.text = text
        if shouldRender {
            label.transform = .identity
            label.font = baseFont.withSize(candidateSpec.fontPointSize)
        }
        if textChanged || shouldRender {
            label.invalidateIntrinsicContentSize()
        }

        return OptotypeRenderUpdate(
            spec: shouldRender ? candidateSpec : previousSpec ?? candidateSpec,
            candidateSpec: candidateSpec,
            didRender: shouldRender
        )
    }

    @discardableResult
    static func update(
        button: UIButton,
        text: String,
        distanceCM: Double,
        snellenDenominator: Int,
        calibration: ScreenCalibration,
        previousSpec: OptotypeRenderSpec?,
        force: Bool = false
    ) throws -> OptotypeRenderUpdate {
        let baseFont = try sloanFont()
        let candidateSpec = try OptotypeSizing.renderSpec(
            distanceCM: distanceCM,
            snellenDenominator: snellenDenominator,
            calibration: calibration,
            font: baseFont
        )
        let shouldRender = needsRender(
            previousSpec: previousSpec,
            candidateSpec: candidateSpec,
            force: force
        )

        let textChanged = button.title(for: .normal) != text
        button.setTitle(text, for: .normal)
        if shouldRender {
            button.titleLabel?.transform = .identity
            button.titleLabel?.font = baseFont.withSize(candidateSpec.fontPointSize)
        }
        if textChanged || shouldRender {
            button.titleLabel?.invalidateIntrinsicContentSize()
        }

        return OptotypeRenderUpdate(
            spec: shouldRender ? candidateSpec : previousSpec ?? candidateSpec,
            candidateSpec: candidateSpec,
            didRender: shouldRender
        )
    }

    @discardableResult
    static func apply(
        to label: UILabel,
        text: String,
        distanceCM: Double,
        snellenDenominator: Int,
        calibration: ScreenCalibration
    ) throws -> OptotypeRenderSpec {
        try update(
            label: label,
            text: text,
            distanceCM: distanceCM,
            snellenDenominator: snellenDenominator,
            calibration: calibration,
            previousSpec: nil,
            force: true
        ).spec
    }

    @discardableResult
    static func apply(
        to button: UIButton,
        text: String,
        distanceCM: Double,
        snellenDenominator: Int,
        calibration: ScreenCalibration
    ) throws -> OptotypeRenderSpec {
        try update(
            button: button,
            text: text,
            distanceCM: distanceCM,
            snellenDenominator: snellenDenominator,
            calibration: calibration,
            previousSpec: nil,
            force: true
        ).spec
    }
}
