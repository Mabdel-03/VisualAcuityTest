//
//  SettingsViewController.swift
//  Distance Measure Test
//
//  Created by Visual Acuity Test Assistant
//

import UIKit

/*
 * SettingsViewController manages the app settings for the Landolt-C only version.
 * Users can toggle audio preferences. Test type is fixed to Landolt C.
 */
class SettingsViewController: UIViewController {
    
    // MARK: - UI Elements
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Settings"
        label.drawHeader()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Test Type Info Section (Read-only)
    private lazy var testTypeLabel: UILabel = {
        let label = UILabel()
        label.text = "Test Type: Landolt C"
        label.drawHeader2()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var testTypeDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "C-shaped letters with swipe gestures"
        label.drawSmallText()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Audio Section
    private lazy var audioLabel: UILabel = {
        let label = UILabel()
        label.text = "Audio Instructions"
        label.drawHeader2()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var audioDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Spoken instructions"
        label.drawSmallText()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var audioSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(audioSwitchChanged(_:)), for: .valueChanged)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        return toggle
    }()
    
    private lazy var audioContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var audioTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "🔊 Enable Audio Instructions"
        label.drawSmallText()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Navigation
    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.drawStandardButton()
        button.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateAudioSwitch()
        
        // Ensure Landolt C is always selected in this version
        setETDRSTestEnabled(false)
        
        // Play audio instructions for the settings screen
        if isAudioEnabled() {
            playAudioInstructions()
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // Add decorative circles
        addDecorativeCircles()
        
        // Add scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add all UI elements to content view
        contentView.addSubview(titleLabel)
        contentView.addSubview(testTypeLabel)
        contentView.addSubview(testTypeDescriptionLabel)
        contentView.addSubview(audioLabel)
        contentView.addSubview(audioDescriptionLabel)
        contentView.addSubview(audioContainer)
        contentView.addSubview(doneButton)
        
        // Add audio controls to container
        audioContainer.addSubview(audioTitleLabel)
        audioContainer.addSubview(audioSwitch)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Test Type Section
            testTypeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            testTypeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            testTypeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            testTypeDescriptionLabel.topAnchor.constraint(equalTo: testTypeLabel.bottomAnchor, constant: 5),
            testTypeDescriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            testTypeDescriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Audio Section
            audioLabel.topAnchor.constraint(equalTo: testTypeDescriptionLabel.bottomAnchor, constant: 30),
            audioLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            audioLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            audioDescriptionLabel.topAnchor.constraint(equalTo: audioLabel.bottomAnchor, constant: 5),
            audioDescriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            audioDescriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Audio Container
            audioContainer.topAnchor.constraint(equalTo: audioDescriptionLabel.bottomAnchor, constant: 15),
            audioContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            audioContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            audioContainer.heightAnchor.constraint(equalToConstant: 60),
            
            // Audio controls within container
            audioTitleLabel.leadingAnchor.constraint(equalTo: audioContainer.leadingAnchor, constant: 16),
            audioTitleLabel.centerYAnchor.constraint(equalTo: audioContainer.centerYAnchor),
            
            audioSwitch.trailingAnchor.constraint(equalTo: audioContainer.trailingAnchor, constant: -16),
            audioSwitch.centerYAnchor.constraint(equalTo: audioContainer.centerYAnchor),
            audioTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: audioSwitch.leadingAnchor, constant: -10),
            
            // Done Button
            doneButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            doneButton.topAnchor.constraint(equalTo: audioContainer.bottomAnchor, constant: 30),
            doneButton.widthAnchor.constraint(equalToConstant: 242),
            doneButton.heightAnchor.constraint(equalToConstant: 60),
            doneButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func audioSwitchChanged(_ sender: UISwitch) {
        setAudioEnabled(sender.isOn)
        
        let message = sender.isOn ? "Audio instructions enabled" : "Audio instructions disabled"
        if sender.isOn {
            SharedAudioManager.shared.playText(message, source: "Settings")
        }
    }
    
    @objc private func doneButtonTapped() {
        if isAudioEnabled() {
            SharedAudioManager.shared.playText("Settings saved. Landolt C test is active. Returning to main menu.", source: "Settings")
        }
        
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func updateAudioSwitch() {
        audioSwitch.isOn = isAudioEnabled()
    }
    
    // MARK: - Settings Management
    
    private func isAudioEnabled() -> Bool {
        return SharedAudioManager.shared.isAudioEnabled()
    }
    
    private func setAudioEnabled(_ enabled: Bool) {
        SharedAudioManager.shared.setAudioEnabled(enabled)
    }
    
    private func isETDRSTestEnabled() -> Bool {
        return SharedAudioManager.shared.isETDRSTestEnabled()
    }
    
    private func setETDRSTestEnabled(_ enabled: Bool) {
        SharedAudioManager.shared.setETDRSTestEnabled(enabled)
    }
    
    // MARK: - Audio Instructions
    
    private func playAudioInstructions() {
        let audioStatus = isAudioEnabled() ? "enabled" : "disabled"
        
        let instructionText = """
        Settings screen. This app uses the Landolt C test with swipe gestures to indicate the opening direction of C-shaped letters. 
        Audio instructions are currently \(audioStatus). You can toggle audio instructions on or off. Tap Done when finished.
        """
        
        SharedAudioManager.shared.playText(instructionText, source: "Settings")
    }
    
    // MARK: - Decorative Elements
    
    /* Adds decorative daisy flowers to the background for visual cohesion.
    */
    private func addDecorativeCircles() {
        // Decorative daisy 1 - top right (magenta)
        addDecorativeDaisy(
            size: 105,
            petalColor: UIColor(red: 0.788, green: 0.169, blue: 0.369, alpha: 1.0),
            centerColor: UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0),
            alpha: 0.11,
            trailingOffset: 18,
            topOffset: 90
        )
        
        // Decorative daisy 2 - bottom left (teal)
        addDecorativeDaisy(
            size: 95,
            petalColor: UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0),
            centerColor: UIColor(red: 0.251, green: 0.427, blue: 0.455, alpha: 1.0),
            alpha: 0.13,
            leadingOffset: 22,
            bottomOffset: 110
        )
    }
}
