//
//  Main Menu.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 8/7/23.
//

import UIKit
import AVFoundation

/* SharedAudioManager class is designed to manage the audio instructions on the
    visual acuity app. It is a singleton class that is used to play audio instructions
    to the user.
*/
class SharedAudioManager: NSObject {
    static let shared = SharedAudioManager()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private override init() {
        super.init()
        speechSynthesizer.delegate = self
        setupAudioSystem()
    }
    
    private func setupAudioSystem() {
        // Check if speech synthesis is available
        let voices = AVSpeechSynthesisVoice.speechVoices()
        print("🔊 Shared Audio Manager - Available voices: \(voices.count)")
        
        if let englishVoice = AVSpeechSynthesisVoice(language: "en-US") {
            print("🔊 Shared Audio Manager - ✅ English voice available: \(englishVoice.name)")
        } else {
            print("🔊 Shared Audio Manager - ❌ No English voice available")
        }
        
        // Configure audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("🔊 Shared Audio Manager - Audio session configured successfully")
        } catch {
            print("🔊 Shared Audio Manager - ❌ Audio session setup failed: \(error)")
        }
    }
    
    func isAudioEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "audio_enabled")
    }
    
    func setAudioEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "audio_enabled")
        print("🔊 Shared Audio Manager - Audio set to: \(enabled)")
        
        // Stop any current speech when disabled
        if !enabled {
            stopSpeech()
        }
    }
    
    func playText(_ text: String, source: String = "Unknown") {
        print("🔊 [\(source)] playText called")
        print("🔊 [\(source)] Audio enabled: \(isAudioEnabled())")
        
        guard isAudioEnabled() else {
            print("🔊 [\(source)] Audio disabled, not playing text")
            return
        }
        
        // ALWAYS stop any current speech before starting new speech
        stopSpeech()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.volume = 1.0
        
        // Try to set a specific voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
            print("🔊 [\(source)] Using voice: \(voice.name)")
        } else {
            print("🔊 [\(source)] No voice found, using default")
        }
        
        print("🔊 [\(source)] Starting speech synthesis...")
        speechSynthesizer.speak(utterance)
        print("🔊 [\(source)] Speech synthesis command sent")
    }
    
    func stopSpeech() {
        if speechSynthesizer.isSpeaking {
            print("🔊 Shared Audio Manager - Stopping current speech")
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        if speechSynthesizer.isPaused {
            print("🔊 Shared Audio Manager - Stopping paused speech")
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    func initializeDefaultSettings() {
        // Always set audio enabled by default on app launch
        UserDefaults.standard.set(true, forKey: "audio_enabled")
        print("🔊 Shared Audio Manager - Audio initialized as enabled")
    }
}

/* AVSpeechSynthesizerDelegate is a protocol that allows the SharedAudioManager to 
    manage the audio instructions on the visual acuity app.
*/
extension SharedAudioManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 Shared Audio Manager - ✅ Speech synthesis STARTED")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 Shared Audio Manager - ✅ Speech synthesis FINISHED")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🔊 Shared Audio Manager - ❌ Speech synthesis CANCELLED")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        print("🔊 Shared Audio Manager - 📢 Speaking: \(utterance.speechString)")
    }
}

/* CORNER_RADIUS is a constant that is used to round the corners of the buttons on the main menu.
*/
let CORNER_RADIUS: CGFloat = 2.0

/* MainMenu class is designed to manage the main menu scene on the
    visual acuity app. This is what the user sees upon first opening the app.
    Tuser is given the option to toggle their audio instructions as well as 
    four buttons to navigate to the different scenes.
*/
class MainMenu: UIViewController {
    
    /* Settings button is a button that allows the user to toggle their audio instructions.
    */
    private lazy var settingsButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("⚙️ Audio", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.318, green: 0.522, blue: 0.624, alpha: 1.0) // #51859F
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        button.layer.cornerRadius = CORNER_RADIUS
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(audioToggleButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        initializeAudioSettings()
        updateAudioButtonAppearance()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
    }
    
    /* Initializes the audio settings for the user.
    */
    private func initializeAudioSettings() {
        SharedAudioManager.shared.initializeDefaultSettings()
    }
    
    /* Checks if the audio is enabled for the user.
    */
    private func isAudioEnabled() -> Bool {
        return SharedAudioManager.shared.isAudioEnabled()
    }
    
    /* Sets the audio enabled for the user.
    */
    private func setAudioEnabled(_ enabled: Bool) {
        SharedAudioManager.shared.setAudioEnabled(enabled)
        updateAudioButtonAppearance()
    }
    
    /* Updates the appearance of the audio button.
    */
    private func updateAudioButtonAppearance() {
        let isEnabled = isAudioEnabled()
        settingsButton.setTitle(isEnabled ? "🔊 Audio On" : "🔇 Audio Off", for: .normal)
        settingsButton.backgroundColor = isEnabled ? UIColor.systemGreen.withAlphaComponent(0.3) : UIColor.systemGray6
        print("🔊 Main Menu - Button updated - Audio is: \(isEnabled ? "ON" : "OFF")")
    }
    
    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let instructionText = "Welcome to the Visual Acuity Test app. Tap 'Start Test' to begin a new vision test, or tap 'Completed Tests' to view your test history. You can toggle audio instructions using the audio button."
        SharedAudioManager.shared.playText(instructionText, source: "Main Menu")
    }
    
    /* Sets up the UI for the main menu.
    */
    private func setupUI() {
        view.backgroundColor = UIColor.white
        view.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            settingsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            settingsButton.widthAnchor.constraint(equalToConstant: 140),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }
    
    /* Navigates to the test history scene.
    */
    @IBAction func goToTestHistory(_ sender: Any) {
        let testHistoryVC = TestHistoryViewController()
        navigationController?.pushViewController(testHistoryVC, animated: true)
    }
    
    /* Toggles the audio instructions for the user.
    */
    @objc private func audioToggleButtonTapped() {
        let currentState = isAudioEnabled()
        setAudioEnabled(!currentState)
        
        // Provide audio feedback
        let message = isAudioEnabled() ? "Audio instructions enabled" : "Audio instructions disabled"
        if isAudioEnabled() {
            SharedAudioManager.shared.playText(message, source: "Main Menu Toggle")
        }
    }
    
    /* Tests the audio instructions for the user.
    */
    @objc private func testAudioButtonTapped() {
        print("🔊 Test Audio button tapped!")
        
        // Force enable audio for testing
        SharedAudioManager.shared.setAudioEnabled(true)
        updateAudioButtonAppearance()
        
        let testText = "This is a test of the audio system. If you can hear this, audio is working correctly."
        SharedAudioManager.shared.playText(testText, source: "Main Menu Test")
    }
    
    /* Bypasses the audio instructions for the user.
    */
    @objc private func bypassTestButtonTapped() {
        print("🔊 BYPASS test button tapped!")
        
        // Stop any current speech using the shared manager
        SharedAudioManager.shared.stopSpeech()
        
        let testText = "Bypass test. This directly tests speech synthesis."
        SharedAudioManager.shared.playText(testText, source: "Main Menu Bypass")
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
}
