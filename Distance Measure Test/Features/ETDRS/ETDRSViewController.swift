//
//  ETDRSViewController.swift
//  Distance Measure Test
//
//  Created by Visual Acuity Test Assistant
//
//  NOTE: This file is not used in the "Landolt-C Only" version of the app.
//  The app has been modified to only use the Landolt C test (TumblingEViewController).
//  This file is kept for reference and potential future use.

import UIKit
import AVFoundation

/* ETDRSViewController class implements a visual acuity test using ETDRS letters.
   The test displays ETDRS letters at various sizes, and the user must speak the
   letter they see. The test maintains a fixed testing distance using AR face tracking.
 */
class ETDRSViewController: UIViewController {
    // MARK: - Properties

    private var isPaused = false
    // Set only by the user tapping the Pause/Resume button — kept separate from
    // `isPaused` (the automatic distance-based pause) so the two can't override
    // each other, e.g. the distance coming back in range must not silently
    // resume a test the user deliberately paused.
    private var isManuallyPaused = false
    private lazy var pauseBarButtonItem = UIBarButtonItem(
        title: "Pause",
        style: .plain,
        target: self,
        action: #selector(pauseButtonTapped)
    )
    private var lowerBound: Double = 0.0
    private var upperBound: Double = 0.0
    
    /// List of acuity levels to test in 20/x format (from largest to smallest)
    let acuityList = [200, 160, 125, 100, 80, 63, 50, 40, 32, 20, 16]

    private let etdrsProtocol = ETDRSProtocolConfiguration.fiveLetterV1
    private var progressionEngine: ETDRSProgressionEngine!

    /// Current index in the acuity list, owned by the progression engine.
    var currentAcuityIndex: Int {
        progressionEngine.currentAcuityIndex
    }
    
    /// The no-input window: how long the microphone listens, timed from the moment it is actually
    /// armed — after the inter-letter gap and after any spoken instruction — before the trial
    /// resolves without a letter. Same value as Myotect's `recognitionTimeoutSeconds`.
    private static let noInputWindowSeconds: TimeInterval = 5
    /// Filler / unintelligible speech inside the window is engagement, not a miss: the same letter
    /// is retried this many times (the first retry with a spoken "Try again.", later ones silent)
    /// before the no-input miss is scored. Myotect's `maxAutoRetriesPerTrial`.
    private static let maxUnclearRetriesPerLetter = 2
    /// Backstop for a participant (or microphone) that stays silent: after this many consecutive
    /// no-input letters the test pauses itself until Resume. The silent letters still score as
    /// misses; without the backstop a silent participant would auto-fail every level with no
    /// signal to whoever is running the test. Myotect's `noInputTrialsBeforeEscalation`.
    private static let noInputTrialsBeforeAutoPause = 3
    /// On-screen answer instruction. Audio instructions are off by default, so this label is the
    /// one channel that reliably tells the participant that saying "skip" is allowed.
    private static let answerInstruction = "Say the letter you see out loud. If you cannot see it, say \"skip\"."
    /// Shown for the rest of the letter after an unclear answer. The transcription pill is hidden
    /// by stopListening and rewritten by every re-arm, so this label is the cue that survives.
    private static let retryInstruction = "Try again. Say the letter you see, or say \"skip\"."
    /// How many times the deadline may find the audio still `.pending` (a live inference holding
    /// it) before the window is treated as silent anyway.
    private static let maxDeadlineFlushAttempts = 3
    /// Fires when the no-input window elapses (`startNoInputTimer`).
    private var noInputTimer: Timer?
    
    /// Conversion table from US foot notation (20/x) to LogMAR values
    let usFootToLogMAR: [Int: Double] = [
        10: -0.3,
        12: -0.2,
        16: -0.1,
        20: 0.0,   // 20/20 vision = LogMAR 0.0 (normal vision)
        25: 0.1,
        32: 0.2,
        40: 0.3,
        50: 0.4,
        63: 0.5,
        80: 0.6,
        100: 0.7,
        125: 0.8,
        160: 0.9,
        200: 1.0,  // 20/200 vision = LogMAR 1.0 (legally blind in many jurisdictions)
        250: 1.1,
        320: 1.2,
        400: 1.3,
        500: 1.4,
        630: 1.5,
        800: 1.6,
        1000: 1.7,
        1260: 1.8,
        1600: 1.9,
        2000: 2.0
    ]
    
    /// Standard ETDRS letters
    let etdrsLetters = ["C", "D", "F", "H", "K", "N", "P", "R", "X", "J", "Z"]
    
    /// Current letter being displayed
    private var currentLetter: String = ""
    
    // MARK: - Speech Recognition Properties
    
    /// WhisperKit service for spoken ETDRS letter input
    private let whisperLetterService = ETDRSWhisperLetterService.shared
    
    /// Flag to indicate if speech recognition is active
    private var isListening = false
    /// Bumped by every start/stop of listening. A prediction, timer, or flush callback captured
    /// under an older value belongs to a dead listening session and must no-op — a late score
    /// would trip the progression engine's one-response-per-trial preconditions.
    private var listeningGeneration = 0
    /// Filler or unmapped speech heard since the microphone armed for the current window: the
    /// participant is engaged, so the deadline retries instead of scoring "no input".
    private var heardSpeechThisWindow = false
    /// Same-letter retries already spent on unclear speech; reset with every new letter.
    private var unclearRetriesThisLetter = 0
    /// Deadline flushes that came back `.pending` for the current window; bounded so a stuck
    /// inference cannot postpone the decision forever.
    private var deadlineFlushAttempts = 0
    /// True while the "End test?" confirmation is presented: nothing may arm the microphone behind
    /// it, whichever deferred path asks (gap completion, silent retry, distance recovery, app
    /// foregrounding). Cancel clears it and re-arms.
    private var isConfirmingEndTest = false
    /// Consecutive failed microphone starts. A transient audio-session or engine error is retried
    /// (1 s apart) up to `maxConsecutiveStartFailures` times; after that — or at once for a denied
    /// permission — the test parks on the manual-pause path so Resume is the visible way back,
    /// rather than stranding the letter with no listener, no timer and no pause indicator.
    private var consecutiveStartFailures = 0
    private static let maxConsecutiveStartFailures = 3
    /// Consecutive scored letters that ended as "no input registered"; any letter or skip resets it.
    private var consecutiveNoInputTrials = 0
    private var shouldResumeListeningAfterSpeech = false
    private var resumeListeningWorkItem: DispatchWorkItem?
    private var listeningStatusWorkItem: DispatchWorkItem?
    private var letterTransitionWorkItem: DispatchWorkItem?

    // True from the moment a response is scored until the next optotype is on
    // screen. The distance display link and the renderer both write
    // letterLabel.alpha, so without this they would uncover the letter the
    // participant just answered during the transition gap.
    private var isBetweenLetters = false
    private var pendingRecognizedLetter: String?
    private var pendingRecognizedLetterCount = 0
    private var pendingRecognizedLetterTimestamp: Date?
    private let showWhisperDebugLabel = true
    
    // MARK: - UI Elements
    
