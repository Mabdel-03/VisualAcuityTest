import UIKit
import ARKit
import SceneKit
import DevicePpi

// MARK: - Core Models

enum TestedEye: String, Codable, CaseIterable {
    case right = "Right"
    case left = "Left"

    var next: TestedEye? {
        switch self {
        case .right:
            return .left
        case .left:
            return nil
        }
    }

    var coveredEyeInstruction: String {
        switch self {
        case .right:
            return "Cover your left eye. Test with your right eye."
        case .left:
            return "Cover your right eye. Test with your left eye."
        }
    }
}

enum LandoltOrientation: String, Codable, CaseIterable {
    case right = "Right"
    case down = "Down"
    case left = "Left"
    case up = "Up"

    var angleRadians: CGFloat {
        switch self {
        case .right:
            return 0
        case .down:
            return .pi / 2
        case .left:
            return .pi
        case .up:
            return -.pi / 2
        }
    }
}

enum StaircaseDirection: String, Codable {
    case up = "Up"
    case down = "Down"
}

struct DeviceMetadata: Codable {
    let deviceModel: String
    let systemName: String
    let systemVersion: String
    let appVersion: String
    let buildNumber: String
    let ppi: Double
    let nativeScale: Double
    let screenWidthPoints: Double
    let screenHeightPoints: Double

    static func current(ppi: Double = DeviceDisplay.currentPPI(),
                        nativeScale: Double = Double(UIScreen.main.nativeScale)) -> DeviceMetadata {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let bounds = UIScreen.main.bounds
        return DeviceMetadata(
            deviceModel: DeviceDisplay.modelIdentifier(),
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: version,
            buildNumber: build,
            ppi: ppi,
            nativeScale: nativeScale,
            screenWidthPoints: Double(bounds.width),
            screenHeightPoints: Double(bounds.height)
        )
    }
}

struct DistanceCalibration: Codable {
    let eye: TestedEye
    let capturedAt: Date
    let targetDistanceCM: Double
    let lowerBoundCM: Double
    let upperBoundCM: Double
    let sampleCount: Int
    let sampleStandardDeviationCM: Double
    let captureMethod: String

    init(
        eye: TestedEye,
        capturedAt: Date = Date(),
        targetDistanceCM: Double,
        tolerance: Double = 0.10,
        sampleCount: Int,
        sampleStandardDeviationCM: Double,
        captureMethod: String
    ) {
        self.eye = eye
        self.capturedAt = capturedAt
        self.targetDistanceCM = targetDistanceCM
        self.lowerBoundCM = targetDistanceCM * (1 - tolerance)
        self.upperBoundCM = targetDistanceCM * (1 + tolerance)
        self.sampleCount = sampleCount
        self.sampleStandardDeviationCM = sampleStandardDeviationCM
        self.captureMethod = captureMethod
    }
}

struct TrialRecord: Codable {
    let sessionId: String
    let eye: TestedEye
    let trialIndex: Int
    let timestamp: Date
    let staircaseStepIndex: Int
    let logMAR: Double
    let snellenDenominator: Int
    let targetDistanceCM: Double
    let liveDistanceCM: Double
    let optotypeDiameterCM: Double
    let optotypeDiameterPoints: Double
    let devicePPI: Double
    let nativeScale: Double
    let orientationDisplayed: LandoltOrientation
    let userResponse: LandoltOrientation
    let isCorrect: Bool
    let responseTimeMS: Int
    let wasPausedDuringTrial: Bool
    let pauseEventCountAtResponse: Int
    let trackingStateDescription: String
    let wasDistanceSampleStable: Bool
    let causedReversal: Bool
    let staircaseDirectionAfterResponse: StaircaseDirection?
}

struct EyeRun: Codable {
    let eye: TestedEye
    var calibration: DistanceCalibration?
    var startingLogMAR: Double?
    var trials: [TrialRecord] = []
    var reversalLogMARs: [Double] = []
    var finalLogMAR: Double?
    var finalSnellenDenominator: Int?

    var isComplete: Bool {
        finalLogMAR != nil
    }
}

struct TestSession: Codable {
    let id: String
    let startedAt: Date
    var completedAt: Date?
    let deviceMetadata: DeviceMetadata
    var rightEye: EyeRun
    var leftEye: EyeRun

    init(deviceMetadata: DeviceMetadata = .current()) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let stamp = formatter.string(from: Date())
        self.id = "LandoltC_\(stamp)_\(UUID().uuidString.prefix(8))"
        self.startedAt = Date()
        self.deviceMetadata = deviceMetadata
        self.rightEye = EyeRun(eye: .right)
        self.leftEye = EyeRun(eye: .left)
    }

    func run(for eye: TestedEye) -> EyeRun {
        switch eye {
        case .right:
            return rightEye
        case .left:
            return leftEye
        }
    }

    mutating func setRun(_ run: EyeRun) {
        switch run.eye {
        case .right:
            rightEye = run
        case .left:
            leftEye = run
        }
    }
}

// MARK: - Device and Sizing

enum DeviceDisplay {
    static func currentPPI() -> Double {
        switch Ppi.get() {
        case .success(let ppi):
            return ppi
        case .unknown(let bestGuessPpi, _):
            return bestGuessPpi
        }
    }

    static func modelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier.append(String(UnicodeScalar(UInt8(value))))
        }
    }
}

struct OptotypeMetrics: Codable {
    let logMAR: Double
    let snellenDenominator: Int
    let viewingDistanceCM: Double
    let outerDiameterCM: Double
    let outerDiameterPoints: Double
    let strokeWidthPoints: Double
    let gapWidthPoints: Double
}

enum OptotypeSizer {
    static func snellenDenominator(forLogMAR logMAR: Double) -> Int {
        let raw = 20.0 * pow(10.0, logMAR)
        let standardValues = [16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200]
        return standardValues.min(by: { abs(Double($0) - raw) < abs(Double($1) - raw) }) ?? Int(raw.rounded())
    }

    static func logMAR(forSnellenDenominator denominator: Int) -> Double {
        log10(Double(denominator) / 20.0)
    }

