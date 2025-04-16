//
//  TumblingEViewController.swift
//  Distance Measure Test
//
//  Created by Maggie Bao on 7/23/24.
//

import UIKit
import DevicePpi
import ARKit

// MARK: - Global Variables

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

/**
 * TumblingEViewController
 *
 * This class implements a visual acuity test using a tumbling E paradigm.
 * The test displays a rotated "C" letter at various sizes, and the user 
 * must swipe in the direction the C is pointing. The test maintains
 * a fixed testing distance using AR face tracking.
 */
class TumblingEViewController: UIViewController, ARSCNViewDelegate {
    // MARK: - Properties
    
    /// AR scene view for face tracking
    var sceneView: ARSCNView!
    
    /// 3D node for left eye tracking
    var leftEye: SCNNode!
    
    /// 3D node for right eye tracking
    var rightEye: SCNNode!
    
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
    
    /// Label displaying the tumbling C for the vision test
    private lazy var letterLabel: UILabel = {
        let label = UILabel()
        label.text = LETTER
        label.font = UIFont(name: "Sloan", size: 100)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// Label indicating which eye is being tested
    private lazy var eyeTestLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    /// Label displaying instructions to the user
    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Please swipe in the direction the C is pointing."
        label.font = UIFont.systemFont(ofSize: 27, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    /// Label warning the user about incorrect distance
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

    /// Label indicating distance is acceptable
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
    
    // MARK: - Test Properties
    
    /// Current rotation angle of the letter (in degrees)
    private var currentRotation: Double = 0
    
    /// Number of correct answers
    private var score = 0
    
    /// Total number of test attempts
    private var totalAttempts = 0
    
    /// Available rotation angles for the letter (right, down, left, up)
    private let possibleRotations = [0.0, 90.0, 180.0, 270.0]
    
    // MARK: - Lifecycle Methods
    
    /**
     * Initializes the view and sets up the test environment.
     * 
     * This method:
     * - Sets up the UI elements
     * - Configures gesture recognizers for user input
     * - Initializes the current acuity level from the selected value
     * - Sets up distance tracking and boundaries
     * - Initializes AR face tracking for distance monitoring
     * - Sizes the test letter appropriately for the current acuity level
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
        
        // Add triple-tap gesture to bypass distance checking if needed
        setupEmergencyOverride()
        
        // Finish layout and generate the first rotated letter
        view.layoutIfNeeded()
        generateNewE()
    }

    /**
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
    
    /**
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
        
        // Set acceptable distance range (±40% of target)
        lowerBound = 0.6 * averageDistanceCM  // 40% below target
        upperBound = 1.4 * averageDistanceCM  // 40% above target
        print("Distance bounds set to: \(String(format: "%.1f", lowerBound)) - \(String(format: "%.1f", upperBound)) cm")
    }
    
    /**
     * Sets up an emergency override gesture (triple tap) to bypass
     * distance checking if the user encounters persistent distance issues.
     */
    private func setupEmergencyOverride() {
        // Setup override gesture - triple tap to bypass distance checking
        let tripleTap = UITapGestureRecognizer(target: self, action: #selector(handleTripleTap))
        tripleTap.numberOfTapsRequired = 3
        view.addGestureRecognizer(tripleTap)
    }

    /**
     * Handles the triple-tap gesture to bypass distance checking.
     * This is an emergency override for when distance detection is problematic.
     */
    @objc private func handleTripleTap() {
        isPaused = false
        warningLabel.isHidden = true
        checkmarkLabel.isHidden = false
        
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
        
        print("🔧 Distance check bypassed via triple tap")
        
        // Resume the test
        resumeTest()
        
        // Remove the message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            overrideLabel.removeFromSuperview()
        }
    }

    /**
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

    /**
     * Initiates distance monitoring with optional debug features.
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
        
        // Use a more frequent timer for more responsive distance checks
        Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(updateLiveDistance), userInfo: nil, repeats: true)
    }

    /**
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
    
    /**
     * Called when an AR anchor is updated in the scene.
     * Updates eye positions and calculates distance from the device.
     */
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        // Update eye transforms
        leftEye.simdTransform = faceAnchor.leftEyeTransform
        rightEye.simdTransform = faceAnchor.rightEyeTransform

        // Get camera position
        guard let frame = sceneView.session.currentFrame else { return }
        let cameraTransform = frame.camera.transform
        
        // Process ALL updates for better responsiveness to fast movements
        DispatchQueue.main.async { [weak self] in
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
                
                // Apply a raw conversion factor to cm
                let rawAverageDistance = (leftEyeDistance + rightEyeDistance) / 2 * 100
                
                // Use a more aggressive threshold for extreme movements
                let extremeDistanceThreshold = 20.0 // cm
                
                // Check if the distance is extremely different from target (possibly rapid movement)
                let distanceDifference = abs(Double(rawAverageDistance) - averageDistanceCM)
                let isExtremeMovement = distanceDifference > extremeDistanceThreshold
                
                if isExtremeMovement {
                    // Log extreme movements immediately to help with debugging
                    print("⚠️ EXTREME MOVEMENT DETECTED: \(String(format: "%.1f", rawAverageDistance)) cm (Target: \(String(format: "%.1f", averageDistanceCM)) cm)")
                    
                    // Update distance immediately for extreme movements
                    DistanceTracker.shared.addReading(Double(rawAverageDistance))
                    
                    // Force distance check for extreme movement
                    self.checkDistance(Double(rawAverageDistance))
                } else {
                    // Normal processing for moderate movements
                    DistanceTracker.shared.addReading(Double(rawAverageDistance))
                    
                    // Print distance more often during testing phase
                    if Int(Date().timeIntervalSince1970 * 10) % 10 == 0 {
                        print("📏 Distance: \(String(format: "%.1f", Double(rawAverageDistance))) cm | Target: \(String(format: "%.1f", averageDistanceCM)) cm")
                    }
                }
            } else {
                // Print warning when face tracking is lost
                if Int(Date().timeIntervalSince1970 * 10) % 30 == 0 {
                    print("⚠️ Face tracking unstable - eye positions invalid")
                }
            }
        }
    }