    // Label displaying the ETDRS letter for the vision test
    private lazy var letterLabel: UILabel = {
        let label = UILabel()
        label.text = "C"
        label.font = UIFont(name: "Sloan", size: 50) // Temporary size, will be set by set_Size_E()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Opaque square drawn over the optotype between trials. Masking with a
    // sibling view rather than recolouring letterLabel matters: the 10 fps
    // distance display link writes letterLabel.alpha on its own schedule, and an
    // opaque cover hides the answered letter no matter what alpha it lands on.
    private lazy var letterMaskView: UIView = {
        let maskView = UIView()
        maskView.backgroundColor = AppThemeColors.black
        maskView.isHidden = true
        maskView.isUserInteractionEnabled = false
        return maskView
    }()

    // Label indicating which eye is being tested
    private lazy var eyeTestLabel: UILabel = {
        let label = UILabel()
        label.drawHeader2()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Label displaying instructions to the user
    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = Self.answerInstruction
        label.drawInstruction()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var distanceGuidanceView = DistanceGuidanceView()
    
    // Label showing microphone status
    private lazy var microphoneLabel: UILabel = {
        let label = PaddedStatusLabel()
        label.text = "VOICE INPUT ACTIVE"
        label.font = UIFont.systemFont(ofSize: 14, weight: .black)
        label.textColor = TextPalette.teal
        label.applyStatusPillStyle(
            backgroundColor: TextPalette.mist,
            borderColor: TextPalette.teal.withAlphaComponent(0.20),
            textInsets: UIEdgeInsets(top: 9, left: 16, bottom: 9, right: 16),
            cornerRadius: 14,
            textColor: TextPalette.teal
        )
        return label
    }()

    private lazy var transcriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Waiting for a spoken letter"
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 2
        return label
    }()

    private lazy var whisperDebugLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = AppThemeColors.systemGrey
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 2
        label.isHidden = !showWhisperDebugLabel
        return label
    }()
    
    // MARK: - Test Properties
    
    // Number of correct answers
    private var score = 0
    
    // Total number of test attempts
    private var totalAttempts = 0
    
    // Last distance used for letter scaling to prevent unnecessary updates
    private var currentRenderSpec: OptotypeRenderSpec?
    private var currentSizingProvenance: SizingProvenance?
    
    // Last audio instruction played to avoid repetition
    private var lastAudioInstruction: String = ""
    
    // Timer for audio instruction repetition
    private var audioInstructionTimer: Timer?
    
    // Display link for smooth distance monitoring
    private var displayLink: CADisplayLink?
    
    // MARK: - Data Collection Properties
    
    /// Time when the current letter was displayed
    private var letterDisplayTime: Date?
    
    /// Data collector for test progression tracking
    private let dataCollector = TestProgressionDataCollector.shared

    private func resetPendingRecognition() {
        pendingRecognizedLetter = nil
        pendingRecognizedLetterCount = 0
        pendingRecognizedLetterTimestamp = nil
    }
    
    // MARK: - Lifecycle Methods
    
    /* Initializes the view and sets up the test environment.
       This method sets up the UI elements, initializes speech recognition,
       initializes the current acuity level from the selected value, sets up distance tracking
       and boundaries, initializes AR face tracking for distance monitoring, and sizes the
       test letter appropriately for the current acuity level.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        print("🔍 ETDRSViewController - viewDidLoad started")

        // Replace the default Back button with an explicit confirmed exit action
        // so the test cannot be abandoned accidentally mid-trial.
        navigationItem.hidesBackButton = true
        navigationItem.setHidesBackButton(true, animated: false)

        // Set up the basic UI
        view.backgroundColor = .white
        setupUI()
        setupEndTestButton()
        setupPauseButton()
        print("🔍 ETDRSViewController - UI setup completed")

        // Initialize acuity level from the selected value
        initializeAcuityLevel()
        print("🔍 ETDRSViewController - acuity level initialized")
        
        // Set up distance tracking and monitoring
        initializeDistanceTracking()
        print("🔍 ETDRSViewController - distance tracking initialized")
        
        // Set up speech recognition
        setupSpeechRecognition()
        // A microphone that dies mid-window and cannot be restarted ends the window here (retry,
        // then park) instead of running out as a scored "no input registered".
        whisperLetterService.onMicrophoneLost = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.handleMicrophoneLost(error)
            }
        }
        print("🔍 ETDRSViewController - speech recognition setup completed")
        
        // Start monitoring distance with appropriate checks
        startDistanceMonitoring()
        print("🔍 ETDRSViewController - distance monitoring started")

        // Finish layout and generate the first letter
        view.layoutIfNeeded()
        generateNewLetter()
        print("🔍 ETDRSViewController - first letter generated: \(currentLetter)")
        
        letterLabel.alpha = 0
        
        // Update eye test label based on current eye number
        updateEyeTestLabel()
        
        // Initialize data collection session
        let eyeName = VisualAcuitySession.eyeName(for: VisualAcuitySession.currentEyeNumber)
        dataCollector.startNewSession(eye: eyeName, testType: "ETDRS")
        print("🔍 ETDRSViewController - viewDidLoad completed successfully")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        EyeDistanceProvider.shared.start(
            eyeNumber: VisualAcuitySession.currentEyeNumber,
            client: self
        )

        // Prevent the edge-swipe back gesture from interrupting the ETDRS test.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSharedAudioDidStart),
            name: SharedAudioManager.speechDidStartNotification,
            object: SharedAudioManager.shared
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSharedAudioDidFinish),
            name: SharedAudioManager.speechDidFinishNotification,
            object: SharedAudioManager.shared
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        requireCalibrationIfNeeded()
        
        print("🔍 ETDRSViewController - viewDidAppear started")
        
        // Play audio instructions for the ETDRS test screen
        playAudioInstructions()
        print("🔍 ETDRSViewController - audio instructions played")
        
        // Start speech recognition after any spoken instruction finishes.
        requestListeningAfterSpeechIfNeeded()
        print("🔍 ETDRSViewController - viewDidAppear completed")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Restore the standard edge-swipe behavior for non-test screens.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        
        // Clean up timers and display link
        audioInstructionTimer?.invalidate()
        audioInstructionTimer = nil
        displayLink?.invalidate()
        displayLink = nil
        cancelInterLetterGap()
        
        // Stop speech recognition and timeout timer. The service is stopped unconditionally as
        // well: a start still arming when the screen goes away must not leave the microphone hot.
        stopListening()
        whisperLetterService.stopListening()
        whisperLetterService.onMicrophoneLost = nil
        stopNoInputTimer()
        shouldResumeListeningAfterSpeech = false
        resumeListeningWorkItem?.cancel()
        resumeListeningWorkItem = nil
        listeningStatusWorkItem?.cancel()
        listeningStatusWorkItem = nil
        NotificationCenter.default.removeObserver(self)

        EyeDistanceProvider.shared.stop(client: self)
    }

    /*
     * Installs an explicit "End Test" button on the navigation bar's trailing
     * edge so the user can intentionally leave the test after confirming.
     */
    private func setupEndTestButton() {
        navigationItem.rightBarButtonItem = makeEndTestBarButton(action: #selector(endTestTapped))
    }

    @objc private func endTestTapped() {
        // Not during the 0.45 s inter-letter gap: its completion advances (or finishes) the test
        // and would do so behind the confirmation.
        guard !isBetweenLetters else { return }
        // The no-input window must not run behind the confirmation: a participant who is being
        // asked whether to stop is not failing to answer the letter. Stop cleanly; Cancel re-arms.
        stopListening()
        resumeListeningWorkItem?.cancel()
        resumeListeningWorkItem = nil
        shouldResumeListeningAfterSpeech = false
        isConfirmingEndTest = true

        let alert = UIAlertController(
            title: "End test?",
            message: "Your progress on this set will be lost.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            guard let self else { return }
            self.isConfirmingEndTest = false
            self.startListening()
        })
        alert.addAction(UIAlertAction(title: "End Test", style: .destructive) { [weak self] _ in
            self?.isConfirmingEndTest = false
            // Wait for "Test ended." to actually finish speaking before
            // popping — otherwise the previous screen's own instructions
            // (played from its viewDidAppear) cut this off mid-sentence.
            self?.announceForVoiceOver("Test ended.", source: "End Test") {
                self?.navigationController?.popViewController(animated: true)
            }
        })
        present(alert, animated: true)
    }

    /*
     * Installs a Pause/Resume button on the navigation bar's leading edge so
     * the user can manually halt speech recognition and test progression.
     */
    private func setupPauseButton() {
        navigationItem.leftBarButtonItem = pauseBarButtonItem
    }