    static func metrics(
        logMAR: Double,
        viewingDistanceCM: Double,
        ppi: Double = DeviceDisplay.currentPPI(),
        nativeScale: Double = Double(UIScreen.main.nativeScale)
    ) -> OptotypeMetrics {
        let denominator = snellenDenominator(forLogMAR: logMAR)
        return metrics(snellenDenominator: denominator, viewingDistanceCM: viewingDistanceCM, ppi: ppi, nativeScale: nativeScale)
    }

    static func metrics(
        snellenDenominator: Int,
        viewingDistanceCM: Double,
        ppi: Double = DeviceDisplay.currentPPI(),
        nativeScale: Double = Double(UIScreen.main.nativeScale)
    ) -> OptotypeMetrics {
        let safeDistance = max(10.0, viewingDistanceCM)
        let logMAR = logMAR(forSnellenDenominator: snellenDenominator)
        let visualAngleArcMinutes = (Double(snellenDenominator) / 20.0) * 5.0
        let visualAngleRadians = (visualAngleArcMinutes / 60.0) * .pi / 180.0
        let diameterCM = safeDistance * tan(visualAngleRadians)
        let pixels = diameterCM / 2.54 * ppi
        let points = pixels / max(nativeScale, 1.0)
        return OptotypeMetrics(
            logMAR: logMAR,
            snellenDenominator: snellenDenominator,
            viewingDistanceCM: safeDistance,
            outerDiameterCM: diameterCM,
            outerDiameterPoints: points,
            strokeWidthPoints: points / 5.0,
            gapWidthPoints: points / 5.0
        )
    }
}

final class LandoltCView: UIView {
    var orientation: LandoltOrientation = .right {
        didSet { setNeedsDisplay() }
    }

    var metrics: OptotypeMetrics? {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    var optotypeColor: UIColor = .black {
        didSet { setNeedsDisplay() }
    }

    var gapColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    override var intrinsicContentSize: CGSize {
        guard let points = metrics?.outerDiameterPoints else {
            return CGSize(width: 80, height: 80)
        }
        return CGSize(width: points, height: points)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let side = min(rect.width, rect.height)
        guard side > 0 else { return }

        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        let outerRect = CGRect(origin: origin, size: CGSize(width: side, height: side))
        let stroke = side / 5.0
        let innerRect = outerRect.insetBy(dx: stroke, dy: stroke)

        context.setFillColor(optotypeColor.cgColor)
        context.fillEllipse(in: outerRect)
        context.setFillColor(gapColor.cgColor)
        context.fillEllipse(in: innerRect)

        let gapRect = LandoltCView.gapRect(for: orientation, outerRect: outerRect, stroke: stroke)
        context.fill(gapRect)
    }

    static func gapRect(for orientation: LandoltOrientation, outerRect: CGRect, stroke: CGFloat) -> CGRect {
        let center = CGPoint(x: outerRect.midX, y: outerRect.midY)
        switch orientation {
        case .right:
            return CGRect(x: center.x, y: center.y - stroke / 2, width: outerRect.width / 2 + 1, height: stroke)
        case .left:
            return CGRect(x: outerRect.minX - 1, y: center.y - stroke / 2, width: outerRect.width / 2 + 1, height: stroke)
        case .up:
            return CGRect(x: center.x - stroke / 2, y: outerRect.minY - 1, width: stroke, height: outerRect.height / 2 + 1)
        case .down:
            return CGRect(x: center.x - stroke / 2, y: center.y, width: stroke, height: outerRect.height / 2 + 1)
        }
    }
}

// MARK: - Distance Service

struct DistanceSample {
    let distanceCM: Double
    let timestamp: Date
    let sampleCount: Int
    let standardDeviationCM: Double
    let trackingStateDescription: String
    let isStable: Bool
}

enum DistanceBandStatus: Equatable {
    case below
    case inBand
    case above

    var displayText: String {
        switch self {
        case .below:
            return "Too close. Move farther."
        case .inBand:
            return "Distance in range"
        case .above:
            return "Too far. Move closer."
        }
    }
}

final class DistanceMeasurementService: NSObject, ARSCNViewDelegate {
    var onSample: ((DistanceSample) -> Void)?

    private var sceneView: ARSCNView?
    private var leftEye = SCNNode()
    private var rightEye = SCNNode()
    private var recentReadings: [Double] = []
    private var trackedEye: TestedEye = .right
    private let maximumReadings = 18
    private let stableStandardDeviationThresholdCM = 1.5
    private let validRange: ClosedRange<Double> = 10.0...100.0
    private var lastCallbackTime: CFTimeInterval = 0
    private(set) var latestSample: DistanceSample?

