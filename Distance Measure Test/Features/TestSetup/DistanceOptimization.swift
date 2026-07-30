import UIKit
import SceneKit
import ARKit
import AVFoundation

var averageDistanceCM = 0.0

/*
 The DistanceTracker class is designed to manage distance measurements. 
 It provides real-time distance tracking with smoothing algorithms and persistent 
 storage capabilities.
 */

class DistanceTracker {
    static let shared = DistanceTracker()

    var currentDistanceCM: Double = 0.0  // Live tracking distance
    var targetDistanceCM: Double = 0.0   // Captured optimal distance
    
    // Buffer for smoothing distance readings
    private var recentReadings: [Double] = []
    private let maxReadings = 5

    /* Private initializer enforcing singleton pattern
    */
    private init() {}

    var preferredHoldingDistanceCM: Double? {
        if let target = Self.validatedHoldingDistance(targetDistanceCM) {
            return target
        }
        let saved = UserDefaults.standard.object(forKey: "SavedTargetDistance") as? Double
        guard let restored = Self.validatedHoldingDistance(saved) else {
            targetDistanceCM = 0
            return nil
        }
        targetDistanceCM = restored
        return restored
    }

    static func validatedHoldingDistance(_ distanceCM: Double?) -> Double? {
        guard let distanceCM,
              distanceCM.isFinite,
              EyeDistanceSample.acceptedRangeCM.contains(distanceCM) else {
            return nil
        }
        return distanceCM
    }

    @discardableResult
    func saveHoldingDistance(_ distanceCM: Double) -> Bool {
        guard let validated = Self.validatedHoldingDistance(distanceCM) else { return false }
        targetDistanceCM = validated
        UserDefaults.standard.set(validated, forKey: "SavedTargetDistance")
        return true
    }
    
    /* Adds a new distance reading with smoothing algorithm. 
        Validates input (rejects values ≤ 0), adds reading to buffer, 
        maintains buffer size limit, and updates currentDistanceCM with 
        smoothed average.
        @param distance: Distance value in centimeters
    */
    func addReading(_ distance: Double) {
        // Don't add invalid readings
        if distance <= 0 {
            return
        }
        // Add to recent readings
        recentReadings.append(distance)
        // Keep only the most recent readings
        if recentReadings.count > maxReadings {
            recentReadings.removeFirst()
        }
        // Update current distance with smoothed value
        if !recentReadings.isEmpty {
            currentDistanceCM = recentReadings.reduce(0, +) / Double(recentReadings.count)
        }
    }
}



/* DistanceOptimization class is designed to manage the distance optimization scene on the
    visual acuity app. On this page, the user is asked to hold their phone at a distance where
    they can clearly see the flower image. When the image appears the most clear, the user
    taps 'Capture Distance' button to save this distance as the optimal distance for their test.
*/

class DistanceOptimization: UIViewController {
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var captureDistanceButton: UIButton!
    var lastCapturedDistance: Double = 0.0
    private var distanceTimer: Timer?

    // This is true only while the shared provider has a current, valid sample.
    private var hasDetectedFace = false {
        didSet {
            guard hasDetectedFace != oldValue else { return }
            updateCaptureAvailability()
        }
    }

    // MARK: - Stability Detection
    // The button should only become available once the measured distance has
    // held roughly steady for a continuous window, not just at the first
    // instant a face is detected (a face detected mid-movement produces a
    // meaningless reading). Tracked as a streak anchored to the first reading
    // of the current run: as long as later readings stay within tolerance of
    // it, the streak (and its elapsed time) keeps growing; a reading outside
    // tolerance restarts the streak from that new reading.
    private let stabilityWindowSeconds: TimeInterval = 3.0
    private let stabilityToleranceCM: Double = 4.0
    private var stabilityAnchorDistanceCM: Double?
    private var stabilityStreakStartedAt: Date?
    private var isDistanceStable = false {
        didSet {
            guard isDistanceStable != oldValue else { return }
            updateCaptureAvailability()
        }
    }

    // Tracks what the countdown label is currently showing, so repeated
    // samples with the same remaining-second value don't re-trigger the
    // change animation on every frame.
    private var lastDisplayedCountdown: Int?
    
