//
//  ETDRSViewController.swift
//  Distance Measure Test
//
//  Created by Visual Acuity Test Assistant
//

import UIKit
import DevicePpi
import ARKit
import AVFoundation
import Speech

/* ETDRSViewController class implements a visual acuity test using ETDRS letters.
   The test displays ETDRS letters at various sizes, and the user must speak the
   letter they see. The test maintains a fixed testing distance using AR face tracking.
 */
class ETDRSViewController: UIViewController, ARSCNViewDelegate, SFSpeechRecognizerDelegate {
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
    
    /// Flag to track if the test has actually started (user has provided input)
    private var testStarted = false
    
    /// Timer to restart speech recognition if it gets stuck
    private var speechTimeoutTimer: Timer?
    
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
    
    /// Standard ETDRS letters
    let etdrsLetters = ["C", "D", "F", "H", "K", "N", "P", "R", "U", "V", "Z"]
    
    /// Current letter being displayed
    private var currentLetter: String = ""
    
    // MARK: - Speech Recognition Properties
    
    /// Speech recognizer for voice input
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    /// Audio engine for speech recognition
    private let audioEngine = AVAudioEngine()
    
    /// Speech recognition request
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    /// Speech recognition task
    private var recognitionTask: SFSpeechRecognitionTask?
    
    /// Flag to indicate if speech recognition is active
    private var isListening = false
    
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
        label.text = "Please say the letter you see out loud."
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
    
    // Label showing microphone status
    private lazy var microphoneLabel: UILabel = {
        let label = UILabel()
        label.text = "🎤 Listening..."
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // MARK: - Test Properties
    
    // Number of correct answers
    private var score = 0
    
    // Total number of test attempts
    private var totalAttempts = 0
    
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
       This method sets up the UI elements, initializes speech recognition,
       initializes the current acuity level from the selected value, sets up distance tracking
       and boundaries, initializes AR face tracking for distance monitoring, and sizes the
       test letter appropriately for the current acuity level.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        print("🔍 ETDRSViewController - viewDidLoad started")

        // Set up the basic UI
        view.backgroundColor = .white
        setupUI()
        print("🔍 ETDRSViewController - UI setup completed")

        // Initialize acuity level from the selected value
        initializeAcuityLevel()
        print("🔍 ETDRSViewController - acuity level initialized")
        
        // Set up distance tracking and monitoring
        initializeDistanceTracking()
        print("🔍 ETDRSViewController - distance tracking initialized")
        
        // Set up AR face tracking for distance monitoring
        setupARTracking()
        print("🔍 ETDRSViewController - AR tracking setup completed")
        
        // Set up speech recognition
        setupSpeechRecognition()
        print("🔍 ETDRSViewController - speech recognition setup completed")
        
        // Start monitoring distance with appropriate checks
        startDistanceMonitoring()
        print("🔍 ETDRSViewController - distance monitoring started")

        // Initialize scaling factors
        lastScaleFactor = 1.0
        lastScalingDistance = 0.0
        
        // Add triple-tap gesture to bypass distance checking if needed
        setupEmergencyOverride()
        
        // Add temporary debugging tap gesture
        setupDebugTapGesture()
        
        // Finish layout and generate the first letter
        view.layoutIfNeeded()
        generateNewLetter()
        print("🔍 ETDRSViewController - first letter generated: \(currentLetter)")
        
        // Size the test letter for the current acuity level (after letter is generated)
        set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: currentLetter)
        print("🔍 ETDRSViewController - initial letter size set for acuity: \(acuityList[currentAcuityIndex])")
        
        // Update eye test label based on current eye number
        updateEyeTestLabel()
        
        print("🔍 ETDRSViewController - viewDidLoad completed successfully")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("🔍 ETDRSViewController - viewDidAppear started")
        
        // Play audio instructions for the ETDRS test screen
        playAudioInstructions()
        print("🔍 ETDRSViewController - audio instructions played")
        