    var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    func start(for eye: TestedEye, attachingTo parentView: UIView) {
        stop()
        trackedEye = eye
        reset()

        guard isSupported else {
            let sample = DistanceSample(
                distanceCM: 0,
                timestamp: Date(),
                sampleCount: 0,
                standardDeviationCM: 0,
                trackingStateDescription: "AR face tracking is not supported on this device.",
                isStable: false
            )
            latestSample = sample
            onSample?(sample)
            return
        }

        let arView = ARSCNView(frame: parentView.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.isHidden = true
        arView.delegate = self
        parentView.addSubview(arView)

        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        configuration.isLightEstimationEnabled = true
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        sceneView = arView
    }

    func stop() {
        sceneView?.session.pause()
        sceneView?.delegate = nil
        sceneView?.removeFromSuperview()
        sceneView = nil
    }

    func reset() {
        recentReadings.removeAll()
        latestSample = nil
        lastCallbackTime = 0
    }

    func calibration(for eye: TestedEye) -> DistanceCalibration? {
        guard let sample = latestSample, sample.isStable, validRange.contains(sample.distanceCM) else {
            return nil
        }
        return DistanceCalibration(
            eye: eye,
            targetDistanceCM: sample.distanceCM,
            sampleCount: sample.sampleCount,
            sampleStandardDeviationCM: sample.standardDeviationCM,
            captureMethod: "ARFaceTracking"
        )
    }

    func manualCalibration(for eye: TestedEye, distanceCM: Double) -> DistanceCalibration {
        DistanceCalibration(
            eye: eye,
            targetDistanceCM: distanceCM,
            sampleCount: 1,
            sampleStandardDeviationCM: 0,
            captureMethod: "ManualEntry"
        )
    }

    static func bandStatus(distanceCM: Double, calibration: DistanceCalibration) -> DistanceBandStatus {
        if distanceCM < calibration.lowerBoundCM {
            return .below
        }
        if distanceCM > calibration.upperBoundCM {
            return .above
        }
        return .inBand
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARFaceAnchor else { return }
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let frame = sceneView?.session.currentFrame else {
            return
        }

        let now = CACurrentMediaTime()
        guard now - lastCallbackTime >= 0.1 else { return }
        lastCallbackTime = now

        leftEye.simdTransform = faceAnchor.leftEyeTransform
        rightEye.simdTransform = faceAnchor.rightEyeTransform

        let cameraTransform = frame.camera.transform
        let cameraPosition = SCNVector3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let eyePosition = trackedEye == .right ? rightEye.worldPosition : leftEye.worldPosition
        let rawDistanceCM = Double(distance(from: eyePosition, to: cameraPosition)) * 100.0

        guard validRange.contains(rawDistanceCM) else { return }

        recentReadings.append(rawDistanceCM)
        if recentReadings.count > maximumReadings {
            recentReadings.removeFirst()
        }

        let mean = recentReadings.reduce(0, +) / Double(recentReadings.count)
        let variance = recentReadings.reduce(0) { sum, value in
            let delta = value - mean
            return sum + delta * delta
        } / Double(recentReadings.count)
        let stdDev = sqrt(variance)
        let trackingDescription = frame.camera.trackingState.descriptionText
        let sample = DistanceSample(
            distanceCM: mean,
            timestamp: Date(),
            sampleCount: recentReadings.count,
            standardDeviationCM: stdDev,
            trackingStateDescription: trackingDescription,
            isStable: recentReadings.count >= 10 && stdDev <= stableStandardDeviationThresholdCM
        )

        DispatchQueue.main.async {
            self.latestSample = sample
            self.onSample?(sample)
        }
    }

    private func distance(from a: SCNVector3, to b: SCNVector3) -> Float {
        sqrtf(powf(a.x - b.x, 2) + powf(a.y - b.y, 2) + powf(a.z - b.z, 2))
    }
}

private extension ARCamera.TrackingState {
    var descriptionText: String {
        switch self {
        case .normal:
            return "Normal"
        case .notAvailable:
            return "Not available"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return "Limited: excessive motion"
            case .insufficientFeatures:
                return "Limited: insufficient features"
            case .initializing:
                return "Limited: initializing"
            case .relocalizing:
                return "Limited: relocalizing"
            @unknown default:
                return "Limited"
            }
        }
    }
}

// MARK: - Staircase

struct StaircaseTransition {
    let presentedLogMAR: Double
    let presentedStepIndex: Int
    let newLogMAR: Double
    let causedReversal: Bool
    let directionAfterResponse: StaircaseDirection?
    let isComplete: Bool
}

struct StaircaseState: Codable {
    static let levels: [Double] = stride(from: -0.1, through: 1.0, by: 0.1).map { ($0 * 10).rounded() / 10 }

    private(set) var currentStepIndex: Int
    private(set) var trialCount: Int = 0
    private(set) var consecutiveCorrect: Int = 0
    private(set) var lastDirection: StaircaseDirection?
    private(set) var reversalLogMARs: [Double] = []
    let maxTrials: Int
    let requiredReversals: Int

    init(startLogMAR: Double, maxTrials: Int = 30, requiredReversals: Int = 6) {
        let nearestIndex = StaircaseState.levels.indices.min { left, right in
            abs(StaircaseState.levels[left] - startLogMAR) < abs(StaircaseState.levels[right] - startLogMAR)
        } ?? StaircaseState.levels.count - 1
        self.currentStepIndex = nearestIndex
        self.maxTrials = maxTrials
        self.requiredReversals = requiredReversals
    }

    var currentLogMAR: Double {
        StaircaseState.levels[currentStepIndex]
    }

    var currentSnellenDenominator: Int {
        OptotypeSizer.snellenDenominator(forLogMAR: currentLogMAR)
    }

    var isComplete: Bool {
        trialCount >= maxTrials || reversalLogMARs.count >= requiredReversals
    }

    mutating func record(correct: Bool) -> StaircaseTransition {
        let presented = currentLogMAR
        let presentedIndex = currentStepIndex
        trialCount += 1

        var direction: StaircaseDirection?
        if correct {
            consecutiveCorrect += 1
            if consecutiveCorrect >= 2 {
                direction = .down
                consecutiveCorrect = 0
            }
        } else {
            direction = .up
            consecutiveCorrect = 0
        }

        var causedReversal = false
        if let direction = direction {
            if let lastDirection, lastDirection != direction {
                causedReversal = true
                reversalLogMARs.append(presented)
            }
            lastDirection = direction

            switch direction {
            case .down:
                currentStepIndex = max(0, currentStepIndex - 1)
            case .up:
                currentStepIndex = min(StaircaseState.levels.count - 1, currentStepIndex + 1)
            }
        }

        return StaircaseTransition(
            presentedLogMAR: presented,
            presentedStepIndex: presentedIndex,
            newLogMAR: currentLogMAR,
            causedReversal: causedReversal,
            directionAfterResponse: direction,
            isComplete: isComplete
        )
    }

    func finalLogMAR() -> Double {
        let source = reversalLogMARs.suffix(4)
        guard !source.isEmpty else {
            return currentLogMAR
        }
        return source.reduce(0, +) / Double(source.count)
    }
}

// MARK: - Persistence and Export

final class LandoltSessionStore {
    static let shared = LandoltSessionStore()