    @objc private func pauseButtonTapped() {
        isManuallyPaused.toggle()
        if isManuallyPaused {
            applyManualPause()
        } else {
            applyManualResume()
        }
    }

    /* Manually pauses the test: stops listening immediately and prevents any
       in-flight or scheduled work from restarting it until resumed.
    */
    private func applyManualPause(instruction: String = "Paused", announcement: String = "Test paused.") {
        pauseBarButtonItem.title = "Resume"
        stopListening()
        resumeListeningWorkItem?.cancel()
        resumeListeningWorkItem = nil
        listeningStatusWorkItem?.cancel()
        listeningStatusWorkItem = nil
        shouldResumeListeningAfterSpeech = false
        instructionLabel.text = instruction
        transcriptionLabel.isHidden = true
        announceForVoiceOver(announcement)
    }

    /* The no-input backstop: after `noInputTrialsBeforeAutoPause` consecutive letters ended by the
       no-input window, the test parks itself on the manual-pause path. The next letter is already
       on screen; startListening()'s isManuallyPaused guard keeps the microphone off until whoever
       is present taps Resume. Mirrors Myotect's hand-off to the clinician keypad — this app has
       neither a keypad nor an operator strip, so the pause is the signal.
     */
    private func autoPauseForNoResponse() {
        isManuallyPaused = true
        applyManualPause(
            instruction: "Paused: no response detected",
            announcement: "No response detected. Test paused. Tap Resume to continue."
        )
    }

    /* Manually resumes the test. If the user is still out of the acceptable
       distance range, listening stays off until distance-based auto-resume
       (checkDistance) brings it back — it will now be free to run again
       since isManuallyPaused is false.
    */
    private func applyManualResume() {
        pauseBarButtonItem.title = "Pause"
        if isPaused {
            instructionLabel.text = "Paused: Adjust your distance"
            announceForVoiceOver("Still out of range. Test will resume automatically once you're back in range.")
        } else {
            instructionLabel.text = Self.answerInstruction
            startListening()
            announceForVoiceOver("Test resumed.")
        }
    }

    /*
    * Updates the eye test label based on the current eye number.
    */
    private func updateEyeTestLabel() {
        let eyeName = VisualAcuitySession.eyeName(for: VisualAcuitySession.currentEyeNumber)
        eyeTestLabel.applyEyeTestTitle(eyeName: eyeName, testName: "ETDRS")
    }

    /*
     * Initializes the acuity level based on the user's selection.
     * If no selection was made or the selection is invalid, defaults to the largest letter size.
     */
    private func initializeAcuityLevel() {
        // Debug: Print selected acuity at start
        print("Initial selectedAcuity value: \(String(describing: VisualAcuitySession.selectedAcuity))")

        let startingAcuityIndex: Int
        if let selectedAcuity = VisualAcuitySession.selectedAcuity {
            // Find the index of the selected acuity in our acuity list
            let selectedIndex = getIndex(numList: acuityList, value: selectedAcuity)
            print("The index of \(selectedAcuity) is \(selectedIndex).")
            
            // If the acuity wasn't found in our list, default to the largest size
            if selectedIndex == -1 {
                print("Selected acuity not found in acuity list, defaulting to first entry")
                startingAcuityIndex = 0
            } else {
                startingAcuityIndex = selectedIndex
            }
        } else {
            print("Selected acuity is nil, defaulting to largest size")
            startingAcuityIndex = 0
        }

        do {
            progressionEngine = try ETDRSProgressionEngine(
                configuration: etdrsProtocol,
                acuityLevels: acuityList,
                startingAcuityIndex: startingAcuityIndex,
                baseLogMARByAcuity: usFootToLogMAR
            )
        } catch {
            preconditionFailure("Unable to initialize ETDRS progression: \(error)")
        }
    }
    
    /*
     * Initializes distance tracking parameters including
     * retrieving saved distances and setting acceptable bounds.
     */
    private func initializeDistanceTracking() {
        averageDistanceCM = DistanceTracker.shared.preferredHoldingDistanceCM ?? 0
        print("📏 ETDRS Target test distance: \(averageDistanceCM) cm")
        
        if averageDistanceCM > 0 {
            lowerBound = max(EyeDistanceSample.acceptedRangeCM.lowerBound, 0.8 * averageDistanceCM)
            upperBound = min(EyeDistanceSample.acceptedRangeCM.upperBound, 1.2 * averageDistanceCM)
        } else {
            lowerBound = EyeDistanceSample.acceptedRangeCM.lowerBound
            upperBound = EyeDistanceSample.acceptedRangeCM.upperBound
        }
        print("📏 ETDRS Distance bounds set to: \(String(format: "%.1f", lowerBound)) - \(String(format: "%.1f", upperBound)) cm")
    }
    