        // Start speech recognition
        startListening()
        print("🔍 ETDRSViewController - viewDidAppear completed")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Clean up timers and display link
        audioInstructionTimer?.invalidate()
        audioInstructionTimer = nil
        displayLink?.invalidate()
        displayLink = nil
        
        // Stop speech recognition and timeout timer
        stopListening()
        stopSpeechTimeoutTimer()
    }

    /*
    * Updates the eye test label based on the current eye number.
    */
    private func updateEyeTestLabel() {
        eyeTestLabel.text = eyeNumber == 2 ? "Right Eye Test - ETDRS" : "Left Eye Test - ETDRS"
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
        
        print("📏 ETDRS Target test distance: \(averageDistanceCM) cm")
        
        // Reset current distance to target distance to avoid immediate out-of-range warnings
        // This helps when switching between test types
        DistanceTracker.shared.currentDistanceCM = averageDistanceCM
        print("📏 ETDRS Reset current distance to target: \(averageDistanceCM) cm")
        
        // Set acceptable distance range (±20% of target)
        lowerBound = 0.8 * averageDistanceCM  // 20% below target
        upperBound = 1.2 * averageDistanceCM  // 20% above target
        print("📏 ETDRS Distance bounds set to: \(String(format: "%.1f", lowerBound)) - \(String(format: "%.1f", upperBound)) cm")
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
        view.addSubview(microphoneLabel)
        
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
            
            // Microphone label constraints
            microphoneLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            microphoneLabel.topAnchor.constraint(equalTo: letterLabel.bottomAnchor, constant: 30),
            
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
        print("ETDRSViewController - constraints activated")
    }
    
    // MARK: - Speech Recognition Setup
    
    /*
     * Sets up speech recognition for voice input.
     */
    private func setupSpeechRecognition() {
        speechRecognizer.delegate = self
        
        print("🎤 Setting up speech recognition...")
        print("🎤 Speech recognizer available: \(speechRecognizer.isAvailable)")
        
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch authStatus {
                case .authorized:
                    print("🎤 Speech recognition authorized ✅")
                case .denied:
                    print("🎤 Speech recognition access denied ❌")
                    // Show alert to user
                    self.showSpeechPermissionAlert()
                case .restricted:
                    print("🎤 Speech recognition restricted ❌")
                    self.showSpeechPermissionAlert()
                case .notDetermined:
                    print("🎤 Speech recognition not determined ⚠️")
                @unknown default:
                    print("🎤 Speech recognition unknown authorization status ❓")
                }
            }
        }
    }
    
    /*
     * Shows an alert when speech recognition permission is not available.
     */
    private func showSpeechPermissionAlert() {
        let alert = UIAlertController(
            title: "Speech Recognition Required",
            message: "This ETDRS test requires speech recognition to work. Please enable speech recognition in Settings > Privacy & Security > Speech Recognition.",
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
     * Sets up a temporary debug tap gesture for testing purposes.
     */
    private func setupDebugTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDebugTap))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
        print("🔍 Debug tap gesture added - tap screen to simulate letter input")
    }
    
    /*
     * Handles debug tap to simulate speech input.
     */
    @objc private func handleDebugTap() {
        print("🔍 Debug tap detected - simulating speech input with current letter: \(currentLetter)")
        handleLetterInput(currentLetter) // Simulate correct answer
    }
    
    /*
     * Starts listening for speech input.
     */
    private func startListening() {
        guard !isListening else { 
            print("🎤 Already listening, skipping start")
            return 
        }
        
        // Check speech recognition authorization first
        guard speechRecognizer.isAvailable else {
            print("🎤 Speech recognizer not available")
            return
        }
        
        // Cancel any previous recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("🎤 Audio session configured successfully")
        } catch {
            print("🎤 Audio session setup failed: \(error)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("🎤 Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Get audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Remove any existing taps
        inputNode.removeTap(onBus: 0)
        
        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("🎤 Audio engine started successfully")
        } catch {
            print("🎤 Audio engine start failed: \(error)")
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let spokenText = result.bestTranscription.formattedString.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                print("🎤 Heard: '\(spokenText)' (length: \(spokenText.count))")
                
                // CRITICAL: Filter out sentences and unwanted speech
                if !self.isValidLetterAttempt(spokenText) {
                    print("🎤 ❌ Ignoring: '\(spokenText)' (Not a valid letter attempt)")
                    // Immediately reset speech recognition to clear the transcription
                    self.resetSpeechRecognition()
                    return
                }
                
                // Process input when we have meaningful speech
                if !spokenText.isEmpty {
                    var shouldProcess = false
                    var reason = ""
                    
                    // Check for single letter first (highest priority)
                    if self.containsSingleLetter(spokenText) {
                        reason = "Single letter detected"
                        shouldProcess = true
                    }
                    // Check for common phonetic words that we know map to letters
                    else if spokenText.count <= 7 { // Reasonable length for phonetic words
                        let commonPhoneticWords = ["ARE", "YOU", "SEE", "DEE", "EFF", "AITCH", "KAY", "PEE", "VEE", "ZEE"]
                        if commonPhoneticWords.contains(spokenText) {
                            reason = "Common phonetic word detected"
                            shouldProcess = true
                        }
                        // Also try a quick phonetic match check
                        else if self.canPhoneticMatch(spokenText) {
                            reason = "Phonetic match possible"
                            shouldProcess = true
                        }
                    }
                    // For final results, always try to process
                    else if result.isFinal {
                        reason = "Final result"
                        shouldProcess = true
                    }
                    
                    if shouldProcess {
                        print("🎤 Processing: '\(spokenText)' (\(reason))")
                        self.processSpokenInput(spokenText)
                        // Stop and restart recognition after processing
                        self.stopListening()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if !isPaused {
                                self.startListening()
                            }
                        }
                        return
                    }
                }
            }
            
            if let error = error {
                print("🎤 Speech recognition error: \(error)")
            }
            
            if error != nil || result?.isFinal == true {
                self.stopListening()
                // Restart listening after a short delay if not paused
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !isPaused {
                        self.startListening()
                    }
                }
            }
        }
        
        isListening = true
        microphoneLabel.isHidden = false
        
        // Start timeout timer to restart recognition if it gets stuck
        startSpeechTimeoutTimer()
        
        print("🎤 Started listening for speech input")
    }
    
    /*
     * Checks if the spoken text contains a single recognizable letter.
     */
    private func containsSingleLetter(_ text: String) -> Bool {
        let letters = text.filter { $0.isLetter }
        return letters.count == 1 && etdrsLetters.contains(String(letters))
    }
    
    /*
     * Checks if the spoken text can be phonetically matched to an ETDRS letter.
     */
    private func canPhoneticMatch(_ text: String) -> Bool {
        // Quick check to see if phonetic matching would succeed
        return phoneticMatch(for: text) != nil
    }
    
    /*
     * Validates if the spoken text is a valid letter attempt and not a sentence.
     * This prevents the app from processing conversation or long sentences.
     */
    private func isValidLetterAttempt(_ text: String) -> Bool {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty text is invalid
        if cleanText.isEmpty {
            return false
        }
        
        // RULE 1: Length filter - reject very long text (likely sentences)
        if cleanText.count > 15 {
            print("🎤 🚫 Sentence filter: Text too long (\(cleanText.count) chars)")
            return false
        }
        
        // RULE 1.5: Letter count filter - reject if more than 5 letters detected
        let letterCount = cleanText.filter { $0.isLetter }.count
        if letterCount > 5 {
            print("🎤 🚫 Sentence filter: Too many letters (\\(letterCount) letters)")
            return false
        }
        
        // RULE 2: Word count filter - reject multiple words (likely sentences)
        let words = cleanText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count > 4 {
            print("🎤 🚫 Sentence filter: Too many words (\(words.count) words)")
            return false
        }
        
        // RULE 3: Common sentence starters - reject obvious conversation
        let sentenceStarters = ["WAIT", "I", "SHOULD", "CAN", "COULD", "WILL", "WOULD", "MAYBE", "PERHAPS", "LET", "LETS", "PLEASE", "EXCUSE", "SORRY", "HI", "HELLO", "YES", "NO", "OKAY", "WELL", "SO", "BUT", "OR", "THE", "A", "AN", "THIS", "THAT", "THESE", "THOSE", "MY", "YOUR", "HIS", "HER", "OUR", "THEIR", "WE", "THEY", "SHE", "HE", "IT", "THERE", "HERE", "NOW", "THEN", "WHEN", "WHERE", "WHY", "HOW", "WHAT", "WHO", "WHICH"]
        let firstWord = words.first ?? ""
        if sentenceStarters.contains(firstWord) {
            print("🎤 🚫 Sentence filter: Conversation starter detected: '\(firstWord)'")
            return false
        }
        
        // RULE 4: Common sentence patterns - reject obvious conversation
        let sentencePatterns = [
            "I SHOULD", "WAIT I", "CAN YOU", "COULD YOU", "WILL YOU", "WOULD YOU",
            "LET ME", "LETS", "PLEASE", "EXCUSE ME", "I THINK", "I BELIEVE",
            "MAYBE", "PERHAPS", "PROBABLY", "DEFINITELY", "CERTAINLY",
            "WAIT I SHOULD", "I SHOULD PROBABLY", "SHOULD PROBABLY", "PROBABLY DO",
            "DO ONE", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN"
        ]
        for pattern in sentencePatterns {
            if cleanText.hasPrefix(pattern) || cleanText.contains(pattern) {
                print("🎤 🚫 Sentence filter: Conversation pattern detected: '\(pattern)'")
                return false
            }
        }
        
        // RULE 5: Question patterns - reject questions
        if cleanText.contains("?") || 
           cleanText.hasPrefix("WHAT") || 
           cleanText.hasPrefix("WHERE") || 
           cleanText.hasPrefix("WHEN") || 
           cleanText.hasPrefix("WHY") || 
           cleanText.hasPrefix("WHO") || 
           cleanText.hasPrefix("HOW") ||
           cleanText.hasPrefix("DO YOU") ||
           cleanText.hasPrefix("DID YOU") ||
           cleanText.hasPrefix("ARE YOU") ||
           cleanText.hasPrefix("CAN YOU") {
            print("🎤 🚫 Sentence filter: Question detected")
            return false
        }
        
        // RULE 5.5: Numbers and counting - reject number sequences
        let numberWords = ["ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN", "TWELVE", "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN", "SEVENTEEN", "EIGHTEEN", "NINETEEN", "TWENTY"]
        for numberWord in numberWords {
            if words.contains(numberWord) && words.count > 1 {
                print("🎤 🚫 Sentence filter: Number in context detected: '\(numberWord)'")
                return false
            }
        }
        
        // RULE 6: Allow single letters (highest priority)
        if cleanText.count == 1 && cleanText.first?.isLetter == true {
            print("🎤 ✅ Valid: Single letter '\(cleanText)'")
            return true
        }
        
        // RULE 7: Allow known phonetic words for ETDRS letters
        let validPhoneticWords = [
            // Direct phonetic pronunciations
            "ARE", "YOU", "SEE", "SEA", "DEE", "EFF", "AITCH", "KAY", "PEE", "VEE", "ZEE",
            // Alternative pronunciations
            "EACH", "AND", "OK", "OH", "HE", "FEE", "ED", "DZ", "VV", "CC", "DD", "FF", 
            "HH", "KK", "NN", "PP", "RR", "UU", "ZZ",
            // Short combinations that might be phonetic attempts
            "AR", "ARR", "EN", "AFF", "ATCH", "AYCH", "SI", "SII", "DI", "DIA"
        ]
        
        if validPhoneticWords.contains(cleanText) {
            print("🎤 ✅ Valid: Known phonetic word '\(cleanText)'")
            return true
        }
        
        // RULE 8: Allow very short text that might contain letters
        if cleanText.count <= 3 {
            // Check if it contains any ETDRS letters
            let containsETDRSLetter = etdrsLetters.contains { letter in
                cleanText.contains(letter)
            }
            if containsETDRSLetter {
                print("🎤 ✅ Valid: Short text with ETDRS letter '\(cleanText)'")
                return true
            }
        }
        
        // RULE 9: Reject everything else (likely conversation)
        print("🎤 🚫 Sentence filter: Rejected as conversation: '\(cleanText)'")
        return false
    }
    
    /*
     * Stops listening for speech input.
     */
    private func stopListening() {
        guard isListening else { 
            print("🎤 Not listening, skipping stop")
            return 
        }
        
        print("🎤 Stopping speech recognition...")
        
        // Stop audio engine first
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap safely
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // End recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        microphoneLabel.isHidden = true
        
        // Stop the timeout timer
        stopSpeechTimeoutTimer()
        
        print("🎤 Stopped listening for speech input")
    }
    
    /*
     * Processes the spoken input from the user.
     */
    private func processSpokenInput(_ spokenText: String) {
        print("🎤 processSpokenInput called with: '\(spokenText)'")
        
        // Try phonetic matching first (this handles "ARE" → "R" cases)
        var recognizedLetter = phoneticMatch(for: spokenText)
        if recognizedLetter != nil {
            print("🎤 Found phonetic match: \(recognizedLetter!) from '\(spokenText)'")
        } else {
            // Extract single letters from the spoken text as fallback
            let letters = spokenText.filter { $0.isLetter }
            print("🎤 Filtered letters: '\(letters)'")
            
            // Look for ETDRS letters in the spoken text
            for letter in etdrsLetters {
                if letters.contains(letter) {
                    recognizedLetter = letter
                    print("🎤 Found direct letter match: \(letter)")
                    break
                }
            }
        }
        
        if let letter = recognizedLetter {
            print("🎤 ✅ Recognized letter: \(letter) for current letter: \(currentLetter)")
            handleLetterInput(letter)
        } else {
            print("🎤 ❌ Could not recognize a valid ETDRS letter from: '\(spokenText)'")
            print("🎤 💡 Try saying the letter name clearly: \(currentLetter)")
        }
    }
    
    /*
     * Attempts to match spoken text to ETDRS letters using comprehensive phonetic matching.
     * Uses a multi-layered approach to handle all speech recognition variations.
     */
    private func phoneticMatch(for spokenText: String) -> String? {
        let text = spokenText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        print("🎤 Phonetic matching for: '\(text)'")
        
        // === LAYER 1: EXACT PHONETIC MAPPINGS ===
        // Most common and reliable phonetic transcriptions
        let exactPhoneticMap: [String: String] = [
            // C - commonly transcribed as "see", "sea"
            "see": "C", "sea": "C", "cee": "C", "si": "C", "c": "C",
            
            // D - commonly transcribed as "dee"
            "dee": "D", "di": "D", "d": "D", "de": "D", "dear": "D",
            
            // F - commonly transcribed as "ef", "eff"
            "ef": "F", "eff": "F", "f": "F", "aff": "F",
            
            // H - commonly transcribed as "aitch", "atch"
            "aitch": "H", "atch": "H", "aych": "H", "h": "H",
            "haitch": "H", "eitch": "H",
            
            // K - commonly transcribed as "kay", "key"
            "kay": "K", "key": "K", "k": "K", "kei": "K",
            
            // N - commonly transcribed as "en", "enn" 
            "en": "N", "enn": "N", "n": "N", "ne": "N",
            
            // P - commonly transcribed as "pee", "pi"
            "pee": "P", "pi": "P", "p": "P", "pe": "P",
            
            // R - commonly transcribed as "are", "ar" 
            "are": "R", "ar": "R", "arr": "R", "or": "R", "r": "R",
            
            // U - commonly transcribed as "you", "yu"
            "you": "U", "yu": "U", "u": "U", "yoo": "U",
            
            // V - commonly transcribed as "vee", "vi"
            "vee": "V", "vi": "V", "v": "V", "ve": "V", "we": "V",
            
            // Z - commonly transcribed as "zee", "zed"
            "zee": "Z", "zed": "Z", "zi": "Z", "z": "Z"
        ]
        
        // === LAYER 2: ALTERNATIVE PHONETIC MAPPINGS ===
        // Less common but still valid transcriptions
        let alternativePhoneticMap: [String: String] = [
            // C alternatives
            "sie": "C", "sii": "C", "ce": "C", "sea sea": "C",
            
            // D alternatives  
            "dea": "D", "dia": "D", "dii": "D", "the": "D", "tea": "D",
            
            // F alternatives
            "eph": "F", "aef": "F", "afe": "F", "fe": "F", "if": "F",
            
            // H alternatives
            "ache": "H", "hatch": "H", "itch": "H", "each": "H",
            "age": "H", "hey": "H", "hay": "H", "eight": "H", "ate": "H",
            
            // K alternatives
            "ca": "K", "cay": "K", "kae": "K", "kai": "K", "que": "K",
            "okay": "K", "ok": "K", "kway": "K",
            
            // N alternatives
            "an": "N", "ene": "N", "inn": "N", "and": "N", "ain": "N",
            
            // P alternatives
            "pea": "P", "pia": "P", "pie": "P", "pii": "P",
            
            // R alternatives
            "aar": "R", "aire": "R", "er": "R", "ore": "R", "arre": "R",
            "our": "R", "hour": "R", "air": "R", "heir": "R", "ah": "R",
            
            // U alternatives  
            "oo": "U", "ooo": "U", "uu": "U", "ou": "U", "yew": "U",
            "ewe": "U", "hugh": "U", "hue": "U", "ew": "U", "ooh": "U",
            "who": "U", "woo": "U", "wu": "U", "ue": "U",
            
            // V alternatives
            "vea": "V", "via": "V", "vie": "V", "vii": "V", "bee": "V",
            
            // Z alternatives
            "zea": "Z", "zia": "Z", "ze": "Z", "zeta": "Z", "said": "Z"
        ]
        
        // === LAYER 3: REPEATED LETTER PATTERNS ===
        // Handle cases like "RRR", "CCC", etc.
        let repeatedPatternMap: [String: String] = [
            "cc": "C", "ccc": "C", "cccc": "C",
            "dd": "D", "ddd": "D", "dddd": "D", 
            "ff": "F", "fff": "F", "ffff": "F",
            "hh": "H", "hhh": "H", "hhhh": "H",
            "kk": "K", "kkk": "K", "kkkk": "K",
            "nn": "N", "nnn": "N", "nnnn": "N",
            "pp": "P", "ppp": "P", "pppp": "P",
            "rr": "R", "rrr": "R", "rrrr": "R",
            "uu": "U", "uuu": "U", "uuuu": "U",
            "vv": "V", "vvv": "V", "vvvv": "V",
            "zz": "Z", "zzz": "Z", "zzzz": "Z"
        ]
        
        // === MATCHING ALGORITHM ===
        
        // STEP 1: Check exact phonetic matches (highest priority)
        if let letter = exactPhoneticMap[text] {
            print("🎤 ✅ Layer 1 - Exact phonetic match: '\(text)' → '\(letter)'")
            return letter
        }
        
        // STEP 2: Check alternative phonetic matches
        if let letter = alternativePhoneticMap[text] {
            print("🎤 ✅ Layer 2 - Alternative phonetic match: '\(text)' → '\(letter)'")
            return letter
        }
        
        // STEP 3: Check repeated letter patterns
        if let letter = repeatedPatternMap[text] {
            print("🎤 ✅ Layer 3 - Repeated pattern match: '\(text)' → '\(letter)'")
            return letter
        }
        
        // STEP 4: Check if text contains any exact phonetic patterns
        let allMaps = [exactPhoneticMap, alternativePhoneticMap, repeatedPatternMap]
        for (mapIndex, map) in allMaps.enumerated() {
            // Sort by length (longer patterns first) to avoid partial matches
            let sortedPhonetics = map.keys.sorted { $0.count > $1.count }
            
            for phonetic in sortedPhonetics {
                if text.contains(phonetic) {
                    let letter = map[phonetic]!
                    print("🎤 ✅ Layer \(mapIndex + 1) - Contains pattern: '\(text)' contains '\(phonetic)' → '\(letter)'")
                    return letter
                }
            }
        }
        
        // STEP 5: Single letter direct match
        if text.count == 1 && text.first!.isLetter {
            let letter = text.uppercased()
            if etdrsLetters.contains(letter) {
                print("🎤 ✅ Direct single letter match: '\(text)' → '\(letter)'")
                return letter
            }
        }
        
        // STEP 6: Check for repeated single letters (like "RRR" → "R")
        if text.count > 1 {
            let uniqueLetters = Set(text.filter { $0.isLetter })
            if uniqueLetters.count == 1, let singleLetter = uniqueLetters.first {
                let letter = String(singleLetter).uppercased()
                if etdrsLetters.contains(letter) {
                    print("🎤 ✅ Repeated letter match: '\(text)' → '\(letter)'")
                    return letter
                }
            }
        }
        
        // STEP 7: Fuzzy matching for edge cases
        return fuzzyPhoneticMatch(for: text)
    }
    
    /*
     * Advanced fuzzy matching for edge cases and unusual transcriptions.
     */
    private func fuzzyPhoneticMatch(for text: String) -> String? {
        // Handle edge cases where letters might be transcribed as words
        let edgeCaseMap: [String: String] = [
            // Common word confusions
            "why": "Y", "wine": "Y", "y": "Y",
            "ex": "X", "x": "X", "axe": "X",
            "oh": "O", "zero": "O", "o": "O",
            "be": "B", "bee": "B", "b": "B",
            "tea": "T", "tee": "T", "t": "T",
            "em": "M", "m": "M",
            "el": "L", "l": "L", "elle": "L",
            "jay": "J", "j": "J",
            "eye": "I", "i": "I", "aye": "I",
            "gee": "G", "g": "G",
            "a": "A", "ay": "A", "hey": "A",
            "queue": "Q", "q": "Q", "cue": "Q",
            "yes": "S", "s": "S", "ess": "S",
            "double you": "W", "w": "W",
        ]
        
        if let letter = edgeCaseMap[text] {
            // Only return if it's an ETDRS letter
            if etdrsLetters.contains(letter) {
                print("🎤 ✅ Fuzzy match: '\(text)' → '\(letter)'")
                return letter
            }
        }
        
        print("🎤 ❌ No phonetic match found for: '\(text)'")
        return nil
    }

    // MARK: - Letter Input Handling
    /*
     * Handles a letter input from speech recognition and determines if it matches the current letter.
     *
     * @param inputLetter The letter recognized from speech
     */
    private func handleLetterInput(_ inputLetter: String) {
        // Mark test as started on first input
        testStarted = true
        
        var isCorrect = 0
        
        if inputLetter == currentLetter {
            isCorrect = 1
            score += 1
            correctAnswersInSet += 1 // Track correct answers in the current set of 10
        } else {
            isCorrect = 0
        }
        
        totalAttempts += 1
        trial += 1 // Increment the trial count within this set
        
        print("🎯 Letter: \(currentLetter), Input: \(inputLetter), Correct: \(isCorrect == 1)")
        
        // Animate the letter flying off screen before processing next trial
        animateLetterFlyOff { [weak self] in
            self?.processNextTrial()
        }
    }
    
    /* Processes the current trial state and determines the next steps in the test.
       This method is called after each user response and handles tracking correct answers,
       determining acuity level changes, calculating final scores, and resetting trial counters.
     */
    private func processNextTrial() {
        print("🔍 ETDRS processNextTrial called - trial:", trial, "correctAnswersInSet:",correctAnswersInSet, "testStarted:", testStarted)
        
        // Don't process trials until the test has actually started with user input
        guard testStarted else {
            print("🔍 ETDRS: Test not started yet, skipping processNextTrial")
            return
        }
        
        let acuity = acuityList[currentAcuityIndex]
        correctAnswersAcrossAcuityLevels[acuity] = correctAnswersInSet
        print("correctAnswersAcrossAcuityLevels:", correctAnswersAcrossAcuityLevels)
        print("currentAcuityIndex:", currentAcuityIndex, "acuity:", acuity)
        
        // Check if trial count has reached 10 or if the user has first 5 correct
        if (trial > 10) || ((trial == SKIP + 1) && (correctAnswersInSet == SKIP)) {
            print("🔍 ETDRS: Ending acuity level - trial > 10 or skip condition met")
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
                        set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: currentLetter) // Update the letter size
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
                    set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: currentLetter) // Update the letter size
                }
            }
            // Reset trial counter and correct answers count
            trial = 1
            correctAnswersInSet = 0
        }
        generateNewLetter() // Generate the next letter with updated size or same size
    }
    
    /* Generates a new ETDRS letter randomly.
     */
    private func generateNewLetter() {
        // Select a random ETDRS letter
        currentLetter = etdrsLetters.randomElement() ?? "C"
        letterLabel.text = currentLetter
        
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
        instructionLabel.text = "Please say the letter you see out loud."
        startListening()
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
        print("🔍 ETDRS calculateScore called - this should only happen at the end of the test!")
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
                print("🔍 ETDRS: Navigating to left eye instructions after right eye completion")
            }
            
        } else {
            // Store the left eye's results (tested second)
            finalAcuityDictionary[1] = String(format: "LogMAR: %.4f, Snellen: 20/%.0f", logMARValue, snellenValue)
            
            performSegue(withIdentifier: "ShowResults", sender: self)
            print("🔍 ETDRS: Navigating to results after left eye completion")
        }
    }

    private func playAudioInstructions() {
        let instructionText = "Say the letter you see."
        SharedAudioManager.shared.playText(instructionText, source: "ETDRS Vision Test")
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("🎤 Speech recognizer availability changed: \(available)")
    }
    
    // MARK: - Speech Timeout Management
    
    /*
     * Starts a timer to restart speech recognition if it gets stuck or disrupted.
     */
    private func startSpeechTimeoutTimer() {
        stopSpeechTimeoutTimer() // Clear any existing timer
        
        speechTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("🎤 ⏰ Speech recognition timeout - restarting...")
            
            if self.isListening {
                self.stopListening()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !isPaused {
                        self.startListening()
                    }
                }
            }
        }
    }
    
    /*
     * Stops the speech timeout timer.
     */
    private func stopSpeechTimeoutTimer() {
        speechTimeoutTimer?.invalidate()
        speechTimeoutTimer = nil
    }
    
    /*
     * Immediately resets speech recognition to clear unwanted transcription.
     * Used when sentences or invalid input is detected.
     */
    private func resetSpeechRecognition() {
        print("🎤 🔄 Resetting speech recognition due to invalid input")
        
        // Stop current recognition
        stopListening()
        
        // Restart immediately to clear the transcription buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if !isPaused {
                self.startListening()
            }
        }
    }
    
    // MARK: - Animation Methods
    
    /*
     * Animates the letter flying off screen with a smooth transition.
     * Provides visual feedback when a letter response is completed.
     */
    private func animateLetterFlyOff(completion: @escaping () -> Void) {
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
        
        // Determine random fly-off direction
        let directions: [(x: CGFloat, y: CGFloat)] = [
            (x: -view.bounds.width, y: -200),  // Up-left
            (x: view.bounds.width, y: -200),   // Up-right
            (x: -view.bounds.width, y: 200),   // Down-left
            (x: view.bounds.width, y: 200),    // Down-right
            (x: 0, y: -view.bounds.height),    // Straight up
            (x: 0, y: view.bounds.height)      // Straight down
        ]
        
        let randomDirection = directions.randomElement()!
        let finalCenter = CGPoint(
            x: letterLabel.center.x + randomDirection.x,
            y: letterLabel.center.y + randomDirection.y
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