    // Header label
    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Get Best Distance"
        label.drawHeader()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var holdSteadyLabel: UILabel = {
        let label = UILabel()
        label.text = "Hold camera steady for"
        label.drawInstruction()
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var statusRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // Shows the whole seconds remaining until the distance has held steady
    // for stabilityWindowSeconds, e.g. "3 s" -> "2 s" -> "1 s".
    private lazy var countdownLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        label.textColor = AppThemeColors.black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add decorative daisies
        addDecorativeDaisies()
        
        // Add header label
        view.addSubview(headerLabel)
        view.bringSubviewToFront(headerLabel)

        view.addSubview(statusRowStack)
        view.bringSubviewToFront(statusRowStack)
        statusRowStack.addArrangedSubview(holdSteadyLabel)
        statusRowStack.addArrangedSubview(countdownLabel)
        
        // Set up header constraints
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            statusRowStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusRowStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            statusRowStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            statusRowStack.bottomAnchor.constraint(equalTo: captureDistanceButton.topAnchor, constant: -16)
        ])

        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        // Create a new scene
        let scene = SCNScene(named: "/ship.scn")!
        // Set the scene to the view
        sceneView.scene = scene

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
        animateDecorativeDaisies()
    }

    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let instructionText = "Position phone for clear flower view, then tap Capture Distance."
        SharedAudioManager.shared.playText(instructionText, source: "Distance Optimization")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // hasDetectedFace/isDistanceStable's didSet only react to changes, so
        // force the waiting UI back on for this fresh session even if they
        // were left true from a previous appearance.
        hasDetectedFace = false
        resetStabilityStreak()
        prepareCaptureButtonAwaitingFaceDetection()

        EyeDistanceProvider.shared.start(
            eyeNumber: VisualAcuitySession.currentEyeNumber,
            client: self
        )
        distanceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in self?.refreshDistanceState()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        distanceTimer?.invalidate()
        distanceTimer = nil
        EyeDistanceProvider.shared.stop(client: self)
    }

    /* Puts the capture UI in its "waiting for a face" state: button disabled,
       "Hold camera steady" status row with animated dots visible. Called up
       front, and again on every fresh appearance — actual enabling happens in
       updateCaptureAvailability() once a face has been detected AND held
       steady for stabilityWindowSeconds.
    */
    private func prepareCaptureButtonAwaitingFaceDetection() {
        statusRowStack.isHidden = false
        holdSteadyLabel.isHidden = false
        captureDistanceButton.isEnabled = false
        captureDistanceButton.alpha = 0.45
        animateStatusRowEntranceIfNeeded()
        resetCountdownDisplay()
    }

    /* Reflects hasDetectedFace + isDistanceStable in the UI: only enable
       Capture Distance once ARKit has found a face AND the measured distance
       has held steady for stabilityWindowSeconds. Disables it again the
       moment either condition stops holding, so the user can't capture a
       stale/placeholder or mid-movement reading.
    */
    private func updateCaptureAvailability() {
        if hasDetectedFace && isDistanceStable {
            statusRowStack.isHidden = true
            captureDistanceButton.isEnabled = true
            UIView.animate(withDuration: 0.2) {
                self.captureDistanceButton.alpha = 1.0
            }
        } else {
            prepareCaptureButtonAwaitingFaceDetection()
        }
    }

    private func animateStatusRowEntranceIfNeeded() {
        guard statusRowStack.alpha == 1, statusRowStack.transform == .identity else { return }
        statusRowStack.alpha = 0
        statusRowStack.transform = CGAffineTransform(translationX: -24, y: 0)
        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.statusRowStack.alpha = 1
                self.statusRowStack.transform = .identity
            }
        )
    }

    /* Resets the countdown label back to its starting value ("3 s") —
       called whenever the stability streak resets (see resetStabilityStreak).
    */
    private func resetCountdownDisplay() {
        let startingValue = Int(stabilityWindowSeconds)
        lastDisplayedCountdown = startingValue
        countdownLabel.isHidden = false
        countdownLabel.alpha = 1
        countdownLabel.transform = .identity
        countdownLabel.text = "\(startingValue) s"
    }

    /* Shows the whole seconds remaining until the current stability streak
       reaches stabilityWindowSeconds — "3 s", then "2 s", then "1 s" — updating
       only when the displayed number actually changes.
    */
    private func updateCountdownDisplay(elapsedSeconds: TimeInterval) {
        let remaining = max(0, Int((stabilityWindowSeconds - elapsedSeconds).rounded(.up)))
        guard remaining != lastDisplayedCountdown else { return }
        lastDisplayedCountdown = remaining

        guard remaining > 0 else {
            // Fully stable — updateCaptureAvailability hides the whole row.
            return
        }

        countdownLabel.text = "\(remaining) s"
        countdownLabel.isHidden = false
        countdownLabel.alpha = 0
        countdownLabel.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.countdownLabel.alpha = 1
                self.countdownLabel.transform = .identity
            }
        )
    }

    /* Captures the distance and immediately transitions to the next scene when the 
    user taps the 'Capture Distance' button.
    */
    @IBAction func capDistanceTransition(_ sender: Any) {
        guard hasDetectedFace,
              isDistanceStable,
              let sample = EyeDistanceProvider.shared.validSample() else {
            print("⚠️ Cannot capture distance: current eye distance is unavailable")
            return
        }

        // Store the target distance
        let distanceValue = sample.distanceCM
        averageDistanceCM = distanceValue
        guard DistanceTracker.shared.saveHoldingDistance(distanceValue) else { return }
        
        // Reset the recent readings with the new target
        DistanceTracker.shared.addReading(distanceValue)
        
        // Set current distance to match target
        DistanceTracker.shared.currentDistanceCM = distanceValue

        print("🎯 Target Distance Captured: \(String(format: "%.1f", averageDistanceCM)) cm")
        lastCapturedDistance = distanceValue
        
    }
    
    private func refreshDistanceState() {
        guard let sample = EyeDistanceProvider.shared.validSample() else {
            if hasDetectedFace {
                hasDetectedFace = false
                resetStabilityStreak()
            }
            return
        }
        if !hasDetectedFace {
            resetStabilityStreak()
            hasDetectedFace = true
        }
        recordDistanceSample(sample.distanceCM)
    }

    /* Records a distance reading and updates the stability streak: as long as
       each new reading stays within stabilityToleranceCM of the reading that
       started the current streak, the streak's elapsed time keeps growing and
       drives both the waiting dots and (once it reaches stabilityWindowSeconds)
       isDistanceStable, which the capture button waits on.
    */
    private func recordDistanceSample(_ distanceCM: Double) {
        guard hasDetectedFace else {
            resetStabilityStreak()
            return
        }

        let now = Date()

        if let anchor = stabilityAnchorDistanceCM, abs(distanceCM - anchor) <= stabilityToleranceCM {
            // Still within tolerance of the reading that started this streak —
            // let it keep running.
        } else {
            // First reading of a new streak, or this one drifted too far from
            // the anchor — restart the clock from here.
            stabilityAnchorDistanceCM = distanceCM
            stabilityStreakStartedAt = now
        }

        let elapsed = stabilityStreakStartedAt.map { now.timeIntervalSince($0) } ?? 0
        updateCountdownDisplay(elapsedSeconds: elapsed)
        isDistanceStable = elapsed >= stabilityWindowSeconds
    }

    /* Clears the stability streak and its on-screen countdown — called
       whenever tracking is lost or restarted, so stale progress never carries
       over into a new attempt.
    */
    private func resetStabilityStreak() {
        stabilityAnchorDistanceCM = nil
        stabilityStreakStartedAt = nil
        resetCountdownDisplay()
        isDistanceStable = false
    }

}

extension DistanceOptimization {
    /* Adds decorative daisy flowers to the background for visual cohesion.
    */
    func addDecorativeDaisies() {
        // Decorative daisy 1 - top right (magenta)
        addDecorativeDaisy(
            size: 90,
            petalColor: AppThemeColors.magentaAccent,
            centerColor: UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0),
            alpha: 0.07,
            trailingOffset: 25,
            topOffset: 150
        )
        
        // Decorative daisy 2 - bottom left (teal)
        addDecorativeDaisy(
            size: 85,
            petalColor: AppThemeColors.teal,
            centerColor: UIColor(red: 0.251, green: 0.427, blue: 0.455, alpha: 1.0),
            alpha: 0.11,
            leadingOffset: 30,
            bottomOffset: 100
        )
    }
}

// Helper function to calculate distance between two SCNVector3 points
func SCNVector3Distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
    return sqrtf(
        powf(a.x - b.x, 2) +
        powf(a.y - b.y, 2) +
        powf(a.z - b.z, 2)
    )
}