    /*
     * Initiates distance monitoring with CADisplayLink for better performance.
     * Can be configured to bypass distance checking for testing purposes.
     */
    private func startDistanceMonitoring() {
        // Add a debug option to skip distance checking for testing
        #if DEBUG
        let debugBypassDistanceCheck = ProcessInfo.processInfo.environment["ETDRS_BYPASS_DISTANCE_CHECK"] == "1"
        
        // Extra debugging for distance
        let debugExtraLogging = true // Set to true for more verbose distance logs
        
        if debugBypassDistanceCheck {
            print("🔧 DEBUG MODE: Distance checking disabled")
            isPaused = false
            distanceGuidanceView.hideAll()
            return
        }
        
        if debugExtraLogging {
            print("🔧 DEBUG MODE: Enhanced distance logging enabled")
        }
        #endif
        
        // Use CADisplayLink for smoother, more efficient updates
        displayLink = CADisplayLink(target: self, selector: #selector(updateLiveDistance))
        displayLink?.preferredFramesPerSecond = 10 // Limit to 10fps for efficiency
        displayLink?.add(to: .main, forMode: .default)
        
        print("🎯 Distance monitoring started with CADisplayLink at 10fps")
    }

    /*
     * Sets up the UI elements and their constraints.
     */
    private func setupUI() {
        view.backgroundColor = .white
        
        // Add subviews
        view.addSubview(letterLabel)
        view.addSubview(letterMaskView)
        view.addSubview(eyeTestLabel)
        view.addSubview(instructionLabel)
        view.addSubview(distanceGuidanceView)
        view.addSubview(microphoneLabel)
        view.addSubview(transcriptionLabel)
        view.addSubview(whisperDebugLabel)
        whisperDebugLabel.isHidden = !showWhisperDebugLabel

        distanceGuidanceView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Eye test label constraints
            eyeTestLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            eyeTestLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            eyeTestLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Distance guidance view constraints
            distanceGuidanceView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            distanceGuidanceView.topAnchor.constraint(equalTo: eyeTestLabel.bottomAnchor, constant: 30),
            distanceGuidanceView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            distanceGuidanceView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // Letter label constraints
            letterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Microphone label constraints
            microphoneLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            microphoneLabel.topAnchor.constraint(equalTo: letterLabel.bottomAnchor, constant: 30),

            // Transcription label constraints
            transcriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            transcriptionLabel.topAnchor.constraint(equalTo: microphoneLabel.bottomAnchor, constant: 10),
            transcriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            transcriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            whisperDebugLabel.topAnchor.constraint(equalTo: transcriptionLabel.bottomAnchor, constant: 8),
            whisperDebugLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            whisperDebugLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // Instruction label constraints
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        print("ETDRSViewController - constraints activated")
    }
    
    // MARK: - Speech Recognition Setup
    
    /*
     * Sets up speech recognition for voice input.
     */
    private func setupSpeechRecognition() {
        print("[ETDRSWhisper] Setting up WhisperKit speech recognition...")

        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.whisperLetterService.prepareIfNeeded()
                print("[ETDRSWhisper] WhisperKit setup completed ✅")
            } catch {
                print("[ETDRSWhisper] WhisperKit setup failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.showSpeechPermissionAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    /*
     * Shows an alert when speech recognition permission is not available.
     */
    private func showSpeechPermissionAlert(message: String? = nil) {
        let alert = UIAlertController(
            title: "Microphone Required",
            message: message ?? "This ETDRS test requires microphone access for WhisperKit spoken-letter recognition. Please enable microphone access in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    
    /*
     * Starts listening for speech input.
     */
    private func startListening() {
        guard view.window != nil else { return }
        guard !isPaused, !isManuallyPaused else { return }
        // The single gate for every deferred re-arm path: nothing arms while the End Test
        // confirmation is up (Cancel re-arms) or during the inter-letter gap (processNextTrial
        // re-arms once the next letter is drawn).
        guard !isConfirmingEndTest, !isBetweenLetters else { return }
        guard !SharedAudioManager.shared.isSpeaking else {
            shouldResumeListeningAfterSpeech = true
            microphoneLabel.isHidden = true
            transcriptionLabel.isHidden = true
            transcriptionLabel.text = "Waiting for spoken instructions to finish"
            return
        }
        guard !isListening else { 
            print("🎤 Already listening, skipping start")
            return 
        }

        shouldResumeListeningAfterSpeech = false
        isListening = true
        listeningGeneration += 1
        let generation = listeningGeneration
        // Reserve the service session NOW, on the main thread, so a stopListening() that follows
        // before the async start body runs out-ranks it and the start never arms.
        let sessionToken = whisperLetterService.reserveStart()
        resetPendingRecognition()
        transcriptionLabel.text = "Listening for one spoken letter"
        if showWhisperDebugLabel {
            whisperDebugLabel.text = "Raw: —    →    Mapped: —"
        }
        print("[ETDRSWhisper] Starting WhisperKit listening for ETDRS letters...")
        revealListeningStatusAfterLetterDelay()

        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.whisperLetterService.startListening(token: sessionToken) { [weak self] prediction in
                    Task { @MainActor [weak self] in
                        // A prediction from a superseded listening session must not score.
                        guard let self, self.listeningGeneration == generation else { return }
                        self.handleWhisperPrediction(prediction)
                    }
                }
                print("[ETDRSWhisper] Started listening for spoken ETDRS letters")
                await MainActor.run {
                    // The microphone is live from here: the no-input window runs from THIS moment,
                    // not from the letter's appearance — permission, model readiness and engine
                    // start-up never eat into it, and neither does a spoken instruction.
                    guard self.listeningGeneration == generation, self.isListening else {
                        // Superseded while arming. A newer session (isListening) tears the engine
                        // down itself; with no session alive nothing else would, so stop it here.
                        if !self.isListening { self.whisperLetterService.stopListening() }
                        return
                    }
                    self.consecutiveStartFailures = 0
                    self.heardSpeechThisWindow = false
                    self.deadlineFlushAttempts = 0
                    self.startNoInputTimer(generation: generation)
                }
            } catch {
                print("[ETDRSWhisper] Failed to start listening: \(error.localizedDescription)")
                await MainActor.run {
                    guard self.listeningGeneration == generation else { return }
                    self.isListening = false
                    self.microphoneLabel.isHidden = true
                    self.transcriptionLabel.isHidden = true
                    self.stopNoInputTimer()
                    self.handleStartFailure(error)
                }
            }
        }
    }

    /* A microphone start failed. Permission denial is final: park and explain. Anything else
       (an audio-session or engine error while the route was changing) is retried a bounded number
       of times before the test parks — the letter must never sit on screen with no listener, no
       timer and no pause indicator.
     */
    private func handleStartFailure(_ error: Error) {
        consecutiveStartFailures += 1
        let permissionDenied = (error as? ETDRSWhisperLetterServiceError) == .microphonePermissionDenied

        if !permissionDenied, consecutiveStartFailures < Self.maxConsecutiveStartFailures {
            print("[ETDRSWhisper] Retrying microphone start (\(consecutiveStartFailures)/\(Self.maxConsecutiveStartFailures))")
            resumeListeningWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, !self.isListening else { return }
                self.startListening()
            }
            resumeListeningWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
            return
        }

        consecutiveStartFailures = 0
        isManuallyPaused = true
        applyManualPause(
            instruction: "Paused: microphone unavailable",
            announcement: "Microphone unavailable. Test paused."
        )
        showSpeechPermissionAlert(message: error.localizedDescription)
    }

    private func handleMicrophoneLost(_ error: Error) {
        guard isListening else { return }
        print("[ETDRSWhisper] Microphone lost mid-window: \(error.localizedDescription)")
        stopListening()
        handleStartFailure(error)
    }

    private func handleWhisperPrediction(_ prediction: ETDRSWhisperPrediction) {
        // isBetweenLetters: the answered letter is masked and the next is not up yet, so a late
        // transcript has nothing to score (TumblingE guards handleSwipe the same way).
        guard isListening, !isPaused, !isManuallyPaused, !isBetweenLetters else { return }
        guard !prediction.rawTranscription.isEmpty else { return }

        print("[ETDRSWhisper] Heard: '\(prediction.rawTranscription)' normalized: \(prediction.normalizedLetter ?? "<none>") latency: \(String(format: "%.2f", prediction.latency))s")
        transcriptionLabel.text = "Heard: \"\(prediction.rawTranscription)\""
        if showWhisperDebugLabel {
            let mappedText = prediction.normalizedLetter ?? "—"
            let matchesCurrent = mappedText == currentLetter ? "yes" : "no"
            whisperDebugLabel.text = "Raw: \(prediction.rawTranscription)    →    Mapped: \(mappedText)    | Match: \(matchesCurrent)"
        }

        if prediction.isIgnorableNonAnswer {
            // Whisper's silence hallucinations ("BLANK AUDIO", "SILENCE"): not engagement.
            print("[ETDRSWhisper] Ignoring non-answer: '\(prediction.rawTranscription)'")
            transcriptionLabel.text = "Listening for one spoken letter"
            return
        }

        if prediction.isPartial {
            // Streaming partials are display only — never scored and never engagement. The first
            // tokens of "okay skip" are "Okay" (a K correction) and of "Thank you." are "Thank";
            // only the completed pass, which always follows in the same inference, sees the whole
            // utterance and can apply the mixed-utterance and hallucination rules.
            if let letter = prediction.normalizedLetter {
                transcriptionLabel.text = "Picked up: \(letter)"
            }
            return
        }

        if prediction.isSkip {
            // "Skip" is an answer: the participant cannot see the letter. Scored as a miss, never
            // retried, and the test moves on — exactly like a wrong letter.
            print("[ETDRSWhisper] Spoken skip for target: \(currentLetter)")
            if showWhisperDebugLabel {
                whisperDebugLabel.text = "Raw: \(prediction.rawTranscription)    →    Mapped: skip    | Match: no"
            }
            stopListening(keepMicrophoneWarm: true)
            scoreResponse(ETDRSNonLetterResponse.skipped)
            return
        }

        if prediction.isFiller {
            print("[ETDRSWhisper] Ignoring filler: '\(prediction.rawTranscription)'")
            heardSpeechThisWindow = true
            transcriptionLabel.text = "Listening for one spoken letter"
            return
        }

        guard let letter = prediction.normalizedLetter else {
            print("[ETDRSWhisper] Ignoring unclear transcription: '\(prediction.rawTranscription)'")
            heardSpeechThisWindow = true
            if prediction.isFinal {
                transcriptionLabel.text = "Could not confirm a letter"
            }
            if showWhisperDebugLabel {
                whisperDebugLabel.text = "Raw: \(prediction.rawTranscription)    →    Mapped: —    | Match: no"
            }
            return
        }

        if !prediction.isFinal {
            pendingRecognizedLetter = letter
            pendingRecognizedLetterCount = 1
            pendingRecognizedLetterTimestamp = Date()
            transcriptionLabel.text = "Picked up: \(letter)"
        }

        resetPendingRecognition()
        let isCorrect = letter == currentLetter
        transcriptionLabel.text = "Picked up: \(letter) · \(isCorrect ? "correct" : "incorrect")"
        print("[ETDRSWhisper] Processing recognized ETDRS letter: \(letter) for target: \(currentLetter)")
        stopListening(keepMicrophoneWarm: true)
        scoreResponse(letter)
    }
    
    /*
     * Stops listening for speech input.
     */
    /* Ends the current listening session. `keepMicrophoneWarm` leaves the audio engine running
       so the next letter's session arms instantly — used only on the scoring paths, where the
       next window opens within a second. Every other stop (pause, the app's own speech, End
       Test, backgrounding, leaving the screen) releases the microphone, including a warm one.
     */
    private func stopListening(keepMicrophoneWarm: Bool = false) {
        guard isListening else {
            if !keepMicrophoneWarm, whisperLetterService.isMicrophoneWarm {
                whisperLetterService.stopListening()
            }
            return
        }
        
        print("[ETDRSWhisper] Stopping WhisperKit listening...")
        if keepMicrophoneWarm {
            whisperLetterService.suspendListening()
        } else {
            whisperLetterService.stopListening()
        }
        isListening = false
        // Anything still in flight for this session (a prediction, the no-input timer, a final
        // flush) now belongs to a dead generation and no-ops.
        listeningGeneration += 1
        resetPendingRecognition()
        microphoneLabel.isHidden = true
        transcriptionLabel.isHidden = true
        listeningStatusWorkItem?.cancel()
        listeningStatusWorkItem = nil
        
        // Stop the timeout timer
        stopNoInputTimer()
        
        print("[ETDRSWhisper] Stopped listening for speech input")
    }

    private func requestListeningAfterSpeechIfNeeded() {
        resumeListeningWorkItem?.cancel()
        shouldResumeListeningAfterSpeech = true
        startListening()
    }

    private func revealListeningStatusAfterLetterDelay() {
        listeningStatusWorkItem?.cancel()

        microphoneLabel.isHidden = true
        transcriptionLabel.isHidden = true
        transcriptionLabel.alpha = 0
        if showWhisperDebugLabel {
            whisperDebugLabel.alpha = 1
            whisperDebugLabel.isHidden = false
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isListening, !self.isPaused else { return }
            self.microphoneLabel.isHidden = false
            self.transcriptionLabel.isHidden = false
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: {
                self.transcriptionLabel.alpha = 1
            })
        }
        listeningStatusWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    @objc private func handleSharedAudioDidStart() {
        guard view.window != nil else { return }
        resumeListeningWorkItem?.cancel()
        resumeListeningWorkItem = nil
        listeningStatusWorkItem?.cancel()
        listeningStatusWorkItem = nil

        if isListening {
            stopListening()
            shouldResumeListeningAfterSpeech = !isPaused
        } else {
            // Releases a microphone left warm between letters: the speech that is starting
            // switches the audio session to playback, which a running input engine cannot survive.
            stopListening()
            if !isPaused {
                shouldResumeListeningAfterSpeech = true
            }
        }

        if shouldResumeListeningAfterSpeech {
            transcriptionLabel.text = "Waiting for spoken instructions to finish"
        }
    }

    @objc private func handleSharedAudioDidFinish() {
        guard view.window != nil else { return }
        guard shouldResumeListeningAfterSpeech, !isPaused else { return }
        
        resumeListeningWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.shouldResumeListeningAfterSpeech, !self.isPaused else { return }
            self.startListening()
        }
        resumeListeningWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    /* Backgrounding mid-window: a Timer whose fire date passes while the app is suspended fires
       the instant it returns, which would score a no-input miss the participant never had a
       chance at. Stop cleanly here; didBecomeActive opens a fresh window on the same letter.
     */
    @objc private func handleAppWillResignActive() {
        guard view.window != nil else { return }
        stopListening()
        resumeListeningWorkItem?.cancel()
        resumeListeningWorkItem = nil
        shouldResumeListeningAfterSpeech = false
    }

    @objc private func handleAppDidBecomeActive() {
        guard view.window != nil, !isPaused, !isManuallyPaused, !isBetweenLetters else { return }
        startListening()
    }
    
    // MARK: - Response Scoring
    /*
     * The single scored path for every way a trial resolves: a recognized letter, a spoken
     * "skip", or the no-input window elapsing. `response` is the uppercase letter or one of the
     * ETDRSNonLetterResponse sentinels, which are lowercase and so score incorrect by construction.
     *
     * The distance / calibration guard is deliberately shared: a response that cannot be sized
     * truthfully is dropped and the test pauses — for a sentinel exactly as for a letter — and a
     * fresh window opens on resume.
     */
    private func scoreResponse(_ response: String) {
        guard !isPaused, !isManuallyPaused else { return }
        guard let responseDistance = EyeDistanceProvider.shared.validSample()?.distanceCM,
              let calibration = ScreenCalibrationProvider.shared.currentCalibration,
              let sizingProvenance = currentSizingProvenance,
              sizingProvenance.matches(calibration) else {
            pauseForInvalidDistance()
            return
        }

        let inputLetter = response
        let isCorrect = inputLetter == currentLetter
        if isCorrect {
            score += 1
        }
        consecutiveNoInputTrials = response == ETDRSNonLetterResponse.noInput
            ? consecutiveNoInputTrials + 1
            : 0

        totalAttempts += 1
        let trialNumber = progressionEngine.nextTrialNumber
        
        // Calculate response time
        let responseTime: Int64
        if let displayTime = letterDisplayTime {
            responseTime = Int64(Date().timeIntervalSince(displayTime) * 1000) // Convert to milliseconds
        } else {
            responseTime = 0 // Fallback if timing wasn't recorded
        }
        
        // Record the response data
        let eyeName = VisualAcuitySession.eyeName(for: VisualAcuitySession.currentEyeNumber)
        let acuityString = "20/\(acuityList[currentAcuityIndex])"
        
        dataCollector.recordResponse(
            eye: eyeName,
            testType: "ETDRS",
            acuityLevel: acuityString,
            letterDisplayed: currentLetter,
            distanceCM: responseDistance,
            responseTimeMS: responseTime,
            userResponse: inputLetter,
            isCorrect: isCorrect,
            trialNumber: trialNumber,
            sizingProvenance: sizingProvenance,
            protocolMetadata: etdrsProtocol.metadata
        )
        
        print("🎯 Letter: \(currentLetter), Input: \(inputLetter), Correct: \(isCorrect), Time: \(responseTime)ms")
        
        // Blank the optotype's square before processing the next trial
        presentInterLetterGap { [weak self] in
            self?.processNextTrial(isCorrect: isCorrect)
        }
    }
    
    /* Processes the current trial state and determines the next steps in the test.
       This method is called after each user response and handles tracking correct answers,
       determining acuity level changes, calculating final scores, and resetting trial counters.
     */
    private func processNextTrial(isCorrect: Bool) {
        let completedAcuity = progressionEngine.currentAcuity
        let outcome = progressionEngine.recordResponse(isCorrect: isCorrect)
        print(
            "🔍 ETDRS progression:",
            "acuity:", completedAcuity,
            "attempts:", progressionEngine.attemptsInCurrentAcuity,
            "correct:", progressionEngine.resultsByAcuity[
                completedAcuity
            ]?.progressionCorrect ?? progressionEngine.correctInCurrentAcuity,
            "outcome:", String(describing: outcome)
        )

        switch outcome {
        case .continueCurrentAcuity:
            generateNewLetter()

        case let .changeAcuity(acuity):
            print("🔍 ETDRS: Moving to 20/\(acuity)")
            resetLetterScaling()
            generateNewLetter()
            _ = set_Size_E(
                letterLabel,
                desired_acuity: acuity,
                letterText: currentLetter
            )

        case let .finish(result):
            completeTest(with: result)
            return
        }

        if consecutiveNoInputTrials >= Self.noInputTrialsBeforeAutoPause {
            // The next letter is on screen; park until Resume rather than auto-failing it too.
            consecutiveNoInputTrials = 0
            autoPauseForNoResponse()
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isPaused else { return }
            self.startListening()
        }
    }
    
    /* Picks a letter from `pool` that differs from `previous`, so the same
       optotype is never presented on two consecutive trials. `previous` is ""
       on the first trial, which is not in the pool and so excludes nothing.
       Returns nil only if `pool` holds nothing but `previous` — unreachable
       with the 11-letter ETDRS set, which
       testETDRSLetterPoolSupportsTheNoRepeatRule pins.
     */
    nonisolated static func nextLetter(in pool: [String], excluding previous: String) -> String? {
        pool.filter { $0 != previous }.randomElement()
    }

    /* Generates a new ETDRS letter randomly, never repeating the letter just
       shown. Mirrors generateNewE() in TumblingEViewController, whose rotation
       increments exclude 0 for the same reason: a subject who sees the same
       stimulus twice in a row can answer the second trial from memory rather
       than from vision.
     */
    private func generateNewLetter() {
        if let nextLetter = Self.nextLetter(in: etdrsLetters, excluding: currentLetter) {
            currentLetter = nextLetter
        }
        resetPendingRecognition()
        unclearRetriesThisLetter = 0
        heardSpeechThisWindow = false
        if !isPaused, !isManuallyPaused {
            // Clear a retry cue left by the previous letter; a pause message stays put.
            instructionLabel.text = Self.answerInstruction
        }
        letterLabel.text = currentLetter
        
        // Keep the stimulus hidden if tracking or calibration expired between trials.
        updateLetterVisibility()
        transcriptionLabel.text = "Listening for one spoken letter"
        
        // Record the time when this letter is displayed for response time calculation
        letterDisplayTime = Date()
        
        print("📝 New letter generated: \(currentLetter)")
    }
    
    /* Prepares for navigation to the results screen.
       Passes the final score data to the destination view controller.
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowResults",
           let resultVC = segue.destination as? ResultViewController {
            resultVC.score = score
            resultVC.totalAttempts = totalAttempts
        }
    }

    /* Checks if the user's distance from the device is within acceptable bounds.
       Implements hysteresis to prevent frequent toggling between paused/unpaused states.
       Also updates letter size in real-time when distance is within acceptable bounds.
       Shows directional arrows and plays audio instructions when out of range.
       @param liveDistance The current measured distance in centimeters
     */
    private func checkDistance(_ liveDistance: Double) {
        // Freeze all distance-driven behavior while manually paused so it can't
        // fight with the pause button (e.g. silently resuming listening).
        guard !isManuallyPaused else { return }

        // Always print extreme values
        let isExtreme = liveDistance < 15 || liveDistance > 100 ||
                       abs(liveDistance - averageDistanceCM) > 30
        
        if isExtreme || Int(Date().timeIntervalSince1970 * 10) % 10 == 0 {
            let status = isPaused ? "⏸️ PAUSED" : "▶️ RUNNING"
            print("\(status) Distance: \(String(format: "%.1f", liveDistance)) cm | Bounds: \(String(format: "%.1f", lowerBound)) - \(String(format: "%.1f", upperBound)) cm")
        }
        
        // Add hysteresis to prevent frequent toggling at the boundary
        let outOfRangeTolerance = min(3.0, max(0, (upperBound - lowerBound) * 0.25))
        
        // Determine user's position relative to acceptable range
        let tooClose = liveDistance < lowerBound
        let tooFar = liveDistance > upperBound
        if isPaused {
            // When already paused, require a more definitive return to range
            if liveDistance >= (lowerBound + outOfRangeTolerance)
                && liveDistance <= (upperBound - outOfRangeTolerance) {
                isPaused = false
                hideAllDistanceIndicators()
                showDistanceOK()
                print("✅ RESUMING TEST - Distance Back in Range: \(String(format: "%.1f", liveDistance)) cm")
                resumeTest()
                
                // Update letter size for the new distance
                updateLetterSizeForDistance(liveDistance)
                
                // Resume speech recognition
                startListening()
            } else {
                // Still out of range - update directional indicators
                updateDirectionalIndicators(tooClose: tooClose, tooFar: tooFar, distance: liveDistance)
            }
        } else {
            // When not paused, use standard bounds
            if tooClose || tooFar {
                isPaused = true
                hideAllDistanceIndicators()
                showDistanceWarning()
                updateDirectionalIndicators(tooClose: tooClose, tooFar: tooFar, distance: liveDistance)
                print("⚠️ PAUSING TEST - Distance Out of Range: \(String(format: "%.1f", liveDistance)) cm")
                pauseTest()
                
                // Stop speech recognition when paused
                stopListening()
            } else {
                // Distance is within acceptable bounds - update letter size if needed
                updateLetterSizeForDistance(liveDistance)
                // Ensure all distance indicators are hidden when in range
                hideAllDistanceIndicators()
            }
        }
    }
    
    /* Updates directional indicators and plays audio instructions based on whether user is too close or too far.
     */
    private func updateDirectionalIndicators(tooClose: Bool, tooFar: Bool, distance: Double) {
        if tooClose {
            distanceGuidanceView.showMoveFarther()
            playAudioInstructionIfNeeded("Move farther.")
        } else if tooFar {
            distanceGuidanceView.showMoveCloser()
            playAudioInstructionIfNeeded("Move closer.")
        }
    }
    
    /* Plays audio instruction only if it's different from the last one played or enough time has passed.
     */
    private func playAudioInstructionIfNeeded(_ instruction: String) {
        // Only play if it's a different instruction or enough time has passed
        if lastAudioInstruction != instruction {
            SharedAudioManager.shared.playText(instruction, source: "Distance Guidance")
            lastAudioInstruction = instruction
            
            // Reset the instruction after 5 seconds to allow replay
            audioInstructionTimer?.invalidate()
            audioInstructionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                self.lastAudioInstruction = ""
            }
        }
    }
    
    /* Shows the distance warning indicator.
     */
    private func showDistanceWarning() {
        distanceGuidanceView.showWarning()
    }
    
    /* Shows the distance OK indicator temporarily.
     */
    private func showDistanceOK() {
        distanceGuidanceView.showOK()
    }
    
    /* Hides all distance-related indicators.
     */
    private func hideAllDistanceIndicators() {
        distanceGuidanceView.hideAll()
    }
    
    /* Updates the letter size when the expected change reaches half a physical pixel.
       @param currentDistance The current measured distance in centimeters
     */
    private func updateLetterSizeForDistance(_ currentDistance: Double) {
        renderCurrentOptotype(distanceCM: currentDistance, force: false)
    }
    
    /* Resets the letter scaling factors when acuity changes.
       This ensures clean scaling for the new acuity level while preserving the calculated font size.
     */
    private func resetLetterScaling() {
        currentRenderSpec = nil
        currentSizingProvenance = nil
        letterLabel.transform = .identity
    }

    /* Pauses the visual acuity test when the user is not at the proper distance.
       Updates UI elements and disables speech recognition.
     */
    private func pauseTest() {
        instructionLabel.text = "Paused: Adjust your distance"
        stopListening()
    }

    /* Resumes the visual acuity test when the user returns to the proper distance.
       Updates UI elements and re-enables speech recognition.
     */
    private func resumeTest() {
        instructionLabel.text = Self.answerInstruction
        startListening()
    }
    
    /* Updates the test based on current distance from the device.
       Called by CADisplayLink for smooth, efficient updates.
       Includes validation and fallback mechanisms for invalid distance readings.
     */
    @objc private func updateLiveDistance() {
        guard let sample = EyeDistanceProvider.shared.validSample(),
              ScreenCalibrationProvider.shared.currentCalibration != nil else {
            pauseForInvalidDistance()
            return
        }
        DistanceTracker.shared.currentDistanceCM = sample.distanceCM
        updateLetterVisibility()
        checkDistance(sample.distanceCM)
    }

    // MARK: - Optotype Rendering

    /* Sets the size of the letter from the current live eye-distance sample.
       @param oneLetter The UILabel to be sized
       @param desired_acuity The target acuity in 20/x notation
       @param letterText The letter to display
     * @return The text that was displayed or nil if the operation failed
     */
    private func set_Size_E(
        _ oneLetter: UILabel?,
        desired_acuity: Int,
        letterText: String?
    ) -> String? {
        guard let sample = EyeDistanceProvider.shared.validSample() else {
            oneLetter?.alpha = 0
            return nil
        }
        return renderOptotype(
            oneLetter,
            desired_acuity: desired_acuity,
            letterText: letterText,
            distanceCM: sample.distanceCM,
            force: true
        )
    }

    private func renderOptotype(
        _ oneLetter: UILabel?,
        desired_acuity: Int,
        letterText: String?,
        distanceCM: Double,
        force: Bool
    ) -> String? {
        guard let text = letterText,
              let label = oneLetter,
              let calibration = ScreenCalibrationProvider.shared.currentCalibration else {
            oneLetter?.alpha = 0
            return nil
        }
        do {
            let update = try OptotypeRenderer.update(
                label: label,
                text: text,
                distanceCM: distanceCM,
                snellenDenominator: desired_acuity,
                calibration: calibration,
                previousSpec: currentRenderSpec,
                force: force
            )
            currentRenderSpec = update.spec
            currentSizingProvenance = update.spec.provenance
            label.alpha = isBetweenLetters ? 0 : 1
            return text
        } catch {
            label.alpha = 0
            print("Unable to size ETDRS optotype: \(error.localizedDescription)")
            return nil
        }
    }

    private func renderCurrentOptotype(distanceCM: Double, force: Bool) {
        guard renderOptotype(
            letterLabel,
            desired_acuity: acuityList[currentAcuityIndex],
            letterText: currentLetter,
            distanceCM: distanceCM,
            force: force
        ) != nil else {
            pauseForInvalidDistance()
            return
        }
    }

    /* Single owner of "show the optotype" decisions. The stimulus is visible
       only when face tracking and screen calibration are both live and no
       inter-letter transition is in flight.
     */
    private func updateLetterVisibility() {
        letterLabel.alpha = !isBetweenLetters
            && EyeDistanceProvider.shared.validSample() != nil
            && ScreenCalibrationProvider.shared.currentCalibration != nil ? 1 : 0
    }

    private func pauseForInvalidDistance() {
        letterLabel.alpha = 0
        isPaused = true
        guard !isManuallyPaused else { return }
        if isListening {
            stopListening()
        }
        // A microphone left warm between letters is released for the pause as well.
        if whisperLetterService.isMicrophoneWarm {
            whisperLetterService.stopListening()
        }
        instructionLabel.text = "Paused: Face tracking unavailable"
        distanceGuidanceView.showWarning()
    }

    private func requireCalibrationIfNeeded() {
        guard ScreenCalibrationProvider.shared.currentCalibration == nil,
              presentedViewController == nil else { return }
        present(ScreenCalibrationViewController(), animated: true)
    }
    
    /* Find the index of a value in a list.
       @param numList The array to search
       @param value The value to find
       @return The index of the value or -1 if not found
     */
    func getIndex(numList: [Int], value: Int) -> Int {
        for (index, val) in numList.enumerated() {
            if val == value {
                return index
            }
        }
        return -1
    }
    
    /* Completes the current eye after the progression engine calculates the
       terminal acuity levels and letter-level LogMAR score.
     */
    private func completeTest(with result: ETDRSFinalResult) {
        print(
            "🔍 ETDRS test completed:",
            "20/\(result.primaryAcuity) \(result.primaryCorrect)/\(etdrsProtocol.trialsPerAcuity),",
            "20/\(result.secondaryAcuity) \(result.secondaryCorrect)/\(etdrsProtocol.trialsPerAcuity),",
            "LogMAR \(result.logMAR)"
        )
        
        // End the data collection session
        dataCollector.endCurrentSession()
        
        // Navigate to the results screen
        
        finalAcuityScore = result.logMAR
        VisualAcuitySession.logMARValue = finalAcuityScore
        VisualAcuitySession.snellenValue = 20 * pow(10, VisualAcuitySession.logMARValue)
        
        if VisualAcuitySession.currentEyeNumber == 2 {
            // Store the right eye's results (tested first)
            VisualAcuitySession.finalAcuityResults[2] = String(
                format: "LogMAR: %.4f, Snellen: 20/%.0f",
                VisualAcuitySession.logMARValue,
                VisualAcuitySession.snellenValue
            )
            
            // Set eye number for left eye test (tested second)
            VisualAcuitySession.currentEyeNumber = 1
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let leftInstrucVC = storyboard.instantiateViewController(withIdentifier: "OneEyeInstruc") as? OneEyeInstruc {
                navigationController?.pushViewController(leftInstrucVC, animated: true)
                print("🔍 ETDRS: Navigating to left eye instructions after right eye completion")
            }
            
        } else {
            // Store the left eye's results (tested second)
            VisualAcuitySession.finalAcuityResults[1] = String(
                format: "LogMAR: %.4f, Snellen: 20/%.0f",
                VisualAcuitySession.logMARValue,
                VisualAcuitySession.snellenValue
            )
            
            performSegue(withIdentifier: "ShowResults", sender: self)
            print("🔍 ETDRS: Navigating to results after left eye completion")
        }
    }

    private func playAudioInstructions() {
        let instructionText = "Say the letter you see. If you can't see it, say skip."
        SharedAudioManager.shared.playText(instructionText, source: "ETDRS Vision Test")
    }
    
    // MARK: - No-Input Window

    /*
     * Arms the no-input window for the listening session `generation`. Called only once the
     * microphone is actually live (see startListening), so the window never counts model or
     * permission latency, the inter-letter gap, or the app's own speech.
     */
    private func startNoInputTimer(generation: Int) {
        stopNoInputTimer()
        noInputTimer = Timer.scheduledTimer(withTimeInterval: Self.noInputWindowSeconds, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.noInputTimer = nil
            self.handleNoInputDeadline(generation: generation)
        }
    }

    private func stopNoInputTimer() {
        noInputTimer?.invalidate()
        noInputTimer = nil
    }

    /* The window elapsed. Before deciding anything, give an utterance that is still in progress
       up to ~1 s to finish, then transcribe everything the live loop has not yet turned into text
       — a quiet answer that never crossed the live voice gate must be heard before the trial is
       called silent.
     */
    private func handleNoInputDeadline(generation: Int) {
        guard isListening, generation == listeningGeneration, !isPaused, !isManuallyPaused else { return }
        print("🎤 ⏰ No-input window elapsed — flushing pending audio before deciding")

        Task { [weak self] in
            guard let self else { return }
            await self.whisperLetterService.waitForUtteranceToEnd()
            let flush = await self.whisperLetterService.finalizeCurrentBufferIfNeeded()
            let voiceDetected = self.whisperLetterService.voiceDetectedThisSession
            await MainActor.run {
                self.resolveNoInputDeadline(flush: flush, voiceDetected: voiceDetected, generation: generation)
            }
        }
    }

    private func resolveNoInputDeadline(
        flush: ETDRSWhisperLetterService.FinalFlushResult,
        voiceDetected: Bool,
        generation: Int
    ) {
        // A live prediction may have scored while the flush ran; stopListening() bumped the
        // generation, so this deadline belongs to a finished session and must do nothing.
        guard isListening, generation == listeningGeneration, !isPaused, !isManuallyPaused else { return }

        var finalHadSpeech = false
        switch flush {
        case .pending:
            // A live inference still holds the audio (its answer arrives through the normal
            // prediction path) or the decode failed transiently. Ask again shortly — bounded, so
            // a stuck engine cannot postpone the decision forever.
            deadlineFlushAttempts += 1
            if deadlineFlushAttempts <= Self.maxDeadlineFlushAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.handleNoInputDeadline(generation: generation)
                }
                return
            }
            print("[ETDRSWhisper] Deadline flush still pending after \(deadlineFlushAttempts) attempts — treating the window as silent")
        case .silence:
            break
        case let .prediction(finalPrediction):
            // A 5 s decode of room noise can hallucinate text ("Thank you.", "Okay."). The
            // vocabulary filter catches the classic forms; on top of that, an answer found only
            // by the deadline flush counts only if voice was actually detected in this window.
            let voiceHeard = heardSpeechThisWindow || voiceDetected
            let isAnswer = finalPrediction.isSkip || finalPrediction.normalizedLetter != nil
            if isAnswer, voiceHeard {
                // The flush found an answer after all: score it through the normal path.
                handleWhisperPrediction(finalPrediction)
                if !isListening { return }
            } else if isAnswer {
                print("[ETDRSWhisper] Ignoring flush transcript '\(finalPrediction.rawTranscription)' — no voice detected in the window")
            }
            finalHadSpeech = voiceHeard
                && !finalPrediction.isIgnorableNonAnswer
                && !ETDRSSpokenResponseClassifier.cleanedTranscriptToken(from: finalPrediction.rawTranscription).isEmpty
        }

