//
//  TumblingEViewController.swift
//  Distance Measure Test
//
//  Created by Maggie Bao on 7/23/24.
//

import UIKit
import AVFoundation

/// Final acuity score calculated at the end of the test
var finalAcuityScore = -Double.infinity

/* TumblingEViewController class implements a visual acuity test using a tumbling C paradigm.
   The test displays a rotated "C" letter at various sizes, and the user must swipe in the
   direction the C is pointing. The test maintains a fixed testing distance using AR face tracking.
 */
class TumblingEViewController: UIViewController {
    // MARK: - Properties
    
    private var isPaused = false
    // Set only by the user tapping the Pause/Resume button — kept separate from
    // `isPaused` (the automatic distance-based pause) so the two can't override
    // each other, e.g. the distance coming back in range must not silently
    // re-enable swipes on a test the user deliberately paused.
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
    
    /// Current index in the acuity list
    var currentAcuityIndex = 0
    
    /// Current trial number within the current acuity level
    var trial = 1
    
    /// Number of correct answers in the current set of trials
    var correctAnswersInSet = 0
    
    /// Dictionary tracking correct answers across all acuity levels
    var correctAnswersAcrossAcuityLevels: [Int: Int] = [:]
    
    /// Counter for tracking trial sequence
    var counter = 0
    
    /// Number of trials to skip if user gets all correct
    var SKIP = 5
    
    /// Maximum number of correct answers needed to advance
    var MAX_CORRECT = 10
    
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
    
    // MARK: - UI Elements
    
