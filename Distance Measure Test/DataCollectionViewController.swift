//
//  DataCollectionViewController.swift
//  Distance Measure Test
//
//  Created for Algorithm Optimization
//

import UIKit
import DevicePpi
import ARKit
import AVFoundation
import Speech
import MessageUI

/* DataCollectionViewController implements a data collection system for optimizing
   voice recognition mapping algorithms. Shows extremely large letters (20/200 at 40cm)
   and records user responses, transcriptions, and mapping results.
 */
class DataCollectionViewController: UIViewController, ARSCNViewDelegate, SFSpeechRecognizerDelegate, MFMailComposeViewControllerDelegate {
    
    // MARK: - Properties
    
    /// AR scene view for distance tracking
    var sceneView: ARSCNView!
    
    /// 3D nodes for eye tracking
    var leftEye: SCNNode!
    var rightEye: SCNNode!
    
    /// ETDRS letters for testing
    let etdrsLetters = ["C", "D", "F", "H", "K", "N", "P", "R", "U", "V", "Z"]
    
    /// Current letter being displayed
    private var currentLetter: String = ""
    
    /// Current letter index (0-24 for 25 letters total)
    private var currentLetterIndex = 0
    
    /// Total number of letters to test
    private let totalLetters = 25
    
    /// Data collection array
    private var collectedData: [(letter: String, transcription: String, mapping: String)] = []
    
    /// Fixed distance for data collection (40cm)
    private let fixedDistance: Double = 40.0
    
    /// Fixed acuity level for large letters (20/200)
    private let fixedAcuity: Int = 200
    
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
    
    /// Timer to restart speech recognition if it gets stuck
    private var speechTimeoutTimer: Timer?
    
    // MARK: - UI Elements
    
    // Large letter label for data collection
    private lazy var letterLabel: UILabel = {
        let label = UILabel()
        label.text = "C"
        label.font = UIFont(name: "Sloan", size: 200) // Very large for 20/200 at 40cm
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Title label
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Data Collection Mode"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor(red: 0.820, green: 0.106, blue: 0.376, alpha: 1.0) // #D11B60
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Progress label
    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.text = "Letter 1 of 25"
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Instruction label
    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Say the letter you see out loud."
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    // Microphone status label
    private lazy var microphoneLabel: UILabel = {
        let label = UILabel()
        label.text = "🎤 Listening..."
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // Transcription display label
    private lazy var transcriptionLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .systemGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 2
        return label
    }()
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🔬 DataCollectionViewController - viewDidLoad started")
        
        view.backgroundColor = .white
        setupUI()
        setupARTracking()
        setupSpeechRecognition()
        
        // Generate first letter
        generateNextLetter()
        
        print("🔬 DataCollectionViewController - viewDidLoad completed")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("🔬 DataCollectionViewController - viewDidAppear started")
        
        // Play audio instructions
        playAudioInstructions()
        
        // Start speech recognition
        startListening()
        
        print("🔬 DataCollectionViewController - viewDidAppear completed")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Clean up speech recognition
        stopListening()
        stopSpeechTimeoutTimer()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(progressLabel)
        view.addSubview(letterLabel)
        view.addSubview(instructionLabel)
        view.addSubview(microphoneLabel)
        view.addSubview(transcriptionLabel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Progress label
            progressLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Letter label (center)
            letterLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            letterLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Microphone label
            microphoneLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            microphoneLabel.topAnchor.constraint(equalTo: letterLabel.bottomAnchor, constant: 30),
            
            // Transcription label
            transcriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            transcriptionLabel.topAnchor.constraint(equalTo: microphoneLabel.bottomAnchor, constant: 10),
            transcriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            transcriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Instruction label
            instructionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // Set the letter size for 20/200 at 40cm
        setLetterSizeForDataCollection()
        
        print("🔬 DataCollectionViewController - UI setup completed")
    }
    
    // MARK: - AR Setup
    
    private func setupARTracking() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("⚠️ AR Face Tracking is NOT supported on this device.")
            return
        }

        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.maximumNumberOfTrackedFaces = 1
        
