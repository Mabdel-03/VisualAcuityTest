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
import DevicePpi
import ARKit
import AVFoundation

/* ETDRSViewController class implements a visual acuity test using ETDRS letters.
   The test displays ETDRS letters at various sizes, and the user must speak the
   letter they see. The test maintains a fixed testing distance using AR face tracking.
 */
class ETDRSViewController: UIViewController, ARSCNViewDelegate {
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
    
    /// WhisperKit service for spoken ETDRS letter input
    private let whisperLetterService = ETDRSWhisperLetterService.shared
    
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
        label.drawHeader2()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Label displaying instructions to the user
    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Please say the letter you see out loud."
        label.drawInstruction()
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
    
    // MARK: - Data Collection Properties
    
    /// Time when the current letter was displayed
    private var letterDisplayTime: Date?
    
    /// Data collector for test progression tracking
    private let dataCollector = TestProgressionDataCollector.shared
    
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
        
        
        // Finish layout and generate the first letter
        view.layoutIfNeeded()
        generateNewLetter()
        print("🔍 ETDRSViewController - first letter generated: \(currentLetter)")
        
        // Size the test letter for the current acuity level (after letter is generated)
        set_Size_E(letterLabel, desired_acuity: acuityList[currentAcuityIndex], letterText: currentLetter)
        print("🔍 ETDRSViewController - initial letter size set for acuity: \(acuityList[currentAcuityIndex])")
        
        // Update eye test label based on current eye number
        updateEyeTestLabel()
        
        // Initialize data collection session
        let eyeName = eyeNumber == 2 ? "Right" : "Left"
        dataCollector.startNewSession(eye: eyeName, testType: "ETDRS")
        
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
        guard !isListening else { 
            print("🎤 Already listening, skipping start")
            return 
        }

        isListening = true
        microphoneLabel.isHidden = false
        startSpeechTimeoutTimer()
        print("[ETDRSWhisper] Starting WhisperKit listening for ETDRS letters...")

        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.whisperLetterService.startListening { [weak self] prediction in
                    Task { @MainActor in
                        self?.handleWhisperPrediction(prediction)
                    }
                }
                print("[ETDRSWhisper] Started listening for spoken ETDRS letters")
            } catch {
                print("[ETDRSWhisper] Failed to start listening: \(error.localizedDescription)")
                await MainActor.run {
                    self.isListening = false
                    self.microphoneLabel.isHidden = true
                    self.stopSpeechTimeoutTimer()
                    self.showSpeechPermissionAlert(message: error.localizedDescription)
                }
            }
        }
    }

    private func handleWhisperPrediction(_ prediction: ETDRSWhisperPrediction) {
        guard isListening, !isPaused else { return }
        guard !prediction.rawTranscription.isEmpty else { return }

        print("[ETDRSWhisper] Heard: '\(prediction.rawTranscription)' normalized: \(prediction.normalizedLetter ?? "<none>") latency: \(String(format: "%.2f", prediction.latency))s")

        if prediction.isIgnorableNonAnswer {
            print("[ETDRSWhisper] Ignoring non-answer: '\(prediction.rawTranscription)'")
            return
        }

        if prediction.isFiller {
            print("[ETDRSWhisper] Ignoring filler: '\(prediction.rawTranscription)'")
            return
        }

        guard let letter = prediction.normalizedLetter else {
            print("[ETDRSWhisper] Ignoring unclear transcription: '\(prediction.rawTranscription)'")
            return
        }

        print("[ETDRSWhisper] Processing recognized ETDRS letter: \(letter) for target: \(currentLetter)")
        stopListening()
        handleLetterInput(letter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if !isPaused {
                self.startListening()
            }
        }
    }
    
    /*
     * Stops listening for speech input.
     */
    private func stopListening() {
        guard isListening else { 
            print("🎤 Not listening, skipping stop")
            return 
        }
        
        print("[ETDRSWhisper] Stopping WhisperKit listening...")
        whisperLetterService.stopListening()
        isListening = false
        microphoneLabel.isHidden = true
        
        // Stop the timeout timer
        stopSpeechTimeoutTimer()
        
        print("[ETDRSWhisper] Stopped listening for speech input")
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
        
        // Calculate response time
        let responseTime: Int64
        if let displayTime = letterDisplayTime {
            responseTime = Int64(Date().timeIntervalSince(displayTime) * 1000) // Convert to milliseconds
        } else {
            responseTime = 0 // Fallback if timing wasn't recorded
        }
        
        // Record the response data
        let eyeName = eyeNumber == 2 ? "Right" : "Left"
        let acuityString = "20/\(acuityList[currentAcuityIndex])"
        
        dataCollector.recordResponse(
            eye: eyeName,
            testType: "ETDRS",
            acuityLevel: acuityString,
            letterDisplayed: currentLetter,
            distanceCM: DistanceTracker.shared.currentDistanceCM,
            responseTimeMS: responseTime,
            userResponse: inputLetter,
            isCorrect: isCorrect == 1,
            trialNumber: trial - 1 // trial was already incremented, so subtract 1 for the actual trial number
        )
        
        print("🎯 Letter: \(currentLetter), Input: \(inputLetter), Correct: \(isCorrect == 1)), Time: \(responseTime)ms")
        
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
        
        // Make the letter visible now that the new letter is set
        letterLabel.alpha = 1
        
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
        
        // End the data collection session
        dataCollector.endCurrentSession()
        
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
            // Clean up the snapshot
            letterSnapshot.removeFromSuperview()
            
            // Keep the original label hidden - it will be shown in generateNewLetter after new letter is set
            
            // Call completion after a brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                completion()
            }
        }
    }
}