    /**
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

    /**
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
        
        // Update eye test label text based on current eye
        eyeTestLabel.text = eyeNumber == 1 ? "Left Eye Test" : "Right Eye Test"
        
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
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        print("TumblingEViewController - constraints activated")
    }
    
    /**
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
    /**
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
        
        // Visual feedback
        letterLabel.textColor = isCorrect == 1 ? .green : .red
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.letterLabel.textColor = .black
            self?.processNextTrial()
        }
    }
    
    /**
     * Processes the current trial state and determines the next steps in the test.
     * 
     * This method is called after each user response and handles:
     * - Tracking correct answers for the current acuity level
     * - Determining if the test should advance to a smaller letter size
     * - Determining if the test should revert to a larger letter size
     * - Calculating the final score if appropriate conditions are met
     * - Resetting trial counters when changing acuity levels
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
                    set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: LETTER) // Update the letter size
                }
            }
            // Reset trial counter and correct answers count
            trial = 1
            correctAnswersInSet = 0
        }
        generateNewE() // Generate the next letter with updated size or same size
    }
    
    /**
     * Generates a new tumbling E with a random rotation.
     * Animates the rotation of the letter to one of four possible orientations.
     */
    private func generateNewE() {
        currentRotation = possibleRotations.randomElement() ?? 0
        UIView.animate(withDuration: 0.1) {
            self.letterLabel.transform = CGAffineTransform(rotationAngle: CGFloat(self.currentRotation) * .pi / 180)
        }
    }
    
    /**
     * Prepares for navigation to the results screen.
     * Passes the final score data to the destination view controller.
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowResults",
           let resultVC = segue.destination as? ResultViewController {
            resultVC.score = score
            resultVC.totalAttempts = totalAttempts
        }
    }

    /**
     * Checks if the user's distance from the device is within acceptable bounds.
     * Implements hysteresis to prevent frequent toggling between paused/unpaused states.
     * 
     * @param liveDistance The current measured distance in centimeters
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
        let outOfRangeTolerance = 5.0 // 5cm buffer when already paused
        
        if isPaused {
            // When already paused, require a more definitive return to range
            if liveDistance > (lowerBound + outOfRangeTolerance) && liveDistance < (upperBound - outOfRangeTolerance) {
                isPaused = false
                warningLabel.isHidden = true
                checkmarkLabel.isHidden = false
                print("✅ RESUMING TEST - Distance Back in Range: \(String(format: "%.1f", liveDistance)) cm")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.checkmarkLabel.isHidden = true
                }
                resumeTest()
            }
        } else {
            // When not paused, use standard bounds
            if liveDistance < lowerBound || liveDistance > upperBound {
                isPaused = true
                warningLabel.isHidden = false
                checkmarkLabel.isHidden = true
                print("⚠️ PAUSING TEST - Distance Out of Range: \(String(format: "%.1f", liveDistance)) cm")
                pauseTest()
            }
        }
    }

    /**
     * Pauses the visual acuity test when the user is not at the proper distance.
     * Updates UI elements and disables user interaction.
     */
    private func pauseTest() {
        instructionLabel.text = "Paused: Adjust your distance"
        view.isUserInteractionEnabled = false // Disable swipes
    }

    /**
     * Resumes the visual acuity test when the user returns to the proper distance.
     * Updates UI elements and re-enables user interaction.
     */
    private func resumeTest() {
        instructionLabel.text = "Please swipe in the direction the C is pointing."
        view.isUserInteractionEnabled = true // Re-enable swipes
    }
    
