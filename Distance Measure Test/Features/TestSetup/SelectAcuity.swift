//
//  SelectAcuity.swift
//  Distance Measure Test
//
//  Created by Maggie Bao on 5/14/24.
//

import UIKit
import AVFoundation

let LETTER = "C" // Landolt C-- the letter that is displayed on the acuity selection scene.

// Global test type preference
var isETDRSTest: Bool {
    return TestTypePreferences.isEnabled()
}

/* SelectAcuity class is designed to display the acuity selection scene.
    On this page, the user is given a list of acuity levels to start the test at.
*/
class SelectAcuity: UIViewController {
    
    @IBOutlet weak var B200: UIButton!
    @IBOutlet weak var B125: UIButton!
    @IBOutlet weak var B80: UIButton!
    @IBOutlet weak var B50: UIButton!
    @IBOutlet weak var B10: UIButton!

    private var distanceObserver: NSObjectProtocol?
    private var calibrationObserver: NSObjectProtocol?
    private var staleDistanceTimer: Timer?
    private var isPresentingCalibration = false
    private var renderSpecs: [ObjectIdentifier: OptotypeRenderSpec] = [:]

    private var acuityButtons: [(button: UIButton, denominator: Int)] {
        [(B200, 200), (B125, 125), (B80, 80), (B50, 50), (B10, 20)]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set background to teal
        view.backgroundColor = AppThemeColors.teal
        
        // Configure the stack view and buttons for dynamic sizing
        configureButtonConstraints()
        configureButtonAppearance()
        setChoicesEnabled(false)

        distanceObserver = NotificationCenter.default.addObserver(
            forName: .eyeDistanceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshOptotypes()
        }
        calibrationObserver = NotificationCenter.default.addObserver(
            forName: .screenCalibrationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isPresentingCalibration = false
            self?.refreshOptotypes()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        EyeDistanceProvider.shared.start(
            eyeNumber: VisualAcuitySession.currentEyeNumber,
            client: self
        )
        staleDistanceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) {
            [weak self] _ in self?.refreshOptotypes()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        staleDistanceTimer?.invalidate()
        staleDistanceTimer = nil
        EyeDistanceProvider.shared.stop(client: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requireCalibrationIfNeeded()
        refreshOptotypes()
        playAudioInstructions()
    }

    deinit {
        staleDistanceTimer?.invalidate()
        if let distanceObserver { NotificationCenter.default.removeObserver(distanceObserver) }
        if let calibrationObserver { NotificationCenter.default.removeObserver(calibrationObserver) }
    }
    
    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let instructionText = "Tap the smallest letter you can clearly see."
        SharedAudioManager.shared.playText(instructionText, source: "Acuity Selection")
    }
    
    /* Sets up the button text size and display for the acuity selection scene.
    */
    @discardableResult
    func Button_ETDRS(_ button: UIButton, dAcuity: Int, letText: String) -> Bool {
        guard let sample = EyeDistanceProvider.shared.validSample(),
              let calibration = ScreenCalibrationProvider.shared.currentCalibration else {
            button.setTitle(letText, for: .normal)
            button.isEnabled = false
            return false
        }
        do {
            let identifier = ObjectIdentifier(button)
            let update = try OptotypeRenderer.update(
                button: button,
                text: letText,
                distanceCM: sample.distanceCM,
                snellenDenominator: dAcuity,
                calibration: calibration,
                previousSpec: renderSpecs[identifier]
            )
            renderSpecs[identifier] = update.spec
            return true
        } catch {
            button.isEnabled = false
            print("Unable to size acuity \(dAcuity): \(error.localizedDescription)")
            return false
        }
    }

    private func configureButtonAppearance() {
        for (button, _) in acuityButtons {
            button.configuration = nil
            button.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
            button.setTitleColor(.gray, for: .disabled)
            button.titleLabel?.adjustsFontSizeToFitWidth = false
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.lineBreakMode = .byClipping
            button.titleLabel?.textAlignment = .center
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.lightGray.cgColor
        }
    }

    private func refreshOptotypes() {
        guard ScreenCalibrationProvider.shared.currentCalibration != nil,
              EyeDistanceProvider.shared.validSample() != nil else {
            setChoicesEnabled(false)
            return
        }
        let displayLetter = isETDRSTest ? "C" : LETTER
        var renderedEveryChoice = true
        for (button, denominator) in acuityButtons {
            renderedEveryChoice = Button_ETDRS(
                button,
                dAcuity: denominator,
                letText: displayLetter
            ) && renderedEveryChoice
        }
        setChoicesEnabled(renderedEveryChoice)
    }

    private func setChoicesEnabled(_ isEnabled: Bool) {
        acuityButtons.forEach { $0.button.isEnabled = isEnabled }
    }

    private func requireCalibrationIfNeeded() {
        guard ScreenCalibrationProvider.shared.currentCalibration == nil,
              !isPresentingCalibration else { return }
        isPresentingCalibration = true
        present(ScreenCalibrationViewController(), animated: true)
    }

    //DIFFERENT ACUITY LEVELS

    @IBAction func option1(_ sender: Any) {
        VisualAcuitySession.selectedAcuity = 200
        proceedToTest()
    }
    
    @IBAction func option3(_ sender: Any) {
        VisualAcuitySession.selectedAcuity = 125
        proceedToTest()
    }

    @IBAction func option5(_ sender: Any) {
        VisualAcuitySession.selectedAcuity = 80
        proceedToTest()
    }

    @IBAction func option7(_ sender: Any) {
        VisualAcuitySession.selectedAcuity = 50
        proceedToTest()
    }
    
    @IBAction func option10(_ sender: Any) {
        VisualAcuitySession.selectedAcuity = 20
        proceedToTest()
    }
    
    /* This function ensures that selectedAcuity is saved before transitioning
        to the test scene.
    */
    private func proceedToTest() {
        print("Proceeding to test with acuity: \(String(describing: VisualAcuitySession.selectedAcuity))")

        if isETDRSTest {
            let loadingVC = ETDRSWhisperLoadingViewController(launchPurpose: .beforeETDRSTest)
            navigationController?.pushViewController(loadingVC, animated: true)
            print("🔤 ✅ Successfully navigating to ETDRS loading screen")
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            // Navigate to Landolt C test
            if let tumblingVC = storyboard.instantiateViewController(withIdentifier: "TumblingEViewController") as? TumblingEViewController {
                navigationController?.pushViewController(tumblingVC, animated: true)
                print("🔄 ✅ Successfully navigating to Landolt C test")
            } else {
                print("🔄 ❌ Failed to instantiate TumblingEViewController from storyboard")
            }
        }
    }
    
    /* Configures the button constraints for the acuity selection scene.
    */
    private func configureButtonConstraints() {
        // Get all the buttons
        let buttons = [B200, B125, B80, B50, B10]
        
        // Configure the stack view for connected buttons (no spacing)
        if let firstButton = buttons.compactMap({ $0 }).first,
           let stackView = firstButton.superview as? UIStackView {
            stackView.distribution = .fillEqually
            stackView.alignment = .fill
            stackView.spacing = 0 // Remove spacing to connect buttons
            print("✅ Stack view configured: distribution=fillEqually, alignment=fill, spacing=0")
            
            // Apply rounded corners only to top and bottom buttons
            configureConnectedButtonCorners(buttons: buttons.compactMap({ $0 }))
        } else {
            print("⚠️ Could not find stack view - buttons may not be in a UIStackView")
        }
        
        for button in buttons {
            guard let button = button else { continue }
            
            // Configure button to expand horizontally while maintaining dynamic height
            button.setContentHuggingPriority(.defaultLow, for: .horizontal) // Allow horizontal expansion
            button.setContentHuggingPriority(.defaultLow, for: .vertical)
            button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) // Allow compression if needed
            // Must stay below the stack's fillEqually constraints: the row height is
            // fixed at 1/5 of the safe area, so an oversized optotype clips rather
            // than making the layout unsatisfiable.
            button.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        }
        
        // Force layout update to apply the new sizing
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        print("✅ Button constraints configured for full-width dynamic sizing")
    }
    
    /*
     * Configures rounded corners for connected buttons - only top and bottom buttons get rounded corners.
     */
    private func configureConnectedButtonCorners(buttons: [UIButton]) {
        guard !buttons.isEmpty else { return }
        
        let cornerRadius: CGFloat = 12
        
        for (index, button) in buttons.enumerated() {
            if index == 0 {
                // First button - round top corners only
                button.layer.cornerRadius = cornerRadius
                button.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            } else if index == buttons.count - 1 {
                // Last button - round bottom corners only
                button.layer.cornerRadius = cornerRadius
                button.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            } else {
                // Middle buttons - no rounded corners
                button.layer.cornerRadius = 0
                button.layer.maskedCorners = []
            }
        }
        
        print("✅ Configured connected button corners: top and bottom buttons rounded, middle buttons square")
    }
}