    private let storageKey = "LandoltCRewrittenSessions"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ session: TestSession) {
        var sessions = allSessions()
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        sessions.sort { $0.startedAt > $1.startedAt }
        if let data = try? encoder.encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func allSessions() -> [TestSession] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let sessions = try? decoder.decode([TestSession].self, from: data) else {
            return []
        }
        return sessions
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

enum UploadConfiguration {
    static let localServerUploadURL = URL(string: "http://localhost:5000/upload")
    static let dropboxFolderPath = "/Mahmoud Abdelmoneum/OHSU/Clinical_Trials/Landolt_C_Only_Trials"
}

enum LandoltExportManager {
    static func csv(for session: TestSession) -> String {
        let header = [
            "Session_ID",
            "Session_Started",
            "Eye",
            "Trial_Index",
            "Timestamp",
            "Staircase_Step_Index",
            "LogMAR",
            "Snellen",
            "Target_Distance_CM",
            "Live_Distance_CM",
            "Optotype_Diameter_CM",
            "Optotype_Diameter_Points",
            "Device_PPI",
            "Native_Scale",
            "Orientation_Displayed",
            "User_Response",
            "Is_Correct",
            "Response_Time_MS",
            "Was_Paused_During_Trial",
            "Pause_Count_At_Response",
            "Tracking_State",
            "Was_Distance_Sample_Stable",
            "Caused_Reversal",
            "Staircase_Direction_After_Response",
            "Device_Model",
            "System_Version",
            "App_Version"
        ].joined(separator: ",")

        var rows = [header]
        for trial in session.rightEye.trials + session.leftEye.trials {
            rows.append([
                escape(session.id),
                escape(formatDate(session.startedAt)),
                escape(trial.eye.rawValue),
                "\(trial.trialIndex)",
                escape(formatDate(trial.timestamp)),
                "\(trial.staircaseStepIndex)",
                String(format: "%.3f", trial.logMAR),
                "20/\(trial.snellenDenominator)",
                String(format: "%.2f", trial.targetDistanceCM),
                String(format: "%.2f", trial.liveDistanceCM),
                String(format: "%.4f", trial.optotypeDiameterCM),
                String(format: "%.2f", trial.optotypeDiameterPoints),
                String(format: "%.2f", trial.devicePPI),
                String(format: "%.2f", trial.nativeScale),
                escape(trial.orientationDisplayed.rawValue),
                escape(trial.userResponse.rawValue),
                trial.isCorrect ? "TRUE" : "FALSE",
                "\(trial.responseTimeMS)",
                trial.wasPausedDuringTrial ? "TRUE" : "FALSE",
                "\(trial.pauseEventCountAtResponse)",
                escape(trial.trackingStateDescription),
                trial.wasDistanceSampleStable ? "TRUE" : "FALSE",
                trial.causedReversal ? "TRUE" : "FALSE",
                escape(trial.staircaseDirectionAfterResponse?.rawValue ?? ""),
                escape(session.deviceMetadata.deviceModel),
                escape(session.deviceMetadata.systemVersion),
                escape(session.deviceMetadata.appVersion)
            ].joined(separator: ","))
        }

        return rows.joined(separator: "\n") + "\n"
    }

    static func jsonData(for session: TestSession) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(session)
    }

    static func temporaryExportFiles(for session: TestSession) throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory
        let baseName = "\(session.id)_export"
        let csvURL = directory.appendingPathComponent("\(baseName).csv")
        let jsonURL = directory.appendingPathComponent("\(baseName).json")
        try csv(for: session).write(to: csvURL, atomically: true, encoding: .utf8)
        try jsonData(for: session).write(to: jsonURL, options: .atomic)
        return [csvURL, jsonURL]
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

// MARK: - Coordinator

final class LandoltTestCoordinator {
    private let window: UIWindow
    private let navigationController = UINavigationController()
    private var session = TestSession()

    init(window: UIWindow) {
        self.window = window
        navigationController.navigationBar.prefersLargeTitles = false
    }

    func start() {
        showMainMenu()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
    }

    private func resetSession() {
        session = TestSession()
    }

    private func showMainMenu() {
        let controller = LandoltMainMenuViewController()
        controller.onStart = { [weak self] in
            self?.resetSession()
            self?.showInstructions()
        }
        controller.onHistory = { [weak self] in
            self?.showHistory()
        }
        navigationController.setViewControllers([controller], animated: false)
    }

    private func showInstructions() {
        let controller = LandoltInstructionsViewController()
        controller.onContinue = { [weak self] in
            self?.showDistance(for: .right)
        }
        navigationController.pushViewController(controller, animated: true)
    }

    private func showDistance(for eye: TestedEye) {
        let controller = LandoltDistanceViewController(eye: eye)
        controller.onCalibrationCaptured = { [weak self] calibration in
            guard let self else { return }
            var run = self.session.run(for: eye)
            run.calibration = calibration
            self.session.setRun(run)
            self.showAcuitySelection(for: eye)
        }
        navigationController.pushViewController(controller, animated: true)
    }

    private func showAcuitySelection(for eye: TestedEye) {
        let run = session.run(for: eye)
        guard let calibration = run.calibration else {
            showDistance(for: eye)
            return
        }

        let controller = LandoltAcuitySelectionViewController(eye: eye, calibration: calibration, metadata: session.deviceMetadata)
        controller.onAcuitySelected = { [weak self] startLogMAR in
            guard let self else { return }
            var updatedRun = self.session.run(for: eye)
            updatedRun.startingLogMAR = startLogMAR
            self.session.setRun(updatedRun)
            self.showTest(for: eye)
        }
        navigationController.pushViewController(controller, animated: true)
    }

    private func showTest(for eye: TestedEye) {
        let run = session.run(for: eye)
        guard run.calibration != nil, run.startingLogMAR != nil else {
            showDistance(for: eye)
            return
        }

        let controller = LandoltTestViewController(sessionId: session.id, run: run, metadata: session.deviceMetadata)
        controller.onFinished = { [weak self] completedRun in
            guard let self else { return }
            self.session.setRun(completedRun)
            if let nextEye = eye.next {
                self.showDistance(for: nextEye)
            } else {
                self.session.completedAt = Date()
                LandoltSessionStore.shared.save(self.session)
                self.showResults()
            }
        }
        navigationController.pushViewController(controller, animated: true)
    }

    private func showResults() {
        let controller = LandoltResultsViewController(session: session)
        controller.onHome = { [weak self] in
            self?.showMainMenu()
        }
        controller.onRetest = { [weak self] in
            self?.resetSession()
            self?.showInstructions()
        }
        navigationController.setViewControllers([navigationController.viewControllers.first ?? controller, controller], animated: true)
    }

    private func showHistory() {
        let controller = LandoltHistoryViewController()
        navigationController.pushViewController(controller, animated: true)
    }
}

// MARK: - Shared UI

enum LandoltStyle {
    static let teal = UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0)
    static let magenta = UIColor(red: 0.788, green: 0.169, blue: 0.369, alpha: 1.0)
    static let softBackground = UIColor(red: 0.975, green: 0.976, blue: 0.970, alpha: 1.0)
    static let warning = UIColor(red: 0.76, green: 0.10, blue: 0.10, alpha: 1.0)

    static func titleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        label.textColor = magenta
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func bodyLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func button(_ title: String, color: UIColor = teal) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}

class LandoltBaseViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = LandoltStyle.softBackground
    }

    func makeScrollContent() -> (UIScrollView, UIStackView) {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28)
        ])

        return (scrollView, stack)
    }
}

