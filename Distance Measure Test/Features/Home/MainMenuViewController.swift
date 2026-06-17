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
@MainActor
class SharedAudioManager: NSObject, @unchecked Sendable {
    static let shared = SharedAudioManager()
    static let speechDidStartNotification = Notification.Name("SharedAudioManagerSpeechDidStart")
    static let speechDidFinishNotification = Notification.Name("SharedAudioManagerSpeechDidFinish")
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    private func configureAudioSession(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions,
        logContext: String
    ) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(category, mode: mode, options: options)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("🔊 Shared Audio Manager - \(logContext) audio session configured successfully")
        } catch {
            print("🔊 Shared Audio Manager - ❌ \(logContext) audio session setup failed: \(error)")
        }
    }

    private func setupPlaybackAudioSystem() {
        configureAudioSession(
            category: .playback,
            mode: .default,
            options: [],
            logContext: "Playback"
        )
    }

    func prepareForMicrophoneCapture() {
        configureAudioSession(
            category: .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothA2DP],
            logContext: "Microphone capture"
        )
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
    
    func isETDRSTestEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "etdrs_test_enabled")
    }
    
    func setETDRSTestEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "etdrs_test_enabled")
        print("🔧 Shared Audio Manager - Test type set to: \(enabled ? "ETDRS" : "Landolt C")")
    }

    var isSpeaking: Bool {
        speechSynthesizer.isSpeaking || speechSynthesizer.isPaused
    }
    
    func playText(_ text: String, source: String = "Unknown") {
        print("🔊 [\(source)] playText called")
        print("🔊 [\(source)] Audio enabled: \(isAudioEnabled())")
        
        guard isAudioEnabled() else {
            print("🔊 [\(source)] Audio disabled, not playing text")
            return
        }

        setupPlaybackAudioSystem()
        
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
extension SharedAudioManager: @preconcurrency AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 Shared Audio Manager - ✅ Speech synthesis STARTED")
        NotificationCenter.default.post(name: SharedAudioManager.speechDidStartNotification, object: self)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 Shared Audio Manager - ✅ Speech synthesis FINISHED")
        NotificationCenter.default.post(name: SharedAudioManager.speechDidFinishNotification, object: self)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🔊 Shared Audio Manager - ❌ Speech synthesis CANCELLED")
        NotificationCenter.default.post(name: SharedAudioManager.speechDidFinishNotification, object: self)
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
    @IBOutlet weak var menuLabel: UITextField!
    @IBOutlet weak var appDescriptionLabel: UILabel!

    private lazy var whisperLoadingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.94)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var whisperLoadingFlowerView: DaisyFlowerView = {
        let flower = DaisyFlowerView(
            petalColor: UIColor(red: 0.788, green: 0.169, blue: 0.369, alpha: 1.0),
            centerColor: .white
        )
        flower.translatesAutoresizingMaskIntoConstraints = false
        return flower
    }()

    private lazy var whisperLoadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Preparing speech model..."
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .darkGray
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var isAnimatingWhisperFlower = false
    private var hasStartedWhisperPreload = false

    private lazy var whisperLoadingProgressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0)
        progressView.trackTintColor = UIColor.systemGray5
        progressView.translatesAutoresizingMaskIntoConstraints = false
        return progressView
    }()
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        initializeAudioSettings()
        initializeTestTypeSettings()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startWhisperPreloadAfterFirstFrame()
        playAudioInstructions()
    }
    
    /* Initializes the audio settings for the user.
    */
    private func initializeAudioSettings() {
        UserDefaults.standard.register(defaults: ["audio_enabled": true])
    }
    
    /* Initializes the test type settings for the user.
    */
    private func initializeTestTypeSettings() {
        UserDefaults.standard.register(defaults: ["etdrs_test_enabled": false])
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
    }
    
    /* Checks if the ETDRS test is enabled for the user.
    */
    private func isETDRSTestEnabled() -> Bool {
        return SharedAudioManager.shared.isETDRSTestEnabled()
    }
    
    /* Sets the test type enabled for the user.
    */
    private func setETDRSTestEnabled(_ enabled: Bool) {
        SharedAudioManager.shared.setETDRSTestEnabled(enabled)
    }
    
    
    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let testName = isETDRSTestEnabled() ? "ETDRS mode" : "Landolt C mode"
        let instructionText = "Visual acuity test - \(testName). Tap Start Test to begin."
        SharedAudioManager.shared.playText(instructionText, source: "Main Menu")
    }
    
    /* Sets up the UI for the main menu.
    */
    private func setupUI() {
        view.backgroundColor = UIColor.white
        menuLabel?.drawHeader()
        appDescriptionLabel?.drawSmallText()
        addDecorativeDaisies()
    }

    private func setupWhisperLoadingUI() {
        view.addSubview(whisperLoadingOverlay)
        whisperLoadingOverlay.addSubview(whisperLoadingFlowerView)
        whisperLoadingOverlay.addSubview(whisperLoadingLabel)
        whisperLoadingOverlay.addSubview(whisperLoadingProgressView)

        NSLayoutConstraint.activate([
            whisperLoadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            whisperLoadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            whisperLoadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            whisperLoadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            whisperLoadingFlowerView.centerXAnchor.constraint(equalTo: whisperLoadingOverlay.centerXAnchor),
            whisperLoadingFlowerView.centerYAnchor.constraint(equalTo: whisperLoadingOverlay.centerYAnchor, constant: -45),
            whisperLoadingFlowerView.widthAnchor.constraint(equalToConstant: 84),
            whisperLoadingFlowerView.heightAnchor.constraint(equalToConstant: 84),

            whisperLoadingLabel.topAnchor.constraint(equalTo: whisperLoadingFlowerView.bottomAnchor, constant: 18),
            whisperLoadingLabel.leadingAnchor.constraint(equalTo: whisperLoadingOverlay.leadingAnchor, constant: 40),
            whisperLoadingLabel.trailingAnchor.constraint(equalTo: whisperLoadingOverlay.trailingAnchor, constant: -40),

            whisperLoadingProgressView.topAnchor.constraint(equalTo: whisperLoadingLabel.bottomAnchor, constant: 6),
            whisperLoadingProgressView.leadingAnchor.constraint(equalTo: whisperLoadingOverlay.leadingAnchor, constant: 60),
            whisperLoadingProgressView.trailingAnchor.constraint(equalTo: whisperLoadingOverlay.trailingAnchor, constant: -60)
        ])
    }

    private func observeWhisperLoadingProgress() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(whisperLoadingProgressChanged(_:)),
            name: ETDRSWhisperLetterService.loadingProgressDidChangeNotification,
            object: nil
        )
    }

    private func startWhisperPreloadAfterFirstFrame() {
        guard !hasStartedWhisperPreload else { return }
        hasStartedWhisperPreload = true

        DispatchQueue.main.async {
            self.observeWhisperLoadingProgress()

            Task {
                do {
                    print("[ETDRSWhisper] Preloading WhisperKit model after main menu render...")
                    try await ETDRSWhisperLetterService.shared.prepareIfNeeded()
                    print("[ETDRSWhisper] WhisperKit model preloaded after main menu render.")
                } catch {
                    print("[ETDRSWhisper] Main menu preload failed: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func whisperLoadingProgressChanged(_ notification: Notification) {
        let progress = notification.userInfo?[ETDRSWhisperLetterService.loadingProgressKey] as? Double ?? 0.0
        let status = notification.userInfo?[ETDRSWhisperLetterService.loadingStatusKey] as? String ?? "Preparing speech model..."

        DispatchQueue.main.async { [weak self] in
            self?.updateWhisperLoadingUI(progress: progress, status: status)
        }
    }

    private func updateWhisperLoadingUI(progress: Double, status: String) {
        whisperLoadingLabel.text = status
        whisperLoadingProgressView.setProgress(Float(progress), animated: true)

        let isReady = progress >= 1.0
        if isReady {
            stopWhisperFlowerAnimation()
        } else {
            startWhisperFlowerAnimation()
        }

        UIView.animate(withDuration: 0.25) {
            self.whisperLoadingOverlay.alpha = isReady ? 0.0 : 1.0
        } completion: { _ in
            self.whisperLoadingOverlay.isHidden = isReady
        }
    }

    private func startWhisperFlowerAnimation() {
        guard !isAnimatingWhisperFlower else { return }
        isAnimatingWhisperFlower = true
        whisperLoadingOverlay.isHidden = false

        UIView.animate(
            withDuration: 0.85,
            delay: 0,
            options: [.autoreverse, .repeat, .allowUserInteraction],
            animations: {
                self.whisperLoadingFlowerView.transform = CGAffineTransform(scaleX: 1.16, y: 1.16)
                self.whisperLoadingFlowerView.alpha = 0.72
            }
        )
    }

    private func stopWhisperFlowerAnimation() {
        guard isAnimatingWhisperFlower else { return }
        isAnimatingWhisperFlower = false
        whisperLoadingFlowerView.layer.removeAllAnimations()
        whisperLoadingFlowerView.transform = .identity
        whisperLoadingFlowerView.alpha = 1.0
    }
    
    /* Adds decorative daisy flowers to the background for visual cohesion.
    */
    private func addDecorativeDaisies() {
        // Decorative daisy 1 - top left (teal)
        addDecorativeDaisy(
            size: 120,
            petalColor: UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0),
            centerColor: UIColor(red: 0.251, green: 0.427, blue: 0.455, alpha: 1.0),
            alpha: 0.15,
            leadingOffset: 10,
            topOffset: 50
        )
        
        // Decorative daisy 2 - top right (magenta)
        addDecorativeDaisy(
            size: 110,
            petalColor: UIColor(red: 0.788, green: 0.169, blue: 0.369, alpha: 1.0),
            centerColor: UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0),
            alpha: 0.1,
            trailingOffset: 15,
            topOffset: 130
        )
        
        // Decorative daisy 3 - bottom left (teal)
        addDecorativeDaisy(
            size: 100,
            petalColor: UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0),
            centerColor: UIColor(red: 0.251, green: 0.427, blue: 0.455, alpha: 1.0),
            alpha: 0.12,
            leadingOffset: 20,
            bottomOffset: 80
        )
    }
    
    /* Navigates to the test history scene.
    */
    @IBAction func goToTestHistory(_ sender: Any) {
        let testHistoryVC = TestHistoryViewController()
        navigationController?.pushViewController(testHistoryVC, animated: true)
    }
    
    @IBAction func goToSettings(_ sender: Any) {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
        
        if isAudioEnabled() {
            SharedAudioManager.shared.playText("Opening settings screen", source: "Main Menu")
        }
    }
    
    @IBAction func goToDataCollection(_ sender: Any) {
        let dataCollectionVC = DataCollectionViewController()
        navigationController?.pushViewController(dataCollectionVC, animated: true)
        
        if isAudioEnabled() {
            SharedAudioManager.shared.playText("Opening data collection for algorithm optimization", source: "Main Menu")
        }
    }
    
    
    
    /* Tests the audio instructions for the user.
    */
    @objc private func testAudioButtonTapped() {
        print("🔊 Test Audio button tapped!")
        
        // Force enable audio for testing
        SharedAudioManager.shared.setAudioEnabled(true)
        
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
