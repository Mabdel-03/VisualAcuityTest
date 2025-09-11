//
//  TumblingEViewController.swift
//  Distance Measure Test
//
//  Created by Maggie Bao on 7/23/24.
//

import UIKit
import DevicePpi
import ARKit
import AVFoundation

//Global Variables

/// Flag indicating if the test is currently paused due to distance issues
var isPaused = false

/// Lower boundary for acceptable testing distance (calculated as percentage of target distance)
var lowerBound: Double = 0.0

/// Upper boundary for acceptable testing distance (calculated as percentage of target distance)
var upperBound: Double = 0.0

/// Reference to the AR scene view for face tracking
var sceneView: ARSCNView!

/// 3D node representing the user's left eye position
var leftEye: SCNNode!

/// 3D node representing the user's right eye position
var rightEye: SCNNode!

/// Device's pixels per inch, used for accurate size calculations
let ppi: Double = {
    switch Ppi.get() {
    case .success(let ppi):
        return ppi
    case .unknown(let bestGuessPpi, _):
        return bestGuessPpi
    }
}()

/// Final acuity score calculated at the end of the test
var finalAcuityScore = -Double.infinity

/* TumblingEViewController class implements a visual acuity test using a tumbling E paradigm.
   The test displays a rotated "C" letter at various sizes, and the user must swipe in the
   direction the C is pointing. The test maintains a fixed testing distance using AR face tracking.
 */
class TumblingEViewController: UIViewController, ARSCNViewDelegate {
    // MARK: - Properties
    
    /// AR scene view for face tracking
    var sceneView: ARSCNView!
    
    /// 3D node for left eye tracking
    var leftEye: SCNNode!
    
    /// 3D node for right eye tracking
    var rightEye: SCNNode!
    