    // Label displaying the tumbling C for the vision test
    private lazy var letterLabel: UILabel = {
        let label = UILabel()
        label.text = LETTER
        label.font = UIFont(name: "Sloan", size: 50) // Temporary size, will be set by set_Size_E()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Opaque square drawn over the optotype between trials. Masking with a
    // sibling view rather than recolouring letterLabel matters: the 10 fps
    // distance display link writes letterLabel.alpha on its own schedule, and an
    // opaque cover hides the answered ring no matter what alpha it lands on.
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
        label.text = "Please swipe in the direction the C is pointing."
        label.drawInstruction()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var distanceGuidanceView = DistanceGuidanceView()
    
    // MARK: - Test Properties
    
    // Current rotation angle of the letter (in degrees)
    private var currentRotation: Double = 0
    
    // Number of correct answers
    private var score = 0
    
    // Total number of test attempts
    private var totalAttempts = 0
    
    // Available rotation angles for the letter (right, down, left,  up)
    private let possibleRotations = [0.0, 90.0, 180.0, 270.0]
    
    private var currentRenderSpec: OptotypeRenderSpec?
    private var currentSizingProvenance: SizingProvenance?

    private var letterTransitionWorkItem: DispatchWorkItem?

    // True from the moment a response is scored until the next optotype is on
    // screen. The distance display link and the renderer both write
    // letterLabel.alpha, so without this they would uncover the ring the
    // participant just answered during the transition gap.
    private var isBetweenLetters = false
    
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
    
    // MARK: - Lifecycle Methods
    
    /* Initializes the view and sets up the test environment.
       This method sets up the UI elements, configures gesture recognizers for user input,
       initializes the current acuity level from the selected value, sets up distance tracking
       and boundaries, initializes AR face tracking for distance monitoring, and sizes the
       test letter appropriately for the current acuity level.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        print("TumblingEViewController - viewDidLoad")

        // Set up the basic UI and gesture recognizers
        view.backgroundColor = .white

        // Remove the default system Back button. An accidental swipe near the
        // top-left of the screen was registering as a tap on it and popping
        // the test mid-trial. A confirmed "End Test" affordance is added in
        // its place (see setupEndTestButton).
        navigationItem.hidesBackButton = true
        navigationItem.setHidesBackButton(true, animated: false)

        setupUI()
        setupEndTestButton()
        setupPauseButton()
        setupGestureRecognizers()

        // Initialize acuity level from the selected value
        initializeAcuityLevel()
        
        // Set up distance tracking and monitoring
        initializeDistanceTracking()
        
        // Finish layout and generate the first rotated letter
        view.layoutIfNeeded()
        generateNewE()
        letterLabel.alpha = 0
        
        // Update eye test label based on current eye number
        updateEyeTestLabel()
        
        // Initialize data collection session
        let eyeName = VisualAcuitySession.eyeName(for: VisualAcuitySession.currentEyeNumber)
        dataCollector.startNewSession(eye: eyeName, testType: "Landolt_C")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupARTracking()
        startDistanceMonitoring()

        // Prevent the system left-edge swipe-back from swallowing the user's
        // rightward swipe answer during the test.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        requireCalibrationIfNeeded()

        // Play audio instructions for the tumbling C test screen
        playAudioInstructions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Restore the system pop gesture for other screens.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true

        // Clean up timers and display link
        audioInstructionTimer?.invalidate()
        audioInstructionTimer = nil
        displayLink?.invalidate()
        displayLink = nil
        cancelInterLetterGap()
        EyeDistanceProvider.shared.stop(client: self)
    }

    /*
    * Updates the eye test label based on the current eye number.
    */
    private func updateEyeTestLabel() {
        let eyeName = VisualAcuitySession.eyeName(for: VisualAcuitySession.currentEyeNumber)
        eyeTestLabel.applyEyeTestTitle(eyeName: eyeName, testName: "Landolt C")
    }

    /*
     * Initializes the acuity level based on the user's selection.
     * If no selection was made or the selection is invalid, defaults to the largest letter size.
     */
    private func initializeAcuityLevel() {
        // Debug: Print selected acuity at start
        print("Initial selectedAcuity value: \(String(describing: VisualAcuitySession.selectedAcuity))")
        
        if let selectedAcuity = VisualAcuitySession.selectedAcuity {
            // Find the index of the selected acuity in our acuity list
            currentAcuityIndex = getIndex(numList: acuityList, value: selectedAcuity)
            print("The index of \(selectedAcuity) is \(currentAcuityIndex).")
            
            // If the acuity wasn't found in our list, default to the largest size
            if currentAcuityIndex == -1 {
                print("Selected acuity not found in acuity list, defaulting to first entry")
                currentAcuityIndex = 0
            }
        } else {
            print("Selected acuity is nil, defaulting to largest size")
            currentAcuityIndex = 0
        }
    }
    
    /*
     * Initializes distance tracking parameters including
     * retrieving saved distances and setting acceptable bounds.
     */
    private func initializeDistanceTracking() {
        averageDistanceCM = DistanceTracker.shared.preferredHoldingDistanceCM ?? 0
        print("Target test distance: \(averageDistanceCM) cm")
        
        if averageDistanceCM > 0 {
            lowerBound = max(EyeDistanceSample.acceptedRangeCM.lowerBound, 0.8 * averageDistanceCM)
            upperBound = min(EyeDistanceSample.acceptedRangeCM.upperBound, 1.2 * averageDistanceCM)
        } else {
            lowerBound = EyeDistanceSample.acceptedRangeCM.lowerBound
            upperBound = EyeDistanceSample.acceptedRangeCM.upperBound
        }
        print("Distance bounds set to: \(String(format: "%.1f", lowerBound)) - \(String(format: "%.1f", upperBound)) cm")
    }
    
    /*
     * Starts the shared eye-distance provider used by every test screen.
     */
    private func setupARTracking() {
        EyeDistanceProvider.shared.start(
            eyeNumber: VisualAcuitySession.currentEyeNumber,
            client: self
        )
    }

    /*
     * Initiates distance monitoring with CADisplayLink for better performance.
     * Can be configured to bypass distance checking for testing purposes.
     */
    private func startDistanceMonitoring() {
        if displayLink != nil { return }
        
        // Add a debug option to skip distance checking for testing
        #if DEBUG
        let debugBypassDistanceCheck = ProcessInfo.processInfo.environment["LANDOLT_BYPASS_DISTANCE_CHECK"] == "1"
        
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
        
        distanceGuidanceView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Eye test label constraints
            eyeTestLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            eyeTestLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            eyeTestLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Distance guidance view constraints
            distanceGuidanceView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            distanceGuidanceView.topAnchor.constraint(equalTo: eyeTestLabel.bottomAnchor, constant: 18),
            distanceGuidanceView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            distanceGuidanceView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // Letter label constraints
            letterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            letterLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            letterLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // Instruction label constraints
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        print("TumblingEViewController - constraints activated")
    }
    
    /*
     * Sets up swipe gesture recognizers for all four directions.
     */
    private func setupGestureRecognizers() {
        let directions: [UISwipeGestureRecognizer.Direction] = [.right, .left, .up, .down]

        for direction in directions {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
            swipe.direction = direction
            view.addGestureRecognizer(swipe)
        }
    }

    /*
     * Installs an explicit "End Test" button on the navigation bar's trailing
     * edge so the user still has an intentional way to exit the test after
     * the default Back button is hidden. Tap requires a confirmation alert.
     */
    private func setupEndTestButton() {
        navigationItem.rightBarButtonItem = makeEndTestBarButton(action: #selector(endTestTapped))
    }

    @objc private func endTestTapped() {
        let alert = UIAlertController(
            title: "End test?",
            message: "Your progress on this set will be lost.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "End Test", style: .destructive) { [weak self] _ in
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
     * the user can manually halt swipe recognition and test progression.
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

    /* Manually pauses the test: disables swipe recognition immediately. */
    private func applyManualPause() {
        pauseBarButtonItem.title = "Resume"
        view.isUserInteractionEnabled = false
        instructionLabel.text = "Paused"
        announceForVoiceOver("Test paused.")
    }

    /* Manually resumes the test. If the user is still out of the acceptable
       distance range, swipes stay disabled until distance-based auto-resume
       (checkDistance) brings it back — it will now be free to run again
       since isManuallyPaused is false.
    */
    private func applyManualResume() {
        pauseBarButtonItem.title = "Pause"
        if isPaused {
            instructionLabel.text = "Paused: Adjust your distance"
            announceForVoiceOver("Still out of range. Test will resume automatically once you're back in range.")
        } else {
            instructionLabel.text = "Please swipe in the direction the C is pointing."
            view.isUserInteractionEnabled = true
            announceForVoiceOver("Test resumed.")
        }
    }

    // MARK: - Gesture Handling
    /*
     * Handles a user's swipe gesture and determines if it matches the direction of the letter.
     *
     * @param gesture The UISwipeGestureRecognizer that triggered this action
     */
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard !isPaused, !isManuallyPaused else { return }
        // A swipe landing inside the transition gap would be scored against the
        // orientation the participant has already answered.
        guard !isBetweenLetters else { return }
        guard let responseDistance = EyeDistanceProvider.shared.validSample()?.distanceCM,
              let calibration = ScreenCalibrationProvider.shared.currentCalibration,
              let sizingProvenance = currentSizingProvenance,
              sizingProvenance.matches(calibration) else {
            pauseForInvalidDistance()
            return
        }
        var isCorrect = 0
        
        switch (gesture.direction, currentRotation) {
        case (.right, 0), (.down, 90), (.left, 180), (.up, 270):
            isCorrect = 1
            score += 1
            correctAnswersInSet += 1 // Track correct answers in the current set of 10
        default:
            isCorrect = 0
        }
        
        totalAttempts += 1
        trial += 1 // Increment the trial count within this set
        
        // Calculate response time
        let responseTime: Int64
        if let displayTime = letterDisplayTime {
            responseTime = Int64(Date().timeIntervalSince(displayTime) * 1000) // Convert to milliseconds
        } else {
            responseTime = 0 // Fallback if timing wasn't recorded
        }
        
        // Convert swipe direction and rotation to readable format
        let orientationDisplayed = getOrientationString(for: currentRotation)
        let userSwipeDirection = getSwipeDirectionString(for: gesture.direction)
        
        // Record the response data
        let eyeName = VisualAcuitySession.eyeName(for: VisualAcuitySession.currentEyeNumber)
        let acuityString = "20/\(acuityList[currentAcuityIndex])"
        
        dataCollector.recordResponse(
            eye: eyeName,
            testType: "Landolt_C",
            acuityLevel: acuityString,
            letterDisplayed: orientationDisplayed,
            distanceCM: responseDistance,
            responseTimeMS: responseTime,
            userResponse: userSwipeDirection,
            isCorrect: isCorrect == 1,
            trialNumber: trial - 1, // trial was already incremented, so subtract 1 for the actual trial number
            sizingProvenance: sizingProvenance
        )
        
        print("🎯 C Orientation: \(orientationDisplayed), Swipe: \(userSwipeDirection), Correct: \(isCorrect == 1), Time: \(responseTime)ms")
        
        // Blank the optotype's square before processing the next trial
        presentInterLetterGap { [weak self] in
            self?.processNextTrial()
        }
    }
    
    /* Processes the current trial state and determines the next steps in the test.
       This method is called after each user response and handles tracking correct answers,
       determining acuity level changes, calculating final scores, and resetting trial counters.
     */
    private func processNextTrial() {
        print("trial:", trial, "correctAnswersInSet:",correctAnswersInSet)
        let acuity = acuityList[currentAcuityIndex]
        correctAnswersAcrossAcuityLevels[acuity] = correctAnswersInSet
        print("correctAnswersAcrossAcuityLevels:", correctAnswersAcrossAcuityLevels)
        print(currentAcuityIndex, acuity)
        // Check if trial count has reached 10 or if the user has first 5 correct
        if (trial > 10) || ((trial == SKIP + 1) && (correctAnswersInSet == SKIP)) {
            if (trial == SKIP + 1) && (correctAnswersInSet == SKIP){
                print("skip")
                correctAnswersAcrossAcuityLevels[acuity] = MAX_CORRECT
                correctAnswersInSet = MAX_CORRECT
            }
            if currentAcuityIndex == acuityList.count - 1 { // Successfully completed the smallest size
                calculateScore(finishAcuity1: acuity, amtCorrect1: correctAnswersAcrossAcuityLevels[acuity] ?? 0, finishAcuity2: acuityList[currentAcuityIndex-1], amtCorrect2: correctAnswersAcrossAcuityLevels[acuityList[currentAcuityIndex-1]] ?? 0)
                return
            }
            if correctAnswersInSet < 6 { // If the user cannot get at least 6 letters correct
                if currentAcuityIndex <= 0 { // At largest letter size
                    print("You are BLIND! We cannot assess you.")
                    calculateScore(finishAcuity1: acuityList[currentAcuityIndex+1], amtCorrect1: correctAnswersAcrossAcuityLevels[acuityList[currentAcuityIndex+1]] ?? 0, finishAcuity2: acuity, amtCorrect2: correctAnswersAcrossAcuityLevels[acuity] ?? 0)
                } else { // Move back to previous acuity if incorrect
                    let previousAcuity = acuityList[currentAcuityIndex-1]
                    if correctAnswersAcrossAcuityLevels[previousAcuity] != nil {
                        calculateScore(finishAcuity1: acuity, amtCorrect1: correctAnswersInSet, finishAcuity2: previousAcuity, amtCorrect2: correctAnswersAcrossAcuityLevels[previousAcuity] ?? 0)
                    } else {
                        print("Going back to larger acuity...")
                        currentAcuityIndex -= 1
                        resetLetterScaling() // Reset scaling for new acuity level
                        _ = set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: LETTER) // Update the letter size
                    }
                }
            } else { // User gets at least 6 letters correct, advance to next level
                let nextAcuity = acuityList[currentAcuityIndex+1]
                if correctAnswersAcrossAcuityLevels[nextAcuity] != nil {
                    calculateScore(finishAcuity1: nextAcuity, amtCorrect1: correctAnswersAcrossAcuityLevels[nextAcuity] ?? 0, finishAcuity2: acuity, amtCorrect2: correctAnswersInSet)
                } else {
                    print("Advancing to smaller acuity...")
                    currentAcuityIndex += 1
                    resetLetterScaling() // Reset scaling for new acuity level
                    _ = set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: LETTER) // Update the letter size
                }
            }
            // Reset trial counter and correct answers count
            trial = 1
            correctAnswersInSet = 0
        }
        generateNewE() // Generate the next letter with updated size or same size
    }
    
    /* Generates a new tumbling C with a random rotation.
       Animates the rotation of the letter to one of four possible orientations.
     */
    private func generateNewE() {
        // Current position can be 0°, 90°, 180°, or 270°
        // Add random increment (90°, 180°, or 270°) to get next position
        let currentRotationValue = currentRotation
        let increments = [90.0, 180.0, 270.0]
        
        var newRotation: Double
        let randomIncrement = increments.randomElement() ?? 0.0
        newRotation = (currentRotationValue + randomIncrement).truncatingRemainder(dividingBy: 360)
        
        currentRotation = newRotation
        
        // Apply rotation without animation
        letterLabel.transform = CGAffineTransform(rotationAngle: CGFloat(currentRotation) * .pi / 180)
        
        // Make the letter visible now that the new rotation is applied
        updateLetterVisibility()
        
        // Record the time when this letter is displayed for response time calculation
        letterDisplayTime = Date()
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
        // fight with the pause button (e.g. silently re-enabling swipes).
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
                distanceGuidanceView.hideAll()
                distanceGuidanceView.showOK()
                print("✅ RESUMING TEST - Distance Back in Range: \(String(format: "%.1f", liveDistance)) cm")
                resumeTest()
                
                // Update letter size for the new distance
                updateLetterSizeForDistance(liveDistance)
            } else {
                // Still out of range - update directional indicators
                updateDirectionalIndicators(tooClose: tooClose, tooFar: tooFar, distance: liveDistance)
            }
        } else {
            // When not paused, use standard bounds
            if tooClose || tooFar {
                isPaused = true
                distanceGuidanceView.hideAll()
                distanceGuidanceView.showWarning()
                updateDirectionalIndicators(tooClose: tooClose, tooFar: tooFar, distance: liveDistance)
                print("⚠️ PAUSING TEST - Distance Out of Range: \(String(format: "%.1f", liveDistance)) cm")
                pauseTest()
            } else {
                // Distance is within acceptable bounds - update letter size if needed
                updateLetterSizeForDistance(liveDistance)
                // Ensure all distance indicators are hidden when in range
                distanceGuidanceView.hideAll()
            }
        }
    }
    
    /* Updates directional indicators and plays audio instructions based on whether user is too close or too far.
     */
    private func updateDirectionalIndicators(tooClose: Bool, tooFar: Bool, distance: Double) {
        if tooClose {
            distanceGuidanceView.showMoveFarther()
            playAudioInstructionIfNeeded("Move farther to continue.")
        } else if tooFar {
            distanceGuidanceView.showMoveCloser()
            playAudioInstructionIfNeeded("Move closer to continue.")
        }
    }

    private func restoreOptotypeDisplay() {
        letterLabel.text = LETTER
        letterLabel.textColor = AppThemeColors.black
        letterLabel.textAlignment = .center
        letterLabel.numberOfLines = 0
        _ = set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: LETTER)
        letterLabel.transform = CGAffineTransform(rotationAngle: CGFloat(currentRotation) * .pi / 180)
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
        letterLabel.transform = CGAffineTransform(
            rotationAngle: CGFloat(currentRotation) * .pi / 180
        )
    }

    /* Pauses the visual acuity test when the user is not at the proper distance.
       Updates UI elements and disables user interaction.
     */
    private func pauseTest() {
        instructionLabel.text = "Paused: Adjust your distance"
        view.isUserInteractionEnabled = false // Disable swipes
    }

    /* Resumes the visual acuity test when the user returns to the proper distance.
       Updates UI elements and re-enables user interaction.
     */
    private func resumeTest() {
        restoreOptotypeDisplay()
        instructionLabel.text = "Please swipe in the direction the C is pointing."
        view.isUserInteractionEnabled = true // Re-enable swipes
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
            label.transform = CGAffineTransform(
                rotationAngle: CGFloat(currentRotation) * .pi / 180
            )
            label.alpha = isBetweenLetters ? 0 : 1
            return text
        } catch {
            label.alpha = 0
            print("Unable to size Landolt-C optotype: \(error.localizedDescription)")
            return nil
        }
    }

    private func renderCurrentOptotype(distanceCM: Double, force: Bool) {
        guard renderOptotype(
            letterLabel,
            desired_acuity: acuityList[currentAcuityIndex],
            letterText: LETTER,
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
        distanceGuidanceView.showWarning()
        pauseTest()
        instructionLabel.text = "Paused: Face tracking unavailable"
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
    
    /* Calculates the final acuity score based on performance at two acuity levels.
       Uses the number of correct/incorrect responses to refine the score.
       Navigates to the results screen with the final score.
       @param finishAcuity1 The first acuity level (20/x notation)
       @param amtCorrect1 Number of correct responses at first acuity level
       @param finishAcuity2 The second acuity level (20/x notation)
       @param amtCorrect2 Number of correct responses at second acuity level
       @param totalLetters Total number of letters shown at each acuity level
     */
    func calculateScore(finishAcuity1: Int, amtCorrect1: Int, finishAcuity2: Int, amtCorrect2: Int, totalLetters: Int = 10) {
        print("finishAcuity1", finishAcuity1)
        let amtWrongCurrent1 = Double(totalLetters - amtCorrect1)
        let amtWrongCurrent2 = Double(totalLetters - amtCorrect2)
        print("You have an acuity of", finishAcuity1, "with", amtWrongCurrent1, "letters wrong on that line.")
        print("You have an acuity of", finishAcuity2, "with", amtWrongCurrent2, "letters wrong on that line.")
        
        // Convert to LogMAR scale and adjust based on errors
        var acuityScore = usFootToLogMAR[finishAcuity1] ?? 0.0
        acuityScore += amtWrongCurrent1 / 100.0
        acuityScore += amtWrongCurrent2 / 100.0
        
        // Pass this score to the results page via the prepare method
        print("Test completed with final acuity level: \(acuityScore)")
        
        // End the data collection session
        dataCollector.endCurrentSession()
        
        // Navigate to the results screen
        
        finalAcuityScore = acuityScore
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
            }
            
        } else {
            // Store the left eye's results (tested second)
            VisualAcuitySession.finalAcuityResults[1] = String(
                format: "LogMAR: %.4f, Snellen: 20/%.0f",
                VisualAcuitySession.logMARValue,
                VisualAcuitySession.snellenValue
            )
            
            performSegue(withIdentifier: "ShowResults", sender: self)
        }
    }

    private func playAudioInstructions() {
        let instructionText = "Swipe in the direction the C opening points."
        SharedAudioManager.shared.playText(instructionText, source: "Vision Test")
    }
    
    // MARK: - Data Collection Helper Methods
    
    /*
     * Converts rotation angle to readable orientation string
     */
    private func getOrientationString(for rotation: Double) -> String {
        switch rotation {
        case 0:
            return "Right"
        case 90:
            return "Down"
        case 180:
            return "Left"
        case 270:
            return "Up"
        default:
            return "Unknown(\(rotation)°)"
        }
    }
    
    /*
     * Converts swipe direction to readable string
     */
    private func getSwipeDirectionString(for direction: UISwipeGestureRecognizer.Direction) -> String {
        switch direction {
        case .right:
            return "Right"
        case .left:
            return "Left"
        case .up:
            return "Up"
        case .down:
            return "Down"
        default:
            return "Unknown"
        }
    }
    
    // MARK: - Inter-Letter Transition

    // The optotype's square goes black for this long between trials, then the
    // screen holds blank for the settle pause that the fly-off used to end with.
    private static let interLetterMaskDuration: TimeInterval = 0.25
    private static let interLetterPauseDuration: TimeInterval = 0.20

    /* The black square that stands in for the optotype between trials. Its side
       is the optotype's rendered cap height — for Sloan, which is drawn on a 5×5
       grid, that is exactly the ring's design square. The label centres its line
       box rather than its cap box, so the square is placed on the glyph's cap box
       instead of on the label's centre. convert(_:to:) carries the label's
       rotation, and a square is rotation-invariant, so no further adjustment is
       needed for the tumbling orientations.
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