        switch ETDRSNoInputRules.resolve(
            heardSpeech: heardSpeechThisWindow || finalHadSpeech,
            retriesUsed: unclearRetriesThisLetter,
            maxRetries: Self.maxUnclearRetriesPerLetter
        ) {
        case let .retry(withPrompt):
            // Engaged but unclear: same letter, fresh window. The microphone is off while the app
            // speaks (startListening parks on isSpeaking and the speech-finished handler re-arms
            // it), so nothing is ever answered into a dead mic; with audio instructions off,
            // playText is a no-op and listening restarts at once.
            unclearRetriesThisLetter += 1
            print("[ETDRSWhisper] Unclear speech at the deadline — retry \(unclearRetriesThisLetter)/\(Self.maxUnclearRetriesPerLetter)\(withPrompt ? " with prompt" : "")")
            // Keep the microphone warm for the silent re-arm; a spoken "Try again." needs the
            // audio session for playback, so that path releases it.
            stopListening(keepMicrophoneWarm: !(withPrompt && SharedAudioManager.shared.isAudioEnabled()))
            // The transcription pill is hidden by stopListening and rewritten by the re-arm, so
            // the cue lives in the instruction label until the next letter.
            instructionLabel.text = Self.retryInstruction
            if withPrompt {
                SharedAudioManager.shared.playText("Try again.", source: "ETDRS Retry")
                requestListeningAfterSpeechIfNeeded()
            } else {
                // Through the cancellable resume item, so a pause, End Test, or backgrounding in
                // the next half second cancels the re-arm like any other deferred resume.
                resumeListeningWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self, !self.isPaused, !self.isManuallyPaused, !self.isListening else { return }
                    self.requestListeningAfterSpeechIfNeeded()
                }
                resumeListeningWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
            }
        case .scoreNoInput:
            print("[ETDRSWhisper] No usable speech in the window for target: \(currentLetter) — scoring no input")
            if showWhisperDebugLabel {
                whisperDebugLabel.text = "Raw: —    →    Mapped: no input    | Match: no"
            }
            stopListening(keepMicrophoneWarm: true)
            scoreResponse(ETDRSNonLetterResponse.noInput)
        }
    }
    
    // MARK: - Inter-Letter Transition

    // The optotype's square goes black for this long between trials, then the
    // screen holds blank for the settle pause that the fly-off used to end with.
    private static let interLetterMaskDuration: TimeInterval = 0.25
    private static let interLetterPauseDuration: TimeInterval = 0.20

    /* The black square that stands in for the optotype between trials. Its side
       is the optotype's rendered cap height — for Sloan, which is drawn on a 5×5
       grid, that is exactly the letter's design square. The label centres its
       line box rather than its cap box, so the square is placed on the glyph's
       cap box instead of on the label's centre.
     */
    private func optotypeSquareFrame() -> CGRect {
        let side = currentRenderSpec?.renderedHeightPoints
            ?? min(letterLabel.bounds.width, letterLabel.bounds.height)
        guard side > 0, let font = letterLabel.font else { return .zero }

        let baselineY = letterLabel.bounds.midY - font.lineHeight / 2 + font.ascender
        let capBoxCentre = CGPoint(
            x: letterLabel.bounds.midX,
            y: baselineY - font.capHeight / 2
        )
        let centre = letterLabel.convert(capBoxCentre, to: view)
        return CGRect(
            x: centre.x - side / 2,
            y: centre.y - side / 2,
            width: side,
            height: side
        )
    }

    /* Replaces the answered optotype with a black square of the same size and
       position, holds it, then hands control back so the next trial can be set
       up. Nothing moves: the square is the whole transition.
     */
    private func presentInterLetterGap(completion: @escaping () -> Void) {
        isBetweenLetters = true
        letterLabel.alpha = 0

        letterMaskView.frame = optotypeSquareFrame()
        letterMaskView.isHidden = false
        view.bringSubviewToFront(letterMaskView)

        let reveal = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.letterMaskView.isHidden = true

            let advance = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.isBetweenLetters = false
                completion()
            }
            self.letterTransitionWorkItem = advance
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.interLetterPauseDuration,
                execute: advance
            )
        }
        letterTransitionWorkItem = reveal
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.interLetterMaskDuration,
            execute: reveal
        )
    }

    /* Tears down an in-flight transition. Called only when the screen goes away:
       a manual pause must NOT cancel it, or isBetweenLetters would be stranded
       at true and the test would never advance past that trial.
     */
    private func cancelInterLetterGap() {
        letterTransitionWorkItem?.cancel()
        letterTransitionWorkItem = nil
        isBetweenLetters = false
        letterMaskView.isHidden = true
    }
}