// MARK: - Screens

final class LandoltMainMenuViewController: LandoltBaseViewController {
    var onStart: (() -> Void)?
    var onHistory: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Landolt C"
        navigationItem.hidesBackButton = true

        let (_, stack) = makeScrollContent()
        stack.alignment = .center

        let titleLabel = LandoltStyle.titleLabel("Landolt C Visual Acuity")
        let subtitle = LandoltStyle.bodyLabel("A two-eye, distance-aware 4AFC staircase visual acuity test.")
        let preview = LandoltCView()
        preview.metrics = OptotypeSizer.metrics(snellenDenominator: 200, viewingDistanceCM: 40)
        preview.orientation = .right
        preview.translatesAutoresizingMaskIntoConstraints = false

        let start = LandoltStyle.button("Start Test")
        let history = LandoltStyle.button("History", color: .systemGray)

        start.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        history.addTarget(self, action: #selector(historyTapped), for: .touchUpInside)

        [titleLabel, subtitle, preview, start, history].forEach(stack.addArrangedSubview)

        NSLayoutConstraint.activate([
            preview.widthAnchor.constraint(equalToConstant: 96),
            preview.heightAnchor.constraint(equalToConstant: 96),
            start.widthAnchor.constraint(equalTo: stack.widthAnchor),
            history.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SharedAudioManager.shared.initializeDefaultSettings()
        SharedAudioManager.shared.playText("Landolt C visual acuity test. Tap start test to begin.", source: "Landolt Main")
    }

    @objc private func startTapped() {
        onStart?()
    }

    @objc private func historyTapped() {
        onHistory?()
    }
}

final class LandoltInstructionsViewController: LandoltBaseViewController {
    var onContinue: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Instructions"

        let (_, stack) = makeScrollContent()
        let titleLabel = LandoltStyle.titleLabel("How The Test Works")
        let body = LandoltStyle.bodyLabel("""
        For each eye, cover the other eye and hold the phone where the target is clearest.

        The app captures that distance, shows calibrated Landolt C sizes, then starts a swipe test.

        Swipe in the direction of the C opening. The test pauses if your distance leaves the allowed range.
        """)
        body.textAlignment = .left

        let continueButton = LandoltStyle.button("Continue")
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)

        [titleLabel, body, continueButton].forEach(stack.addArrangedSubview)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SharedAudioManager.shared.playText("Cover one eye at a time. Capture distance, select the smallest C you can see, then swipe in the direction of the opening.", source: "Landolt Instructions")
    }

    @objc private func continueTapped() {
        onContinue?()
    }
}

final class LandoltDistanceViewController: LandoltBaseViewController {
    var onCalibrationCaptured: ((DistanceCalibration) -> Void)?

    private let eye: TestedEye
    private let distanceService = DistanceMeasurementService()
    private let distanceLabel = LandoltStyle.bodyLabel("Distance: --")
    private let statusLabel = LandoltStyle.bodyLabel("Looking for your face...")
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let captureButton = LandoltStyle.button("Capture Distance")

    init(eye: TestedEye) {
        self.eye = eye
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "\(eye.rawValue) Eye Distance"

        let (_, stack) = makeScrollContent()
        stack.alignment = .center

        let titleLabel = LandoltStyle.titleLabel(eye.rawValue + " Eye")
        let instruction = LandoltStyle.bodyLabel(eye.coveredEyeInstruction + "\nMove the phone until the C target looks sharp, hold steady, then capture.")

        let target = LandoltCView()
        target.metrics = OptotypeSizer.metrics(snellenDenominator: 80, viewingDistanceCM: 40)
        target.orientation = .right
        target.translatesAutoresizingMaskIntoConstraints = false

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = LandoltStyle.teal
        captureButton.isEnabled = false
        captureButton.alpha = 0.55
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)

