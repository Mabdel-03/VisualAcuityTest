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
    taps the 'Capture Distance' button and holds the phone still through a short countdown;
    the distance measured across that steady window is then saved as the optimal distance
    for their test.
*/

class DistanceOptimization: UIViewController {
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var captureDistanceButton: UIButton!
    var lastCapturedDistance: Double = 0.0
    private var distanceTimer: Timer?

    // The push to acuity selection hangs off this view controller rather than
    // off the button, so the transition can wait for the hold countdown to
    // finish instead of firing the instant the button is tapped.
    private static let acuitySelectionSegueIdentifier = "ShowAcuitySelection"

    // MARK: - Capture Flow
    // The user decides when the distance is right: they tap Capture Distance,
    // then hold the phone still for holdDurationSeconds. Only readings taken
    // inside that window feed the captured value, so a reading grabbed
    // mid-movement can never become the test distance. Drifting further than
    // holdToleranceCM from where the hold started — or losing face tracking —
    // voids the countdown and asks the user to try again.
    private enum CaptureState {
        case awaitingFace   // no usable ARKit reading yet, so nothing to capture
        case ready          // face tracked; waiting on the user to tap Capture
        case holding        // countdown running; the phone has to stay put
        case captured       // distance saved; transitioning to acuity selection
    }

    private var captureState: CaptureState = .awaitingFace {
        didSet {
            guard captureState != oldValue else { return }
            applyCaptureState()
        }
    }

    private let holdDurationSeconds: TimeInterval = 2.0
    private let holdToleranceCM: Double = 4.0

    // How long a "that didn't work" message stays up before the status row goes
    // back to describing the current state.
    private let retryNoticeSeconds: TimeInterval = 2.5

    private var holdStartedAt: Date?
    private var holdAnchorDistanceCM: Double?
    private var holdReadings: [Double] = []
    private var lastRecordedSampleTimestamp: Date?

    // Tracks what the countdown label is currently showing, so repeated samples
    // with the same remaining-second value don't re-trigger the change
    // animation on every tick.
    private var lastDisplayedCountdown: Int?

    private var retryNotice: String?
    private var retryNoticeTimer: Timer?

    // Header label
    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Get Best Distance"
        label.drawHeader()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Describes whatever the capture flow is waiting on right now — a face, a
    // tap, a steady hold — or why the last attempt didn't take.
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.drawInstruction()
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
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