// MARK: - Non-letter responses and the no-input rule

/// Non-letter `userResponse` values recorded by the ETDRS test. Lowercase, so none can ever equal
/// an uppercase ETDRS letter (the trial scores incorrect by construction); no comma, quote or
/// newline, so `TestProgressionCSVFormatter` writes them unquoted. The strings are shared with
/// Myotect (`TrialResult.NonLetterResponse`) so both apps' exports analyse alike.
enum ETDRSNonLetterResponse {
    /// The participant said "skip": they cannot see the letter.
    static let skipped = "skip"
    /// The no-input window elapsed with no usable speech from a live microphone.
    static let noInput = "no input registered"
}

/// The pure decision behind the no-input deadline, kept off the view controller so it is
/// unit-testable: silence scores a miss; speech that mapped to nothing earns a bounded number of
/// same-letter retries (the first with a spoken re-prompt) before the miss is scored.
enum ETDRSNoInputRules {
    enum Resolution: Equatable {
        case retry(withPrompt: Bool)
        case scoreNoInput
    }

    static func resolve(heardSpeech: Bool, retriesUsed: Int, maxRetries: Int) -> Resolution {
        guard heardSpeech, retriesUsed < maxRetries else { return .scoreNoInput }
        return .retry(withPrompt: retriesUsed == 0)
    }
}