        let manualButton = LandoltStyle.button("Enter Distance Manually", color: .systemGray)
        manualButton.addTarget(self, action: #selector(manualTapped), for: .touchUpInside)

        [titleLabel, instruction, target, distanceLabel, progressView, statusLabel, captureButton, manualButton].forEach(stack.addArrangedSubview)

        NSLayoutConstraint.activate([
            target.widthAnchor.constraint(equalToConstant: 120),
            target.heightAnchor.constraint(equalToConstant: 120),
            progressView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            captureButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            manualButton.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        distanceService.onSample = { [weak self] sample in
            self?.handleSample(sample)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SharedAudioManager.shared.playText("\(eye.coveredEyeInstruction) Hold the phone at the clearest distance, then capture distance.", source: "Distance Capture")
        distanceService.start(for: eye, attachingTo: view)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        distanceService.stop()
    }

    private func handleSample(_ sample: DistanceSample) {
        if sample.distanceCM > 0 {
            distanceLabel.text = String(format: "Distance: %.1f cm", sample.distanceCM)
            progressView.progress = Float(min(max((sample.distanceCM - 10.0) / 90.0, 0), 1))
        } else {
            distanceLabel.text = "Distance: --"
            progressView.progress = 0
        }

        if sample.isStable {
            statusLabel.text = String(format: "Stable reading from %d samples (SD %.1f cm)", sample.sampleCount, sample.standardDeviationCM)
            statusLabel.textColor = LandoltStyle.teal
            captureButton.isEnabled = true
            captureButton.alpha = 1
        } else {
            statusLabel.text = "\(sample.trackingStateDescription). Hold steady until capture enables."
            statusLabel.textColor = .secondaryLabel
            captureButton.isEnabled = false
            captureButton.alpha = 0.55
        }
    }

    @objc private func captureTapped() {
        guard let calibration = distanceService.calibration(for: eye) else {
            showAlert(title: "Hold Steady", message: "A stable distance reading is not available yet.")
            return
        }
        onCalibrationCaptured?(calibration)
    }

    @objc private func manualTapped() {
        let alert = UIAlertController(title: "Manual Distance", message: "Enter testing distance in centimeters.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "40"
            field.keyboardType = .decimalPad
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Use Distance", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let text = alert?.textFields?.first?.text,
                  let value = Double(text),
                  (10.0...100.0).contains(value) else {
                self?.showAlert(title: "Invalid Distance", message: "Enter a distance from 10 to 100 cm.")
                return
            }
            let calibration = self.distanceService.manualCalibration(for: self.eye, distanceCM: value)
            self.onCalibrationCaptured?(calibration)
        })
        present(alert, animated: true)
    }
}

final class LandoltAcuitySelectionViewController: LandoltBaseViewController {
    var onAcuitySelected: ((Double) -> Void)?

    private let eye: TestedEye
    private let calibration: DistanceCalibration
    private let metadata: DeviceMetadata
    private let denominators = [200, 125, 80, 50, 20]

    init(eye: TestedEye, calibration: DistanceCalibration, metadata: DeviceMetadata) {
        self.eye = eye
        self.calibration = calibration
        self.metadata = metadata
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "\(eye.rawValue) Eye Acuity"

        let (_, stack) = makeScrollContent()
        let titleLabel = LandoltStyle.titleLabel("Select Starting Size")
        let instruction = LandoltStyle.bodyLabel("Tap the smallest C opening you can clearly identify at \(String(format: "%.1f", calibration.targetDistanceCM)) cm.")
        [titleLabel, instruction].forEach(stack.addArrangedSubview)

        for denominator in denominators {
            stack.addArrangedSubview(row(for: denominator))
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SharedAudioManager.shared.playText("Tap the smallest C opening you can clearly identify.", source: "Acuity Start")
    }

    private func row(for denominator: Int) -> UIButton {
        let metrics = OptotypeSizer.metrics(
            snellenDenominator: denominator,
            viewingDistanceCM: calibration.targetDistanceCM,
            ppi: metadata.ppi,
            nativeScale: metadata.nativeScale
        )
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.layer.cornerRadius = 8
        button.tag = denominator
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(acuityTapped(_:)), for: .touchUpInside)

        let cView = LandoltCView()
        cView.metrics = metrics
        cView.orientation = .right
        cView.translatesAutoresizingMaskIntoConstraints = false
        cView.isUserInteractionEnabled = false

        let label = UILabel()
        label.text = "20/\(denominator)  (LogMAR \(String(format: "%.1f", metrics.logMAR)))"
        label.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(cView)
        button.addSubview(label)

        let visualSize = max(metrics.outerDiameterPoints, 6)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            cView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 24),
            cView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            cView.widthAnchor.constraint(equalToConstant: visualSize),
            cView.heightAnchor.constraint(equalToConstant: visualSize),
            label.leadingAnchor.constraint(equalTo: cView.trailingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -18),
            label.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])

        return button
    }

    @objc private func acuityTapped(_ sender: UIButton) {
        let denominator = sender.tag
        onAcuitySelected?(OptotypeSizer.logMAR(forSnellenDenominator: denominator))
    }
}

final class LandoltTestViewController: LandoltBaseViewController {
    var onFinished: ((EyeRun) -> Void)?

    private let sessionId: String
    private var run: EyeRun
    private let metadata: DeviceMetadata
    private var staircase: StaircaseState
    private let distanceService = DistanceMeasurementService()
    private var currentDistanceCM: Double
    private var currentOrientation: LandoltOrientation = .right
    private var displayTime = Date()
    private var isPausedForDistance = false
    private var currentTrialHadPause = false
    private var pauseEventCount = 0
    private var lastAudioDistanceInstruction = ""
    private var currentTrackingStateDescription = "No live AR sample"
    private var currentDistanceSampleIsStable = false

    private let eyeLabel = LandoltStyle.titleLabel("")
    private let distanceLabel = LandoltStyle.bodyLabel("")
    private let statusLabel = LandoltStyle.bodyLabel("")
    private let progressLabel = LandoltStyle.bodyLabel("")
    private let landoltView = LandoltCView()
    private var optotypeWidthConstraint: NSLayoutConstraint!
    private var optotypeHeightConstraint: NSLayoutConstraint!