    /// Current eye being tested (1 for left eye, 2 for right eye)
    //var eyeNumber: Int = 1
    
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
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Label indicating which eye is being tested
    private lazy var eyeTestLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor(red: 0.820, green: 0.106, blue: 0.376, alpha: 1.0) // #D11B60
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Label displaying instructions to the user
    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Please swipe in the direction the C is pointing."
        label.font = UIFont.systemFont(ofSize: 40, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    // Label warning the user about incorrect distance
    private lazy var warningLabel: UILabel = {
        let label = UILabel()
        label.text = "⚠️ Adjust Distance"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .red
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    // Label indicating distance is acceptable
    private lazy var checkmarkLabel: UILabel = {
        let label = UILabel()
        label.text = "✅ Distance OK"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .green
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // Label with arrow indicating user should move closer
    private lazy var moveCloserArrowLabel: UILabel = {
        let label = UILabel()
        label.text = "⬇️ Move Closer ⬇️"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = .orange
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        label.numberOfLines = 0
        return label
    }()
    
    // Label with arrow indicating user should move farther
    private lazy var moveFartherArrowLabel: UILabel = {
        let label = UILabel()
        label.text = "⬆️ Move Farther ⬆️"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = .orange
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        label.numberOfLines = 0
        return label
    }()
    
    // MARK: - Test Properties
    
    // Current rotation angle of the letter (in degrees)
    private var currentRotation: Double = 0
    
    // Number of correct answers
    private var score = 0
    
    // Total number of test attempts
    private var totalAttempts = 0
    
    // Available rotation angles for the letter (right, down, left, up)
    private let possibleRotations = [0.0, 90.0, 180.0, 270.0]
    
    // Last distance used for letter scaling to prevent unnecessary updates
    private var lastScalingDistance: Double = 0.0
    
    // Minimum distance change required to trigger letter rescaling (in cm)
    private let scalingDistanceThreshold: Double = 2.0
    
    // Last audio instruction played to avoid repetition
    private var lastAudioInstruction: String = ""
    
    // Timer for audio instruction repetition
    private var audioInstructionTimer: Timer?
    
    // Display link for smooth distance monitoring
    private var displayLink: CADisplayLink?
    
    // Base font size for scaling calculations
    private let baseFontSize: CGFloat = 100.0
    
    // Last scale factor applied to prevent unnecessary transforms
    private var lastScaleFactor: CGFloat = 1.0
    
    // Last AR update time for throttling updates
    private var lastARUpdateTime: CFTimeInterval?
    
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
        setupUI()
        setupGestureRecognizers()

        // Initialize acuity level from the selected value
        initializeAcuityLevel()
        
        // Set up distance tracking and monitoring
        initializeDistanceTracking()
        
        // Set up AR face tracking for distance monitoring
        setupARTracking()
        
        // Start monitoring distance with appropriate checks
        startDistanceMonitoring()

        // Size the test letter for the current acuity level
        set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: LETTER)
        print("Initial letter size set for acuity: \(acuityList[currentAcuityIndex])")
        
        // Initialize scaling factors (but preserve the font size calculated above)
        lastScaleFactor = 1.0
        lastScalingDistance = 0.0
        
        // Add triple-tap gesture to bypass distance checking if needed
        setupEmergencyOverride()
        
        // Finish layout and generate the first rotated letter
        view.layoutIfNeeded()
        generateNewE()
        
        // Update eye test label based on current eye number
        updateEyeTestLabel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Play audio instructions for the tumbling E test screen
        playAudioInstructions()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Clean up timers and display link
        audioInstructionTimer?.invalidate()
        audioInstructionTimer = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    /*
    * Updates the eye test label based on the current eye number.
    */
    private func updateEyeTestLabel() {
        eyeTestLabel.text = eyeNumber == 2 ? "Right Eye Test" : "Left Eye Test"
    }

    /*
     * Initializes the acuity level based on the user's selection.
     * If no selection was made or the selection is invalid, defaults to the largest letter size.
     */
    private func initializeAcuityLevel() {
        // Debug: Print selected acuity at start
        print("Initial selectedAcuity value: \(String(describing: selectedAcuity))")
        
        if let selectedAcuity = selectedAcuity {
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
        // Get stored target distance
        averageDistanceCM = DistanceTracker.shared.targetDistanceCM
        
        // If no valid distance is stored, try to load from UserDefaults
        if averageDistanceCM <= 0 {
            if let savedDistance = UserDefaults.standard.object(forKey: "SavedTargetDistance") as? Double,
               savedDistance > 0 {
                print("📏 Loading saved distance from UserDefaults: \(savedDistance) cm")
                averageDistanceCM = savedDistance
                DistanceTracker.shared.targetDistanceCM = savedDistance
            } else {
                print("⚠️ No valid distance found - using default of 40 cm")
                averageDistanceCM = 40.0
                DistanceTracker.shared.targetDistanceCM = 40.0
            }
        }
        
        print("Target test distance: \(averageDistanceCM) cm")
        
        // If current distance is invalid but target is valid, use target as current
        if averageDistanceCM > 0 && DistanceTracker.shared.currentDistanceCM < 10 {
            print("⚠️ Current distance invalid - using stored target distance")
            DistanceTracker.shared.currentDistanceCM = averageDistanceCM
        }
        
        // Set acceptable distance range (±20% of target)
        lowerBound = 0.8 * averageDistanceCM  // 20% below target
        upperBound = 1.2 * averageDistanceCM  // 20% above target
        print("Distance bounds set to: \(String(format: "%.1f", lowerBound)) - \(String(format: "%.1f", upperBound)) cm")
    }
    
    /*
     * Sets up an emergency override gesture (triple tap) to bypass
     * distance checking if the user encounters persistent distance issues.
     */
    private func setupEmergencyOverride() {
        // Setup override gesture - triple tap to bypass distance checking
        let tripleTap = UITapGestureRecognizer(target: self, action: #selector(handleTripleTap))
        tripleTap.numberOfTapsRequired = 3
        view.addGestureRecognizer(tripleTap)
    }

    /*
     * Handles the triple-tap gesture to bypass distance checking.
     * This is an emergency override for when distance detection is problematic.
     */
    @objc private func handleTripleTap() {
        isPaused = false
        hideAllDistanceIndicators()
        showDistanceOK()
        
        // Show a temporary message
        let overrideLabel = UILabel()
        overrideLabel.text = "⚠️ Distance Check Bypassed"
        overrideLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        overrideLabel.textColor = .orange
        overrideLabel.textAlignment = .center
        overrideLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(overrideLabel)
        
        NSLayoutConstraint.activate([
            overrideLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overrideLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80)
        ])
        
        // Also reset current distance to target to avoid further problems
        DistanceTracker.shared.currentDistanceCM = averageDistanceCM
        
        // Reset scaling factors to trigger immediate rescaling with new approach
        letterLabel.transform = CGAffineTransform.identity
        lastScaleFactor = 1.0
        lastScalingDistance = 0.0
        
        // Clear any pending audio instructions
        lastAudioInstruction = ""
        audioInstructionTimer?.invalidate()
        
        print("🔧 Distance check bypassed via triple tap")
        
        // Resume the test
        resumeTest()
        
        // Remove the message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            overrideLabel.removeFromSuperview()
        }
    }

    /*
     * Sets up AR face tracking for distance monitoring.
     * Initializes the AR scene and creates tracking nodes for the eyes.
     */
    private func setupARTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("⚠️ AR Face Tracking is NOT supported on this device.")
            return
        }

        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        
        // Create an AR face tracking configuration with maximum tracking capability
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.maximumNumberOfTrackedFaces = 1 // Focus on tracking a single face well
        
        // Add the scene view but hide it
        sceneView.isHidden = true
        view.addSubview(sceneView)
        
        // Start a new tracking session with maximum quality
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        print("👁️ AR Face Tracking Started")

        // Initialize eye tracking nodes with distinctive colors for debugging
        let eyeGeometry = SCNSphere(radius: 0.01)
        eyeGeometry.firstMaterial?.diffuse.contents = UIColor.blue
        
        leftEye = SCNNode(geometry: eyeGeometry)
        rightEye = SCNNode(geometry: eyeGeometry)
        
        // Log the target distance for reference
        print("📏 Target testing distance: \(String(format: "%.1f", averageDistanceCM)) cm")
        print("📏 Acceptable range: \(String(format: "%.1f", lowerBound)) - \(String(format: "%.1f", upperBound)) cm")
    }