        // Add the scene view but hide it (we don't need visual AR for data collection)
        sceneView.isHidden = true
        view.addSubview(sceneView)
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Initialize eye tracking nodes
        let eyeGeometry = SCNSphere(radius: 0.01)
        eyeGeometry.firstMaterial?.diffuse.contents = UIColor.blue
        
        leftEye = SCNNode(geometry: eyeGeometry)
        rightEye = SCNNode(geometry: eyeGeometry)
        
        print("🔬 AR Face Tracking Started for data collection")
    }
    
    // MARK: - Speech Recognition Setup
    
    private func setupSpeechRecognition() {
        speechRecognizer?.delegate = self
        
        print("🎤 Setting up speech recognition for data collection...")
        
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch authStatus {
                case .authorized:
                    print("🎤 Speech recognition authorized for data collection ✅")
                case .denied, .restricted:
                    print("🎤 Speech recognition access denied/restricted ❌")
                    self.showSpeechPermissionAlert()
                case .notDetermined:
                    print("🎤 Speech recognition not determined ⚠️")
                @unknown default:
                    print("🎤 Speech recognition unknown authorization status ❓")
                }
            }
        }
    }
    
    private func showSpeechPermissionAlert() {
        let alert = UIAlertController(
            title: "Speech Recognition Required",
            message: "Data collection requires speech recognition to work. Please enable speech recognition in Settings.",
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
    
    // MARK: - Speech Recognition Methods
    
    private func startListening() {
        guard !isListening else {
            print("🎤 Already listening, skipping start")
            return
        }
        
        guard speechRecognizer?.isAvailable == true else {
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
            print("🎤 Audio session configured for data collection")
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
            print("🎤 Audio engine started for data collection")
        } catch {
            print("🎤 Audio engine start failed: \(error)")
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let spokenText = result.bestTranscription.formattedString.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Update transcription display
                DispatchQueue.main.async {
                    self.transcriptionLabel.text = "Heard: \"\(spokenText)\""
                }
                
                print("🔬 Data Collection - Heard: '\(spokenText)'")
                
                // For data collection, we want to capture everything, not filter
                if !spokenText.isEmpty && (result.isFinal || spokenText.count >= 1) {
                    self.processSpokenInputForDataCollection(spokenText)
                    return
                }
            }
            
            if let error = error {
                print("🎤 Speech recognition error: \(error)")
            }
            
            if error != nil || result?.isFinal == true {
                self.stopListening()
                // Restart listening for next letter
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.currentLetterIndex < self.totalLetters {
                        self.startListening()
                    }
                }
            }
        }
        
        isListening = true
        microphoneLabel.isHidden = false
        
        // Start timeout timer
        startSpeechTimeoutTimer()
        
        print("🔬 Started listening for data collection")
    }
    
    private func stopListening() {
        guard isListening else {
            print("🎤 Not listening, skipping stop")
            return
        }
        
        print("🎤 Stopping speech recognition...")
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        microphoneLabel.isHidden = true
        
        stopSpeechTimeoutTimer()
        
        print("🎤 Stopped listening for data collection")
    }
    
    // MARK: - Data Collection Processing
    
    private func processSpokenInputForDataCollection(_ spokenText: String) {
        print("🔬 Processing data collection input: '\(spokenText)' for letter: '\(currentLetter)'")
        
        // Get the mapping result using the existing algorithm
        let mappedLetter = phoneticMatch(for: spokenText) ?? extractDirectLetter(from: spokenText)
        let mappingResult = mappedLetter ?? "NO_MATCH"
        
        // Record the data
        let dataPoint = (
            letter: currentLetter,
            transcription: spokenText,
            mapping: mappingResult
        )
        
        collectedData.append(dataPoint)
        
        print("🔬 Data collected - Letter: \(currentLetter), Transcription: \(spokenText), Mapping: \(mappingResult)")
        
        // Stop listening for this letter
        stopListening()
        
        // Move to next letter after a brief pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.moveToNextLetter()
        }
    }
    
    private func extractDirectLetter(from text: String) -> String? {
        let letters = text.filter { $0.isLetter }
        for letter in etdrsLetters {
            if letters.contains(letter) {
                return letter
            }
        }
        return nil
    }
    
    // MARK: - Phonetic Matching (copied from ETDRSViewController)
    
    private func phoneticMatch(for spokenText: String) -> String? {
        let text = spokenText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact phonetic mappings
        let exactPhoneticMap: [String: String] = [
            "see": "C", "sea": "C", "cee": "C", "si": "C", "c": "C",
            "dee": "D", "di": "D", "d": "D", "de": "D",
            "ef": "F", "eff": "F", "f": "F", "aff": "F",
            "aitch": "H", "atch": "H", "aych": "H", "h": "H",
            "kay": "K", "key": "K", "k": "K", "kei": "K",
            "en": "N", "enn": "N", "n": "N", "ne": "N",
            "pee": "P", "pi": "P", "p": "P", "pe": "P",
            "are": "R", "ar": "R", "arr": "R", "or": "R", "r": "R",
            "you": "U", "yu": "U", "u": "U", "yoo": "U",
            "vee": "V", "vi": "V", "v": "V", "ve": "V", "we": "V",
            "zee": "Z", "zed": "Z", "zi": "Z", "z": "Z"
        ]
        
        // Check exact matches first
        if let letter = exactPhoneticMap[text] {
            return letter
        }
        
        // Check if text contains any phonetic patterns
        for (phonetic, letter) in exactPhoneticMap {
            if text.contains(phonetic) {
                return letter
            }
        }
        
        // Single letter direct match
        if text.count == 1 && text.first!.isLetter {
            let letter = text.uppercased()
            if etdrsLetters.contains(letter) {
                return letter
            }
        }
        
        return nil
    }
    
    // MARK: - Letter Management
    
    private func generateNextLetter() {
        // Generate a random ETDRS letter
        currentLetter = etdrsLetters.randomElement() ?? "C"
        letterLabel.text = currentLetter
        
        // Update progress
        progressLabel.text = "Letter \(currentLetterIndex + 1) of \(totalLetters)"
        
        print("🔬 Generated letter \(currentLetterIndex + 1): \(currentLetter)")
    }
    
    private func moveToNextLetter() {
        currentLetterIndex += 1
        
        if currentLetterIndex >= totalLetters {
            // Data collection complete
            completeDataCollection()
        } else {
            // Generate next letter
            generateNextLetter()
            
            // Clear transcription display
            transcriptionLabel.text = ""
            
            // Start listening for the next letter
            startListening()
        }
    }
    
    private func completeDataCollection() {
        print("🔬 Data collection complete! Collected \(collectedData.count) data points")
        
        // Stop any ongoing speech recognition
        stopListening()
        
        // Update UI
        instructionLabel.text = "Data collection complete! Generating report..."
        progressLabel.text = "Complete: \(collectedData.count) letters collected"
        letterLabel.text = "✓"
        transcriptionLabel.text = ""
        
        // Generate and email CSV
        generateAndEmailCSV()
    }
    
    // MARK: - CSV Generation and Email
    
    private func generateAndEmailCSV() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "\(timestamp).csv"
        
        // Generate CSV content
        var csvContent = "Letter_Displayed,Transcribed_Text,Mapped_Result\n"
        
        for dataPoint in collectedData {
            let escapedTranscription = dataPoint.transcription.replacingOccurrences(of: "\"", with: "\"\"")
            csvContent += "\(dataPoint.letter),\"\(escapedTranscription)\",\(dataPoint.mapping)\n"
        }
        
        // Create temporary file
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
            print("🔬 CSV file created: \(fileName)")
            
            // Email the file
            emailCSV(fileURL: tempFileURL, fileName: fileName)
            
        } catch {
            print("🔬 Error creating CSV file: \(error)")
            showErrorAlert(message: "Failed to create CSV file: \(error.localizedDescription)")
        }
    }
    
    private func emailCSV(fileURL: URL, fileName: String) {
        guard MFMailComposeViewController.canSendMail() else {
            print("🔬 Mail not configured on device")
            showErrorAlert(message: "Mail is not configured on this device. Please set up email and try again.")
            return
        }
        
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        
        // Set email details
        mailComposer.setToRecipients(["mabdel03@mit.edu"])
        mailComposer.setSubject("\(fileName) Data Collection")
        mailComposer.setMessageBody("Data collection completed. See attached CSV file with \(collectedData.count) voice recognition samples.", isHTML: false)
        
        // Attach CSV file
        do {
            let csvData = try Data(contentsOf: fileURL)
            mailComposer.addAttachmentData(csvData, mimeType: "text/csv", fileName: fileName)
            print("🔬 CSV attached to email")
        } catch {
            print("🔬 Error attaching CSV: \(error)")
            showErrorAlert(message: "Failed to attach CSV file: \(error.localizedDescription)")
            return
        }
        
        // Present mail composer
        present(mailComposer, animated: true) {
            print("🔬 Mail composer presented")
        }
    }
    
    // MARK: - MFMailComposeViewControllerDelegate
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true) {
            switch result {
            case .sent:
                print("🔬 Email sent successfully")
                self.showSuccessAlert()
            case .cancelled:
                print("🔬 Email cancelled")
                self.showCancelledAlert()
            case .failed:
                print("🔬 Email failed: \(error?.localizedDescription ?? "Unknown error")")
                self.showErrorAlert(message: "Failed to send email: \(error?.localizedDescription ?? "Unknown error")")
            case .saved:
                print("🔬 Email saved to drafts")
                self.showSuccessAlert()
            @unknown default:
                print("🔬 Unknown email result")
            }
        }
    }
    
    // MARK: - Alert Methods
    
    private func showSuccessAlert() {
        let alert = UIAlertController(
            title: "Data Collection Complete",
            message: "Your data has been successfully collected and emailed. Thank you for contributing to algorithm optimization!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Return to Menu", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showCancelledAlert() {
        let alert = UIAlertController(
            title: "Email Cancelled",
            message: "The data has been collected but not emailed. You can try again later.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
            self.generateAndEmailCSV()
        })
        
        alert.addAction(UIAlertAction(title: "Return to Menu", style: .cancel) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Return to Menu", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func setLetterSizeForDataCollection() {
        // Calculate size for 20/200 at 40cm distance
        let arcmin_per_letter = 5.0
        let visual_angle = ((Double(fixedAcuity) / 20.0) * arcmin_per_letter / 60.0) * Double.pi / 180.0
        let scaling_correction_factor = 1.0 / 2.54  // Conversion from inches to cm
        
        let scale_factor = fixedDistance * tan(visual_angle) * scaling_correction_factor
        let labelHeight = scale_factor * ppi
        
        // Set the letter size
        letterLabel.frame.size = CGSize(width: (labelHeight * 5), height: labelHeight)
        
        // Set font size
        let fontSize = 0.3 * letterLabel.frame.height
        letterLabel.font = letterLabel.font?.withSize(fontSize)
        
        print("🔬 Letter sized for data collection - Acuity: 20/\(fixedAcuity), Distance: \(fixedDistance)cm, Font size: \(fontSize)pt")
    }
    
    private func playAudioInstructions() {
        let instructionText = "Data collection mode. Say each letter you see clearly. You will see 25 letters total."
        SharedAudioManager.shared.playText(instructionText, source: "Data Collection")
    }
    
    // MARK: - Speech Timeout Management
    
    private func startSpeechTimeoutTimer() {
        stopSpeechTimeoutTimer()
        
        speechTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("🎤 ⏰ Speech recognition timeout in data collection - restarting...")
            
            if self.isListening {
                self.stopListening()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.currentLetterIndex < self.totalLetters {
                        self.startListening()
                    }
                }
            }
        }
    }
    
    private func stopSpeechTimeoutTimer() {
        speechTimeoutTimer?.invalidate()
        speechTimeoutTimer = nil
    }
    
    // MARK: - ARSCNViewDelegate (minimal implementation for distance tracking)
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
        
        print("👁️ Face detected for data collection")
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        leftEye.simdTransform = faceAnchor.leftEyeTransform
        rightEye.simdTransform = faceAnchor.rightEyeTransform
        
        // We don't need to actively track distance for data collection,
        // but we keep this for potential future use
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("🎤 Speech recognizer availability changed: \(available)")
    }
}