    init(sessionId: String, run: EyeRun, metadata: DeviceMetadata) {
        self.sessionId = sessionId
        self.run = run
        self.metadata = metadata
        let start = run.startingLogMAR ?? OptotypeSizer.logMAR(forSnellenDenominator: 200)
        self.staircase = StaircaseState(startLogMAR: start)
        self.currentDistanceCM = run.calibration?.targetDistanceCM ?? 40
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "\(run.eye.rawValue) Eye Test"
        navigationItem.hidesBackButton = true
        navigationItem.setHidesBackButton(true, animated: false)
        setupUI()
        setupEndTestButton()
        setupGestures()
        generateNextTrial()
        distanceService.onSample = { [weak self] sample in
            self?.handleDistanceSample(sample)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SharedAudioManager.shared.playText("Swipe in the direction of the C opening.", source: "Landolt Test")
        distanceService.start(for: run.eye, attachingTo: view)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        distanceService.stop()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        eyeLabel.text = "\(run.eye.rawValue) Eye"
        statusLabel.text = "Swipe in the direction the C opens."
        progressLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .medium)

        landoltView.translatesAutoresizingMaskIntoConstraints = false
        landoltView.gapColor = LandoltStyle.softBackground
        optotypeWidthConstraint = landoltView.widthAnchor.constraint(equalToConstant: 80)
        optotypeHeightConstraint = landoltView.heightAnchor.constraint(equalToConstant: 80)

        [eyeLabel, distanceLabel, statusLabel, landoltView, progressLabel].forEach(stack.addArrangedSubview)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            optotypeWidthConstraint,
            optotypeHeightConstraint
        ])
    }

    private func setupGestures() {
        for direction in [UISwipeGestureRecognizer.Direction.right, .left, .up, .down] {
            let recognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            recognizer.direction = direction
            view.addGestureRecognizer(recognizer)
        }
    }

    private func setupEndTestButton() {
        let button = UIBarButtonItem(
            title: "End Test",
            style: .plain,
            target: self,
            action: #selector(endTestTapped)
        )
        button.tintColor = .systemRed
        navigationItem.rightBarButtonItem = button
    }

    @objc private func endTestTapped() {
        let alert = UIAlertController(
            title: "End test?",
            message: "Your progress for this eye will be lost.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "End Test", style: .destructive) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func generateNextTrial() {
        let previous = currentOrientation
        let candidates = LandoltOrientation.allCases.filter { $0 != previous }
        currentOrientation = candidates.randomElement() ?? .right
        landoltView.orientation = currentOrientation
        currentTrialHadPause = false
        displayTime = Date()
        applyMetrics(distanceCM: currentDistanceCM)
        updateProgress()
    }

    private func applyMetrics(distanceCM: Double) {
        let metrics = OptotypeSizer.metrics(
            logMAR: staircase.currentLogMAR,
            viewingDistanceCM: distanceCM,
            ppi: metadata.ppi,
            nativeScale: metadata.nativeScale
        )
        landoltView.metrics = metrics
        let size = max(metrics.outerDiameterPoints, 2)
        optotypeWidthConstraint.constant = size
        optotypeHeightConstraint.constant = size
        view.layoutIfNeeded()
    }

    private func handleDistanceSample(_ sample: DistanceSample) {
        guard sample.distanceCM > 0, let calibration = run.calibration else { return }
        currentDistanceCM = sample.distanceCM
        currentTrackingStateDescription = sample.trackingStateDescription
        currentDistanceSampleIsStable = sample.isStable
        distanceLabel.text = String(
            format: "%.1f cm  Target %.1f cm  Range %.1f-%.1f cm",
            sample.distanceCM,
            calibration.targetDistanceCM,
            calibration.lowerBoundCM,
            calibration.upperBoundCM
        )

        let band = DistanceMeasurementService.bandStatus(distanceCM: sample.distanceCM, calibration: calibration)
        switch band {
        case .inBand:
            if isPausedForDistance && !sample.isStable {
                statusLabel.text = "Distance restored. Hold steady to resume."
                statusLabel.textColor = LandoltStyle.teal
                landoltView.isHidden = true
                return
            }

            if isPausedForDistance {
                statusLabel.text = "Distance restored. Continue swiping."
                statusLabel.textColor = LandoltStyle.teal
            } else {
                statusLabel.text = "Swipe in the direction the C opens."
                statusLabel.textColor = .label
            }
            isPausedForDistance = false
            landoltView.isHidden = false
            landoltView.alpha = 1.0
            applyMetrics(distanceCM: sample.distanceCM)
            lastAudioDistanceInstruction = ""
        case .below, .above:
            if !isPausedForDistance {
                pauseEventCount += 1
                currentTrialHadPause = true
            }
            isPausedForDistance = true
            landoltView.isHidden = true
            statusLabel.text = band.displayText
            statusLabel.textColor = LandoltStyle.warning
            if lastAudioDistanceInstruction != band.displayText {
                SharedAudioManager.shared.playText(band.displayText, source: "Distance Alarm")
                lastAudioDistanceInstruction = band.displayText
            }
        }
    }

    private func updateProgress() {
        progressLabel.text = "Trial \(staircase.trialCount + 1) of 30  Reversals \(staircase.reversalLogMARs.count)/6  Current 20/\(staircase.currentSnellenDenominator)"
    }

    @objc private func handleSwipe(_ recognizer: UISwipeGestureRecognizer) {
        guard !isPausedForDistance else {
            statusLabel.text = "Paused: adjust your distance before answering."
            return
        }
        guard let response = LandoltTestViewController.orientation(for: recognizer.direction),
              let calibration = run.calibration else {
            return
        }

        let responseTime = Int(Date().timeIntervalSince(displayTime) * 1000)
        let correct = response == currentOrientation
        let presentedLogMAR = staircase.currentLogMAR
        let presentedStepIndex = staircase.currentStepIndex
        let metrics = OptotypeSizer.metrics(
            logMAR: presentedLogMAR,
            viewingDistanceCM: currentDistanceCM,
            ppi: metadata.ppi,
            nativeScale: metadata.nativeScale
        )
        let transition = staircase.record(correct: correct)

        let record = TrialRecord(
            sessionId: sessionId,
            eye: run.eye,
            trialIndex: run.trials.count + 1,
            timestamp: Date(),
            staircaseStepIndex: presentedStepIndex,
            logMAR: presentedLogMAR,
            snellenDenominator: metrics.snellenDenominator,
            targetDistanceCM: calibration.targetDistanceCM,
            liveDistanceCM: currentDistanceCM,
            optotypeDiameterCM: metrics.outerDiameterCM,
            optotypeDiameterPoints: metrics.outerDiameterPoints,
            devicePPI: metadata.ppi,
            nativeScale: metadata.nativeScale,
            orientationDisplayed: currentOrientation,
            userResponse: response,
            isCorrect: correct,
            responseTimeMS: responseTime,
            wasPausedDuringTrial: currentTrialHadPause,
            pauseEventCountAtResponse: pauseEventCount,
            trackingStateDescription: currentTrackingStateDescription,
            wasDistanceSampleStable: currentDistanceSampleIsStable,
            causedReversal: transition.causedReversal,
            staircaseDirectionAfterResponse: transition.directionAfterResponse
        )

        run.trials.append(record)
        run.reversalLogMARs = staircase.reversalLogMARs

        if transition.isComplete {
            finishRun()
        } else {
            generateNextTrial()
        }
    }

    private func finishRun() {
        let finalLogMAR = staircase.finalLogMAR()
        run.finalLogMAR = finalLogMAR
        run.finalSnellenDenominator = OptotypeSizer.snellenDenominator(forLogMAR: finalLogMAR)
        run.reversalLogMARs = staircase.reversalLogMARs
        onFinished?(run)
    }

    private static func orientation(for direction: UISwipeGestureRecognizer.Direction) -> LandoltOrientation? {
        switch direction {
        case .right:
            return .right
        case .left:
            return .left
        case .up:
            return .up
        case .down:
            return .down
        default:
            return nil
        }
    }
}

