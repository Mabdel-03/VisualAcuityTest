import ARKit
import UIKit

extension Notification.Name {
    static let eyeDistanceDidChange = Notification.Name("eyeDistanceDidChange")
}

struct EyeDistanceSample: Equatable {
    static let acceptedRangeCM = 10.0...100.0

    let distanceCM: Double
    let eyeNumber: Int
    let timestamp: Date

    func isValid(at date: Date = Date(), maximumAge: TimeInterval = 0.5) -> Bool {
        let age = date.timeIntervalSince(timestamp)
        return distanceCM.isFinite
            && maximumAge.isFinite
            && maximumAge >= 0
            && Self.acceptedRangeCM.contains(distanceCM)
            && age.isFinite
            && age >= 0
            && age <= maximumAge
    }
}

enum EyeDistanceState: Equatable {
    case idle
    case tracking
    case unsupported
    case interrupted
    case failed
}

enum EyeDistanceValidity: Equatable {
    case valid
    case missing
    case stale
    case outOfRange
    case unsupported
    case interrupted
    case failed
}

struct EyeDistanceClientLease {
    private(set) var activeClientID: ObjectIdentifier?

    var hasActiveClient: Bool { activeClientID != nil }

    mutating func claim(_ client: AnyObject) {
        activeClientID = ObjectIdentifier(client)
    }

    mutating func release(_ client: AnyObject) -> Bool {
        guard activeClientID == ObjectIdentifier(client) else { return false }
        activeClientID = nil
        return true
    }
}

final class EyeDistanceProvider: NSObject, ARSessionDelegate {
    static let shared = EyeDistanceProvider()

    private let session = ARSession()
    private var recentDistances: [Double] = []
    private let maximumReadings = 5
    private var lastMeasurementWasOutOfRange = false
    private var clientLease = EyeDistanceClientLease()

    private(set) var latestSample: EyeDistanceSample?
    private(set) var state: EyeDistanceState = .idle
    private(set) var eyeNumber = 2

    override private init() {
        super.init()
        session.delegate = self
        session.delegateQueue = .main
    }

    func start(eyeNumber: Int, client: AnyObject) {
        clientLease.claim(client)
        if state == .tracking, self.eyeNumber == eyeNumber {
            return
        }
        beginTracking(eyeNumber: eyeNumber)
    }

    private func beginTracking(eyeNumber: Int) {
        self.eyeNumber = eyeNumber
        recentDistances.removeAll()
        latestSample = nil
        lastMeasurementWasOutOfRange = false
        guard ARFaceTrackingConfiguration.isSupported else {
            state = .unsupported
            notifyChange()
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        state = .tracking
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        notifyChange()
    }

    func updateEyeNumber(_ eyeNumber: Int) {
        guard self.eyeNumber != eyeNumber else { return }
        self.eyeNumber = eyeNumber
        recentDistances.removeAll()
        latestSample = nil
        lastMeasurementWasOutOfRange = false
        notifyChange()
    }

    func stop(client: AnyObject) {
        guard clientLease.release(client) else { return }
        session.pause()
        state = .idle
        recentDistances.removeAll()
        latestSample = nil
        lastMeasurementWasOutOfRange = false
        notifyChange()
    }

    func validity(maximumAge: TimeInterval = 0.5, now: Date = Date()) -> EyeDistanceValidity {
        Self.validity(
            state: state,
            latestSample: latestSample,
            lastMeasurementWasOutOfRange: lastMeasurementWasOutOfRange,
            eyeNumber: eyeNumber,
            maximumAge: maximumAge,
            now: now
        )
    }

    static func validity(
        state: EyeDistanceState,
        latestSample: EyeDistanceSample?,
        lastMeasurementWasOutOfRange: Bool,
        eyeNumber: Int,
        maximumAge: TimeInterval = 0.5,
        now: Date = Date()
    ) -> EyeDistanceValidity {
        switch state {
        case .idle:
            return .missing
        case .unsupported:
            return .unsupported
        case .interrupted:
            return .interrupted
        case .failed:
            return .failed
        case .tracking:
            if lastMeasurementWasOutOfRange { return .outOfRange }
            guard let sample = latestSample else { return .missing }
            guard sample.eyeNumber == eyeNumber else { return .missing }
            guard sample.distanceCM.isFinite,
                  EyeDistanceSample.acceptedRangeCM.contains(sample.distanceCM) else {
                return .outOfRange
            }
            let age = now.timeIntervalSince(sample.timestamp)
            guard maximumAge.isFinite,
                  maximumAge >= 0,
                  age.isFinite,
                  age >= 0,
                  age <= maximumAge else {
                return .stale
            }
            return .valid
        }
    }

    func validSample(maximumAge: TimeInterval = 0.5, now: Date = Date()) -> EyeDistanceSample? {
        guard validity(maximumAge: maximumAge, now: now) == .valid,
              let sample = latestSample,
              sample.eyeNumber == eyeNumber,
              sample.isValid(at: now, maximumAge: maximumAge) else {
            return nil
        }
        return sample
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard state == .tracking,
              let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first,
              let frame = session.currentFrame else { return }

        let relativeEyeTransform = eyeNumber == 1
            ? faceAnchor.leftEyeTransform
            : faceAnchor.rightEyeTransform
        let worldEyeTransform = simd_mul(faceAnchor.transform, relativeEyeTransform)
        let eyePosition = SIMD3<Float>(
            worldEyeTransform.columns.3.x,
            worldEyeTransform.columns.3.y,
            worldEyeTransform.columns.3.z
        )
        let cameraTransform = frame.camera.transform
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        // ARKit measures eye-to-camera distance. The small camera-to-optotype-center
        // offset remains a documented approximation for physical hardware validation.
        let rawDistanceCM = Double(simd_distance(eyePosition, cameraPosition) * 100)
        guard EyeDistanceSample.acceptedRangeCM.contains(rawDistanceCM) else {
            lastMeasurementWasOutOfRange = true
            latestSample = nil
            notifyChange()
            return
        }

        recentDistances.append(rawDistanceCM)
        if recentDistances.count > maximumReadings {
            recentDistances.removeFirst()
        }
        let smoothedDistance = recentDistances.reduce(0, +) / Double(recentDistances.count)
        let sample = EyeDistanceSample(
            distanceCM: smoothedDistance,
            eyeNumber: eyeNumber,
            timestamp: Date()
        )
        lastMeasurementWasOutOfRange = false
        latestSample = sample
        DistanceTracker.shared.currentDistanceCM = smoothedDistance
        notifyChange()
    }

    func sessionWasInterrupted(_ session: ARSession) {
        state = .interrupted
        lastMeasurementWasOutOfRange = false
        latestSample = nil
        notifyChange()
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        guard clientLease.hasActiveClient else {
            state = .idle
            notifyChange()
            return
        }
        beginTracking(eyeNumber: eyeNumber)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        state = .failed
        lastMeasurementWasOutOfRange = false
        latestSample = nil
        notifyChange()
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .eyeDistanceDidChange, object: latestSample)
    }
}