    /*
     * Initiates distance monitoring with CADisplayLink for better performance.
     * Can be configured to bypass distance checking for testing purposes.
     */
    private func startDistanceMonitoring() {
        // Add a debug option to skip distance checking for testing
        #if DEBUG
        let debugBypassDistanceCheck = false // Set to true to bypass distance checking
        
        // Extra debugging for distance
        let debugExtraLogging = true // Set to true for more verbose distance logs
        
        if debugBypassDistanceCheck {
            print("🔧 DEBUG MODE: Distance checking disabled")
            isPaused = false
            warningLabel.isHidden = true
            checkmarkLabel.isHidden = true
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
     * Called when a new AR anchor is added to the scene.
     * Used to attach eye nodes to detected face anchors.
     */
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        // Add eye nodes to the face node
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
        
        print("👁️ Face detected and tracking started")
    }
    
    /*
     * Called when an AR anchor is updated in the scene.
     * Updates eye positions and calculates distance from the device.
     * Optimized to reduce unnecessary calculations.
     */
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        // Update eye transforms
        leftEye.simdTransform = faceAnchor.leftEyeTransform
        rightEye.simdTransform = faceAnchor.rightEyeTransform

        // Only process every few frames to reduce computational load
        let currentTime = CACurrentMediaTime()
        if let lastUpdateTime = lastARUpdateTime, currentTime - lastUpdateTime < 0.1 {
            return // Skip this update if less than 100ms since last update
        }
        lastARUpdateTime = currentTime

        // Get camera position
        guard let frame = sceneView.session.currentFrame else { return }
        let cameraTransform = frame.camera.transform
        
        // Batch distance calculations off main thread for better performance
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            let cameraPosition = SCNVector3(cameraTransform.columns.3.x,
                                            cameraTransform.columns.3.y,
                                            cameraTransform.columns.3.z)
            
            let leftEyePos = self.leftEye.worldPosition
            let rightEyePos = self.rightEye.worldPosition

            // Only calculate distance if eyes are valid positions
            if leftEyePos.length() > 0 && rightEyePos.length() > 0 {
                // Calculate distance from camera to eyes
                let leftEyeDistance = self.SCNVector3Distance(leftEyePos, cameraPosition)
                let rightEyeDistance = self.SCNVector3Distance(rightEyePos, cameraPosition)
                
                // Use only the relevant eye's distance based on which eye is being tested
                let rawDistance = (eyeNumber == 1) ? leftEyeDistance : rightEyeDistance
                let rawAverageDistance = rawDistance * 100  // Convert to cm
                
                // Validate and update distance tracker
                if rawAverageDistance > 5 && rawAverageDistance < 200 {
                    DistanceTracker.shared.addReading(Double(rawAverageDistance))
                }
            }
        }
    }

    /*
     * Calculates Euclidean distance between two 3D points.
     *
     * @param a First point
     * @param b Second point
     * @return Distance between the points in ARKit units
     */
    func SCNVector3Distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        return sqrtf(
            powf(a.x - b.x, 2) +
            powf(a.y - b.y, 2) +
            powf(a.z - b.z, 2)
        )
    }

    /*
     * Sets up the UI elements and their constraints.
     */
    private func setupUI() {
        view.backgroundColor = .white
        
        // Add subviews
        view.addSubview(letterLabel)
        view.addSubview(eyeTestLabel)
        view.addSubview(instructionLabel)
        view.addSubview(warningLabel)
        view.addSubview(checkmarkLabel)
        view.addSubview(moveCloserArrowLabel)
        view.addSubview(moveFartherArrowLabel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Eye test label constraints
            eyeTestLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            eyeTestLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            eyeTestLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Warning and checkmark label constraints
            warningLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            warningLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            checkmarkLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            checkmarkLabel.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 10),
            
            // Letter label constraints
            letterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Instruction label constraints
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Move closer arrow label constraints
            moveCloserArrowLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            moveCloserArrowLabel.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 10),
            moveCloserArrowLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            moveCloserArrowLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Move farther arrow label constraints
            moveFartherArrowLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            moveFartherArrowLabel.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 10),
            moveFartherArrowLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            moveFartherArrowLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
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

    // MARK: - Gesture Handling
    /*
     * Handles a user's swipe gesture and determines if it matches the direction of the letter.
     *
     * @param gesture The UISwipeGestureRecognizer that triggered this action
     */
    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
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
        
        // Animate the letter flying off screen in the swipe direction before processing next trial
        animateLetterFlyOff(direction: gesture.direction) { [weak self] in
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
                        set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: LETTER) // Update the letter size
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
                    set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: LETTER) // Update the letter size
                }
            }
            // Reset trial counter and correct answers count
            trial = 1
            correctAnswersInSet = 0
        }
        generateNewE() // Generate the next letter with updated size or same size
    }
    
    /* Generates a new tumbling E with a random rotation.
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
        // Always print extreme values
        let isExtreme = liveDistance < 15 || liveDistance > 100 ||
                       abs(liveDistance - averageDistanceCM) > 30
        
        if isExtreme || Int(Date().timeIntervalSince1970 * 10) % 10 == 0 {
            let status = isPaused ? "⏸️ PAUSED" : "▶️ RUNNING"
            print("\(status) Distance: \(String(format: "%.1f", liveDistance)) cm | Bounds: \(String(format: "%.1f", lowerBound)) - \(String(format: "%.1f", upperBound)) cm")
        }
        
        // Add hysteresis to prevent frequent toggling at the boundary
        let outOfRangeTolerance = 3.0 // 3cm buffer when already paused (reduced for tighter range)
        
        // Determine user's position relative to acceptable range
        let tooClose = liveDistance < lowerBound
        let tooFar = liveDistance > upperBound
        let inRange = !tooClose && !tooFar
        
        if isPaused {
            // When already paused, require a more definitive return to range
            if liveDistance > (lowerBound + outOfRangeTolerance) && liveDistance < (upperBound - outOfRangeTolerance) {
                isPaused = false
                hideAllDistanceIndicators()
                showDistanceOK()
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
                hideAllDistanceIndicators()
                showDistanceWarning()
                updateDirectionalIndicators(tooClose: tooClose, tooFar: tooFar, distance: liveDistance)
                print("⚠️ PAUSING TEST - Distance Out of Range: \(String(format: "%.1f", liveDistance)) cm")
                pauseTest()
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
            // User is too close - show "move farther" arrow
            moveCloserArrowLabel.isHidden = true
            moveFartherArrowLabel.isHidden = false
            playAudioInstructionIfNeeded("Move farther.")
        } else if tooFar {
            // User is too far - show "move closer" arrow
            moveFartherArrowLabel.isHidden = true
            moveCloserArrowLabel.isHidden = false
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
        warningLabel.isHidden = false
    }
    
    /* Shows the distance OK indicator temporarily.
     */
    private func showDistanceOK() {
        checkmarkLabel.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkmarkLabel.isHidden = true
        }
    }
    
    /* Hides all distance-related indicators.
     */
    private func hideAllDistanceIndicators() {
        warningLabel.isHidden = true
        checkmarkLabel.isHidden = true
        moveCloserArrowLabel.isHidden = true
        moveFartherArrowLabel.isHidden = true
    }
    
    /* Updates the letter size based on current distance if the change is significant enough.
       This provides live scaling while the user is within acceptable distance bounds.
       Uses efficient CALayer transforms instead of font changes for better performance.
       @param currentDistance The current measured distance in centimeters
     */
    private func updateLetterSizeForDistance(_ currentDistance: Double) {
        // Only update if the distance change is significant enough to warrant rescaling
        let distanceChange = abs(currentDistance - lastScalingDistance)
        
        if distanceChange >= scalingDistanceThreshold || lastScalingDistance == 0.0 {
            // Calculate the scale factor based on distance ratio
            // When user moves closer (smaller distance), letters should be smaller
            // When user moves farther (larger distance), letters should be larger
            let targetDistance = averageDistanceCM
            let scaleFactor = CGFloat(currentDistance / targetDistance)
            
            // Only apply transform if scale factor changed significantly
            let scaleChange = abs(scaleFactor - lastScaleFactor)
            if scaleChange > 0.05 || lastScaleFactor == 1.0 {
                // Use transform for efficient scaling without layout changes
                UIView.performWithoutAnimation {
                    self.letterLabel.transform = self.letterLabel.transform.scaledBy(x: scaleFactor / self.lastScaleFactor, y: scaleFactor / self.lastScaleFactor)
                }
                
                lastScaleFactor = scaleFactor
                lastScalingDistance = currentDistance
                
                print("📏 Letter rescaled for distance: \(String(format: "%.1f", currentDistance)) cm (scale: \(String(format: "%.2f", scaleFactor)))")
            }
        }
    }
    
    /* Resets the letter scaling factors when acuity changes.
       This ensures clean scaling for the new acuity level while preserving the calculated font size.
     */
    private func resetLetterScaling() {
        // Reset transform to identity (but preserve the font size set by set_Size_E)
        letterLabel.transform = CGAffineTransform.identity
        lastScaleFactor = 1.0
        lastScalingDistance = 0.0
        
        print("🔄 Letter scaling reset for acuity change (preserving font size)")
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
        instructionLabel.text = "Please swipe in the direction the C is pointing."
        view.isUserInteractionEnabled = true // Re-enable swipes
    }
    
    /* Updates the test based on current distance from the device.
       Called by CADisplayLink for smooth, efficient updates.
       Includes validation and fallback mechanisms for invalid distance readings.
     */
    @objc private func updateLiveDistance() {
        let liveDistance = DistanceTracker.shared.currentDistanceCM  // Get latest live distance
        
        // Validate distance readings
        guard liveDistance > 0 else {
            return // Skip invalid readings
        }
        
        // Only log occasionally to reduce console spam
        let shouldLog = Int(Date().timeIntervalSince1970 * 2) % 20 == 0 // Log every 10 seconds at 2Hz
        
        // CRITICAL FIX: If distance is suspiciously small, use the target distance
        if liveDistance < 10 && averageDistanceCM > 10 {
            if shouldLog {
                print("⚠️ Very close distance detected: \(String(format: "%.1f", liveDistance)) cm (expected ~\(String(format: "%.1f", averageDistanceCM)) cm)")
            }
            
            // For testing purposes, DON'T override with target distance to see if extreme values are detected
            #if DEBUG
            let debugStrictDistanceTesting = true // Set to true to test extreme distance values
            if debugStrictDistanceTesting {
                if shouldLog {
                    print("🔧 DEBUG: Testing with extreme distance value: \(String(format: "%.1f", liveDistance)) cm")
                }
                checkDistance(liveDistance)
                return
            }
            #endif
            
            // Use the target/stored distance instead of the current faulty reading
            DistanceTracker.shared.currentDistanceCM = averageDistanceCM
            return
        }
        
        // Check for very large distances too
        if liveDistance > 100 && averageDistanceCM < 100 {
            if shouldLog {
                print("⚠️ Very far distance detected: \(String(format: "%.1f", liveDistance)) cm (expected ~\(String(format: "%.1f", averageDistanceCM)) cm)")
            }
            
            #if DEBUG
            let debugStrictDistanceTesting = true // Set to true to test extreme distance values
            if debugStrictDistanceTesting {
                if shouldLog {
                    print("🔧 DEBUG: Testing with extreme distance value: \(String(format: "%.1f", liveDistance)) cm")
                }
                checkDistance(liveDistance)
                return
            }
            #endif
        }

        // Process distance check on main thread efficiently
        checkDistance(liveDistance)
    }

    // MARK: - Public Methods
    
    /* Sets the size of the letter based on the visual acuity level and viewing distance.
       Implements the standard ETDRS calculation for optotype sizing.
       This version uses the stored target distance for initial sizing.
       @param oneLetter The UILabel to be sized
       @param desired_acuity The target acuity in 20/x notation
       @param letterText The letter to display
     * @return The text that was displayed or nil if the operation failed
     */
    func set_Size_E(_ oneLetter: UILabel?, desired_acuity: Int, letterText: String?) -> String? {
        return set_Size_E_WithDistance(oneLetter, desired_acuity: desired_acuity, letterText: letterText, distance: averageDistanceCM)
    }
    
    /* Sets the size of the letter based on the visual acuity level and a specific viewing distance.
       Implements the standard ETDRS calculation for optotype sizing.
       This version allows for live distance-based scaling.
       @param oneLetter The UILabel to be sized
       @param desired_acuity The target acuity in 20/x notation
       @param letterText The letter to display
       @param distance The current viewing distance in centimeters
       @return The text that was displayed or nil if the operation failed
     */
    func set_Size_E_WithDistance(_ oneLetter: UILabel?, desired_acuity: Int, letterText: String?, distance: Double) -> String? {
        // Standard ETDRS calculation: 5 arcminutes at 20/20 vision at designated testing distance
        // Visual angle in radians = (size in arcmin / 60) * (pi/180)
        let arcmin_per_letter = 5.0 // Standard size for 20/20 optotype is 5 arcmin
        let visual_angle = ((Double(desired_acuity) / 20.0) * arcmin_per_letter / 60.0) * Double.pi / 180.0
        let scaling_correction_factor = 1.0 / 2.54  // Conversion from inches to cm
        
        // Calculate size at viewing distance using the provided distance
        let scale_factor = distance * tan(visual_angle) * scaling_correction_factor
        
        if let nonNilLetterText = letterText, let oneLetter = oneLetter {
            oneLetter.text = nonNilLetterText
            
            // Adjust size based on scale factor with standard 5:1 width to height ratio
            let labelHeight = scale_factor * ppi
            oneLetter.frame.size = CGSize(width: (labelHeight * 5), height: labelHeight)
            
            // Adjusted font size - reducing by factor of 2 to match physical acuity cards
            // The 0.3 factor (instead of 0.6) accounts for font rendering differences
            let fontSize = 0.3 * oneLetter.frame.height
            oneLetter.font = oneLetter.font.withSize(fontSize)
            
            // Debug output to verify scaling
            print("Test Letter - Acuity: \(desired_acuity), Distance: \(String(format: "%.1f", distance))cm, Visual angle: \(visual_angle), Scale factor: \(scale_factor), Label height: \(labelHeight)px, Font size: \(fontSize)pt")
            
            return nonNilLetterText
        }
        
        return nil
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
        
        // Navigate to the results screen
        
        finalAcuityScore = acuityScore
        logMARValue = finalAcuityScore
        snellenValue = 20 * pow(10, logMARValue)
        
        if eyeNumber == 2 {
            // Store the right eye's results (tested first)
            finalAcuityDictionary[2] = String(format: "LogMAR: %.4f, Snellen: 20/%.0f", logMARValue, snellenValue)
            
            // Set eye number for left eye test (tested second)
            eyeNumber = 1
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let leftInstrucVC = storyboard.instantiateViewController(withIdentifier: "OneEyeInstruc") as? OneEyeInstruc {
                navigationController?.pushViewController(leftInstrucVC, animated: true)
            }
            
        } else {
            // Store the left eye's results (tested second)
            finalAcuityDictionary[1] = String(format: "LogMAR: %.4f, Snellen: 20/%.0f", logMARValue, snellenValue)
            
            performSegue(withIdentifier: "ShowResults", sender: self)
        }
    }

    private func playAudioInstructions() {
        let instructionText = "Swipe in the direction the C opening points."
        SharedAudioManager.shared.playText(instructionText, source: "Vision Test")
    }
    
    // MARK: - Animation Methods
    
    /*
     * Animates the Landolt C letter flying off screen in the direction of the user's swipe.
     * Provides visual feedback that connects the swipe gesture to the letter movement.
     */
    private func animateLetterFlyOff(direction: UISwipeGestureRecognizer.Direction, completion: @escaping () -> Void) {
        // Create a snapshot of the current letter for animation
        guard let letterSnapshot = letterLabel.snapshotView(afterScreenUpdates: false) else {
            // If snapshot fails, just proceed without animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                completion()
            }
            return
        }
        
        // Position the snapshot exactly where the original label is
        letterSnapshot.frame = letterLabel.frame
        letterSnapshot.center = letterLabel.center
        view.addSubview(letterSnapshot)
        
        // Hide the original label during animation
        letterLabel.alpha = 0
        
        // Determine fly-off direction based on user's swipe direction
        let flyDistance: CGFloat = max(view.bounds.width, view.bounds.height) * 1.5
        
        let (deltaX, deltaY): (CGFloat, CGFloat)
        switch direction {
        case .right:
            deltaX = flyDistance
            deltaY = 0
        case .left:
            deltaX = -flyDistance
            deltaY = 0
        case .up:
            deltaX = 0
            deltaY = -flyDistance
        case .down:
            deltaX = 0
            deltaY = flyDistance
        default:
            // Fallback to upward direction for any unexpected cases
            deltaX = 0
            deltaY = -flyDistance
        }
        
        let finalCenter = CGPoint(
            x: letterLabel.center.x + deltaX,
            y: letterLabel.center.y + deltaY
        )
        
        // Animate the letter flying off
        UIView.animate(withDuration: 0.6, delay: 0, options: [.curveEaseIn], animations: {
            letterSnapshot.center = finalCenter
            letterSnapshot.alpha = 0
            letterSnapshot.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        }) { _ in
            // Clean up and restore original label
            letterSnapshot.removeFromSuperview()
            self.letterLabel.alpha = 1
            
            // Call completion after a brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                completion()
            }
        }
    }
}