final class LandoltResultsViewController: LandoltBaseViewController {
    var onHome: (() -> Void)?
    var onRetest: (() -> Void)?

    private let session: TestSession

    init(session: TestSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Results"
        navigationItem.hidesBackButton = true

        let (_, stack) = makeScrollContent()
        let titleLabel = LandoltStyle.titleLabel("Test Complete")
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(resultLabel(for: session.rightEye))
        stack.addArrangedSubview(resultLabel(for: session.leftEye))

        let export = LandoltStyle.button("Export CSV + JSON", color: .systemBlue)
        let retest = LandoltStyle.button("Retest", color: .systemRed)
        let home = LandoltStyle.button("Home")
        export.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        retest.addTarget(self, action: #selector(retestTapped), for: .touchUpInside)
        home.addTarget(self, action: #selector(homeTapped), for: .touchUpInside)
        [export, retest, home].forEach(stack.addArrangedSubview)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SharedAudioManager.shared.playText("The visual acuity test is complete. Results are displayed for each eye.", source: "Landolt Results")
    }

    private func resultLabel(for run: EyeRun) -> UILabel {
        let denominator = run.finalSnellenDenominator.map { "20/\($0)" } ?? "Not complete"
        let logMAR = run.finalLogMAR.map { String(format: "%.3f", $0) } ?? "--"
        let text = "\(run.eye.rawValue) Eye\nSnellen: \(denominator)\nLogMAR: \(logMAR)\nTrials: \(run.trials.count)\nReversals: \(run.reversalLogMARs.count)"
        let label = LandoltStyle.bodyLabel(text)
        label.backgroundColor = .white
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.textAlignment = .center
        return label
    }

    @objc private func exportTapped() {
        do {
            let urls = try LandoltExportManager.temporaryExportFiles(for: session)
            let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            if let popover = controller.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
                popover.permittedArrowDirections = []
            }
            controller.completionWithItemsHandler = { _, _, _, _ in
                urls.forEach { try? FileManager.default.removeItem(at: $0) }
            }
            present(controller, animated: true)
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    @objc private func retestTapped() {
        onRetest?()
    }

    @objc private func homeTapped() {
        onHome?()
    }
}

final class LandoltHistoryViewController: LandoltBaseViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "History"

        let (_, stack) = makeScrollContent()
        let sessions = LandoltSessionStore.shared.allSessions()
        stack.addArrangedSubview(LandoltStyle.titleLabel("Completed Sessions"))

        if sessions.isEmpty {
            stack.addArrangedSubview(LandoltStyle.bodyLabel("No rewritten Landolt-C sessions have been saved yet."))
            return
        }

        for session in sessions {
            let right = summary(for: session.rightEye)
            let left = summary(for: session.leftEye)
            let label = LandoltStyle.bodyLabel("\(format(session.startedAt))\nRight: \(right)\nLeft: \(left)")
            label.textAlignment = .left
            label.backgroundColor = .white
            label.layer.cornerRadius = 8
            label.layer.masksToBounds = true
            stack.addArrangedSubview(label)

            let export = LandoltStyle.button("Export This Session", color: .systemBlue)
            export.addAction(UIAction { [weak self] _ in
                self?.export(session)
            }, for: .touchUpInside)
            stack.addArrangedSubview(export)
        }
    }

    private func export(_ session: TestSession) {
        do {
            let urls = try LandoltExportManager.temporaryExportFiles(for: session)
            let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            if let popover = controller.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
                popover.permittedArrowDirections = []
            }
            controller.completionWithItemsHandler = { _, _, _, _ in
                urls.forEach { try? FileManager.default.removeItem(at: $0) }
            }
            present(controller, animated: true)
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    private func summary(for run: EyeRun) -> String {
        guard let logMAR = run.finalLogMAR, let snellen = run.finalSnellenDenominator else {
            return "Incomplete"
        }
        return "20/\(snellen), LogMAR \(String(format: "%.3f", logMAR))"
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private extension UIViewController {
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Debug Core Checks

#if DEBUG
enum LandoltCoreSelfTests {
    static func run() {
        testOptotypeSizing()
        testLandoltGeometry()
        testStaircaseReversals()
        testDistanceBand()
    }

    private static func testOptotypeSizing() {
        let twentyTwenty = OptotypeSizer.metrics(snellenDenominator: 20, viewingDistanceCM: 40, ppi: 400, nativeScale: 2)
        let twentyTwoHundred = OptotypeSizer.metrics(snellenDenominator: 200, viewingDistanceCM: 40, ppi: 400, nativeScale: 2)
        assert(twentyTwoHundred.outerDiameterCM > twentyTwenty.outerDiameterCM * 9.5)
        assert(twentyTwenty.outerDiameterPoints > 0)
    }

    private static func testLandoltGeometry() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let gap = LandoltCView.gapRect(for: .right, outerRect: rect, stroke: 20)
        assert(abs(gap.height - 20) < 0.001)
        assert(gap.minX == 50)
    }

    private static func testStaircaseReversals() {
        var state = StaircaseState(startLogMAR: 0.6)
        _ = state.record(correct: true)
        _ = state.record(correct: true)
        let transition = state.record(correct: false)
        assert(transition.causedReversal)
        assert(state.reversalLogMARs.count == 1)
    }

    private static func testDistanceBand() {
        let calibration = DistanceCalibration(eye: .right, targetDistanceCM: 40, sampleCount: 10, sampleStandardDeviationCM: 0.5, captureMethod: "Test")
        assert(DistanceMeasurementService.bandStatus(distanceCM: 40, calibration: calibration) == .inBand)
        assert(DistanceMeasurementService.bandStatus(distanceCM: 35, calibration: calibration) == .below)
        assert(DistanceMeasurementService.bandStatus(distanceCM: 45, calibration: calibration) == .above)
    }
}
#endif