    // Shows the whole seconds left in the hold countdown, e.g. "2 s" -> "1 s".
    private lazy var countdownLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 30, weight: .bold)
        label.textColor = AppThemeColors.black
        label.textAlignment = .center
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
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
        statusRowStack.addArrangedSubview(statusLabel)
        statusRowStack.addArrangedSubview(countdownLabel)

        // The button's visible title has to stay short enough to fit, but
        // VoiceOver has room for the control's full name.
        captureDistanceButton.accessibilityLabel = "Capture Distance"

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
        let instructionText = "Position phone for clear flower view, then tap Capture Distance and hold still."
        SharedAudioManager.shared.playText(instructionText, source: "Distance Optimization")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        resetCaptureFlow()

        EyeDistanceProvider.shared.start(
            eyeNumber: VisualAcuitySession.currentEyeNumber,
            client: self
        )
        distanceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in self?.refreshCaptureFlow()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        distanceTimer?.invalidate()
        distanceTimer = nil
        retryNoticeTimer?.invalidate()
        retryNoticeTimer = nil
        EyeDistanceProvider.shared.stop(client: self)
    }

    deinit {
        distanceTimer?.invalidate()
        retryNoticeTimer?.invalidate()
    }

    /* Returns the capture flow to its starting point for a fresh appearance:
       any half-finished hold discarded, any stale retry message cleared, and
       the UI back to waiting on a face. captureState's didSet only reacts to
       changes, so the UI is applied directly rather than relying on it.
    */
    private func resetCaptureFlow() {
        clearHold()
        clearRetryNotice()
        captureState = .awaitingFace
        applyCaptureState()
    }

    // MARK: - Capture UI

    /* The one place the capture UI is derived from captureState: what the
       status row says, whether the countdown is on screen, and whether Capture
       Distance can be tapped. The button is live only in .ready — never while
       ARKit has no reading to give, never during the hold countdown, and never
       after a capture has already been committed.
    */
    private func applyCaptureState() {
        let acceptsTap = captureState == .ready
        captureDistanceButton.isEnabled = acceptsTap
        UIView.animate(withDuration: 0.2) {
            self.captureDistanceButton.alpha = acceptsTap ? 1.0 : 0.45
        }

        countdownLabel.isHidden = captureState != .holding

        if let text = statusText() {
            let wasHidden = statusRowStack.isHidden
            statusLabel.text = text
            statusRowStack.isHidden = false
            if wasHidden {
                animateStatusRowEntranceIfNeeded()
            }
        } else {
            statusRowStack.isHidden = true
        }
    }

    /* The status row's copy for the current state, or nil when there's nothing
       worth saying — in .ready with no retry message pending, an enabled
       Capture Distance button speaks for itself.
    */
    private func statusText() -> String? {
        if let retryNotice {
            return retryNotice
        }
        switch captureState {
        case .awaitingFace:
            return "Finding your face…"
        case .ready:
            return nil
        case .holding:
            return "Hold still for"
        case .captured:
            return "Distance captured"
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

    /* Shows the whole seconds left in the hold — "2 s", then "1 s" — updating
       only when the displayed number actually changes.
    */
    private func updateCountdownDisplay(elapsedSeconds: TimeInterval) {
        let remaining = max(0, Int((holdDurationSeconds - elapsedSeconds).rounded(.up)))
        guard remaining != lastDisplayedCountdown else { return }
        lastDisplayedCountdown = remaining

        guard remaining > 0 else { return }

        countdownLabel.text = "\(remaining) s"
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

    /* Puts a short "that didn't work, try again" message in the status row and
       schedules it to clear itself, so a voided hold explains itself without
       leaving the screen stuck on an error.
    */
    private func showRetryNotice(_ notice: String) {
        retryNotice = notice
        retryNoticeTimer?.invalidate()
        retryNoticeTimer = Timer.scheduledTimer(
            withTimeInterval: retryNoticeSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.clearRetryNotice()
        }
        applyCaptureState()
    }

    private func clearRetryNotice() {
        retryNoticeTimer?.invalidate()
        retryNoticeTimer = nil
        guard retryNotice != nil else { return }
        retryNotice = nil
        applyCaptureState()
    }

    // MARK: - Hold & Capture

    /* Starts the hold countdown when the user taps Capture Distance. The
       reading at the moment of the tap becomes the anchor the rest of the hold
       is judged against — that's the distance the user just decided was right.
    */
    @IBAction func captureDistanceTapped(_ sender: Any) {
        // The button is disabled outside .ready, but a tap landing in the same
        // run loop turn as a tracking loss would still get here.
        guard captureState == .ready,
              let sample = EyeDistanceProvider.shared.validSample() else {
            print("⚠️ Cannot start capture: current eye distance is unavailable")
            return
        }

        clearRetryNotice()
        holdStartedAt = Date()
        holdAnchorDistanceCM = sample.distanceCM
        holdReadings = [sample.distanceCM]
        lastRecordedSampleTimestamp = sample.timestamp
        lastDisplayedCountdown = nil
        captureState = .holding
        updateCountdownDisplay(elapsedSeconds: 0)
        announceForVoiceOver("Hold still.", source: "Distance Optimization")
    }

    /* Drives the whole flow off the 10 Hz timer: promotes the screen to .ready
       as soon as ARKit has a usable reading, drops it back when tracking is
       lost, and advances (or voids) an in-progress hold.
    */
    private func refreshCaptureFlow() {
        let sample = EyeDistanceProvider.shared.validSample()

        switch captureState {
        case .awaitingFace:
            if sample != nil {
                captureState = .ready
            }
        case .ready:
            if sample == nil {
                captureState = .awaitingFace
            }
        case .holding:
            guard let sample else {
                voidHold(notice: "Lost your face — try again", spoken: "Lost your face. Please try again.")
                return
            }
            advanceHold(with: sample)
        case .captured:
            // The distance is already committed and the push to acuity
            // selection is underway — nothing left to track.
            break
        }
    }

    /* Checks one sample against the hold: too far from the anchor voids it,
       otherwise the reading is banked and the countdown moves on, finishing the
       capture once the phone has been steady for holdDurationSeconds.
    */
    private func advanceHold(with sample: EyeDistanceSample) {
        guard let startedAt = holdStartedAt, let anchor = holdAnchorDistanceCM else {
            voidHold(notice: "Couldn't capture — try again", spoken: "Could not capture the distance. Please try again.")
            return
        }

        guard abs(sample.distanceCM - anchor) <= holdToleranceCM else {
            voidHold(notice: "Moved too much — try again", spoken: "Moved too much. Please try again.")
            return
        }

        // ARKit normally produces samples faster than this timer polls, but a
        // repeat of the same sample would otherwise be averaged in twice.
        if sample.timestamp != lastRecordedSampleTimestamp {
            lastRecordedSampleTimestamp = sample.timestamp
            holdReadings.append(sample.distanceCM)
        }

        let elapsed = Date().timeIntervalSince(startedAt)
        guard elapsed >= holdDurationSeconds else {
            updateCountdownDisplay(elapsedSeconds: elapsed)
            return
        }

        completeCapture()
    }

    /* Commits the held distance — the mean of every reading taken across the
       steady window — and moves on to acuity selection.
    */
    private func completeCapture() {
        let readings = holdReadings
        guard !readings.isEmpty else {
            voidHold(notice: "Couldn't capture — try again", spoken: "Could not capture the distance. Please try again.")
            return
        }

        let distanceValue = readings.reduce(0, +) / Double(readings.count)
        guard DistanceTracker.shared.saveHoldingDistance(distanceValue) else {
            voidHold(notice: "Couldn't capture — try again", spoken: "Could not capture the distance. Please try again.")
            return
        }

        // Store the target distance
        averageDistanceCM = distanceValue

        // Reset the recent readings with the new target
        DistanceTracker.shared.addReading(distanceValue)

        // Set current distance to match target
        DistanceTracker.shared.currentDistanceCM = distanceValue

        lastCapturedDistance = distanceValue
        clearHold()
        captureState = .captured

        print("🎯 Target Distance Captured: \(String(format: "%.1f", averageDistanceCM)) cm " +
              "(mean of \(readings.count) readings held steady for \(String(format: "%.0f", holdDurationSeconds)) s)")

        performSegue(withIdentifier: Self.acuitySelectionSegueIdentifier, sender: self)
    }

    /* Cancels an in-progress hold without capturing anything, says why, and
       hands the screen back to the user to try again.
    */
    private func voidHold(notice: String, spoken: String) {
        clearHold()
        captureState = EyeDistanceProvider.shared.validSample() == nil ? .awaitingFace : .ready
        showRetryNotice(notice)
        announceForVoiceOver(spoken, source: "Distance Optimization")
    }

    /* Drops all hold bookkeeping so nothing from an abandoned attempt can leak
       into the next one.
    */
    private func clearHold() {
        holdStartedAt = nil
        holdAnchorDistanceCM = nil
        holdReadings.removeAll()
        lastRecordedSampleTimestamp = nil
        lastDisplayedCountdown = nil
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