    /**
     * Updates the test based on current distance from the device.
     * Called by a timer to continuously check the user's distance.
     * Includes validation and fallback mechanisms for invalid distance readings.
     */
    @objc private func updateLiveDistance() {
        let liveDistance = DistanceTracker.shared.currentDistanceCM  // Get latest live distance
        
        // CRITICAL FIX: If distance is suspiciously small, use the target distance
        if liveDistance < 10 && averageDistanceCM > 10 {
            print("⚠️ Very close distance detected: \(String(format: "%.1f", liveDistance)) cm (expected ~\(String(format: "%.1f", averageDistanceCM)) cm)")
            
            // For testing purposes, DON'T override with target distance to see if extreme values are detected
            #if DEBUG
            let debugStrictDistanceTesting = true // Set to true to test extreme distance values
            if debugStrictDistanceTesting {
                print("🔧 DEBUG: Testing with extreme distance value: \(String(format: "%.1f", liveDistance)) cm")
                DispatchQueue.main.async {
                    self.checkDistance(liveDistance)
                }
                return
            }
            #endif
            
            // Use the target/stored distance instead of the current faulty reading
            DistanceTracker.shared.currentDistanceCM = averageDistanceCM
            return
        }
        
        // Check for very large distances too
        if liveDistance > 100 && averageDistanceCM < 100 {
            print("⚠️ Very far distance detected: \(String(format: "%.1f", liveDistance)) cm (expected ~\(String(format: "%.1f", averageDistanceCM)) cm)")
            
            #if DEBUG
            let debugStrictDistanceTesting = true // Set to true to test extreme distance values
            if debugStrictDistanceTesting {
                print("🔧 DEBUG: Testing with extreme distance value: \(String(format: "%.1f", liveDistance)) cm")
                DispatchQueue.main.async {
                    self.checkDistance(liveDistance)
                }
                return
            }
            #endif
        }
        
        // Regular check for other invalid readings
        if liveDistance <= 0 {
            print("⚠️ Invalid distance reading: \(liveDistance) cm")
            return
        }

        DispatchQueue.main.async {
            self.checkDistance(liveDistance)
        }
    }

    // MARK: - Public Methods
    
    /**
     * Sets the size of the letter based on the visual acuity level and viewing distance.
     * Implements the standard ETDRS calculation for optotype sizing.
     * 
     * @param oneLetter The UILabel to be sized
     * @param desired_acuity The target acuity in 20/x notation
     * @param letterText The letter to display
     * @return The text that was displayed or nil if the operation failed
     */
    func set_Size_E(_ oneLetter: UILabel?, desired_acuity: Int, letterText: String?) -> String? {
        // Standard ETDRS calculation: 5 arcminutes at 20/20 vision at designated testing distance
        // Visual angle in radians = (size in arcmin / 60) * (pi/180)
        let arcmin_per_letter = 5.0 // Standard size for 20/20 optotype is 5 arcmin
        let visual_angle = ((Double(desired_acuity) / 20.0) * arcmin_per_letter / 60.0) * Double.pi / 180.0
        let scaling_correction_factor = 1.0 / 2.54  // Conversion from inches to cm
        
        // Calculate size at viewing distance
        let scale_factor = Double(averageDistanceCM) * tan(visual_angle) * scaling_correction_factor
        
        if let nonNilLetterText = letterText, let oneLetter = oneLetter {
            oneLetter.text = nonNilLetterText
            
            // Adjust size based on scale factor with standard 5:1 width to height ratio
            oneLetter.frame.size = CGSize(width: (scale_factor * 5 * ppi), height: (scale_factor * ppi))
            
            // Set the font size proportional to the label size
            oneLetter.font = oneLetter.font.withSize(0.6 * oneLetter.frame.height)
            
            return nonNilLetterText
        }
        
        return nil
    }
    
    /**
     * Find the index of a value in a list.
     * 
     * @param numList The array to search
     * @param value The value to find
     * @return The index of the value or -1 if not found
     */
    func getIndex(numList: [Int], value: Int) -> Int {
        for (index, val) in numList.enumerated() {
            if val == value {
                return index
            }
        }
        return -1
    }
    
    /**
     * Calculates the final acuity score based on performance at two acuity levels.
     * Uses the number of correct/incorrect responses to refine the score.
     * Navigates to the results screen with the final score.
     * 
     * @param finishAcuity1 The first acuity level (20/x notation)
     * @param amtCorrect1 Number of correct responses at first acuity level
     * @param finishAcuity2 The second acuity level (20/x notation)
     * @param amtCorrect2 Number of correct responses at second acuity level
     * @param totalLetters Total number of letters shown at each acuity level
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
        performSegue(withIdentifier: "ShowResults", sender: self)
    }
}
