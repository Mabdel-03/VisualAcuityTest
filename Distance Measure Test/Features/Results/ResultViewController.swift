import UIKit
import AVFoundation

/* TestDataManager class is designed to manage the persistent storage of the test results.
    It is a singleton class that is used to save and retrieve the test results from the user's
    device.
*/
class TestDataManager {
    static let shared = TestDataManager()
    private let userDefaults = UserDefaults.standard
    private let allTestsKey = "allTestsDictionary"
    
    private init() {}
    
    // Save test results to persistent storage
    func saveTestResults(_ testResults: [String: String], for timestamp: String) {
        var allTests = getAllTests()
        allTests[timestamp] = testResults
        
        // Convert dictionary to Data for storage
        if let data = try? JSONSerialization.data(withJSONObject: allTests) {
            userDefaults.set(data, forKey: allTestsKey)
        }
    }
    
    // Retrieve all test results from persistent storage
    func getAllTests() -> [String: [String: String]] {
        guard let data = userDefaults.data(forKey: allTestsKey),
              let allTests = try? JSONSerialization.jsonObject(with: data) as? [String: [String: String]] else {
            return [:]
        }
        return allTests
    }
    
    // Clear all test history (optional method for resetting)
    func clearAllTests() {
        userDefaults.removeObject(forKey: allTestsKey)
    }
    
    // Get the total number of tests performed
    func getTestCount() -> Int {
        return getAllTests().count
    }
    
    // Check if there are any saved tests
    func hasTests() -> Bool {
        return !getAllTests().isEmpty
    }
    
    // Export all test data as a formatted string (for debugging)
    func exportTestData() -> String {
        let allTests = getAllTests()
        var exportString = "Test History Export\n"
        exportString += "Total Tests: \(allTests.count)\n"
        exportString += "==================\n\n"
        
        let sortedTimestamps = allTests.keys.sorted(by: >)
        for timestamp in sortedTimestamps {
            if let testResults = allTests[timestamp] {
                exportString += "Date: \(timestamp)\n"
                for (eye, result) in testResults {
                    exportString += "\(eye): \(result)\n"
                }
                exportString += "------------------\n"
            }
        }
        return exportString
    }
}

/* ResultViewController class is designed to display the results of the test.
    On this page, the user is given the results of the test for both eyes.
*/
class ResultViewController: UIViewController {
    var score: Int = 0
    var totalAttempts: Int = 0
    
    // Flag to prevent duplicate CSV export prompts
    private var hasTriggeredExport = false
    
    // Store CSV data for share sheet fallback
    private var currentCSVContent: String?
    private var currentFileName: String?
    
    // UI ELEMENTS
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

    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Results"
        label.drawHeader()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Your visual acuity summary by eye"
        label.drawSmallText()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var rightEyeCardView: UIView = makeResultCard()
    private lazy var leftEyeCardView: UIView = makeResultCard()
    private lazy var rightEyeAccentView: UIView = makeAccentStrip(color: AppThemeColors.magentaAccent)
    private lazy var leftEyeAccentView: UIView = makeAccentStrip(color: AppThemeColors.magentaAccent)
    
    private lazy var leftEyeTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Left Eye"
        label.drawHeader2()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var leftEyeResultsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 27, weight: .bold)
        label.textAlignment = .center
        label.textColor = AppThemeColors.black
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var rightEyeTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Right Eye"
        label.drawHeader2()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var rightEyeResultsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 27, weight: .bold)
        label.textAlignment = .center
        label.textColor = AppThemeColors.black
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var homeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Home", for: .normal)
        button.drawStandardButton()
        button.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    private lazy var retestButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Retest", for: .normal)
        button.drawStandardButton()
        button.backgroundColor = AppThemeColors.destructiveRed
        button.addTarget(self, action: #selector(retestButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Save", for: .normal)
        button.drawStandardButton()
        button.backgroundColor = AppThemeColors.actionBlue
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    private func resetExportState() {
        hasTriggeredExport = false
        saveButton.isEnabled = true
        saveButton.alpha = 1.0
    }

    private func makeResultCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .white
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = AppThemeColors.systemGreyBackground.withAlphaComponent(0.55).cgColor
        card.layer.shadowColor = AppThemeColors.black.withAlphaComponent(0.08).cgColor
        card.layer.shadowOpacity = 1
        card.layer.shadowRadius = 18
        card.layer.shadowOffset = CGSize(width: 0, height: 10)
        return card
    }

    private func makeAccentStrip(color: UIColor) -> UIView {
        let strip = UIView()
        strip.translatesAutoresizingMaskIntoConstraints = false
        strip.backgroundColor = color
        strip.layer.cornerRadius = 3
        strip.layer.masksToBounds = true
        return strip
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
        animateDecorativeDaisies()
    }
    
    /* Sets up the UI for the result scene.
    */
    private func setupUI() {
        view.backgroundColor = AppThemeColors.systemGreySurface
        navigationItem.title = nil
        
        // Add decorative circles
        addDecorativeCircles()
        
        // Add scroll view and content view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add subviews to content view
        contentView.addSubview(headerLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(rightEyeCardView)
        contentView.addSubview(leftEyeCardView)
        contentView.addSubview(homeButton)
        contentView.addSubview(retestButton)
        contentView.addSubview(saveButton)

        rightEyeCardView.addSubview(rightEyeTitleLabel)
        rightEyeCardView.addSubview(rightEyeResultsLabel)
        rightEyeCardView.addSubview(rightEyeAccentView)
        leftEyeCardView.addSubview(leftEyeTitleLabel)
        leftEyeCardView.addSubview(leftEyeResultsLabel)
        leftEyeCardView.addSubview(leftEyeAccentView)
        
        // Set up constraints
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

            headerLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 26),
            headerLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),

            subtitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            
            // Right eye card constraints
            rightEyeCardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 36),
            rightEyeCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            rightEyeCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // Right eye card internals
            rightEyeAccentView.leadingAnchor.constraint(equalTo: rightEyeCardView.leadingAnchor),
            rightEyeAccentView.topAnchor.constraint(equalTo: rightEyeCardView.topAnchor),
            rightEyeAccentView.bottomAnchor.constraint(equalTo: rightEyeCardView.bottomAnchor),
            rightEyeAccentView.widthAnchor.constraint(equalToConstant: 6),

            rightEyeTitleLabel.topAnchor.constraint(equalTo: rightEyeCardView.topAnchor, constant: 20),
            rightEyeTitleLabel.leadingAnchor.constraint(equalTo: rightEyeAccentView.trailingAnchor, constant: 16),
            rightEyeTitleLabel.trailingAnchor.constraint(equalTo: rightEyeCardView.trailingAnchor, constant: -20),

            rightEyeResultsLabel.topAnchor.constraint(equalTo: rightEyeTitleLabel.bottomAnchor, constant: 12),
            rightEyeResultsLabel.leadingAnchor.constraint(equalTo: rightEyeAccentView.trailingAnchor, constant: 16),
            rightEyeResultsLabel.trailingAnchor.constraint(equalTo: rightEyeCardView.trailingAnchor, constant: -20),
            rightEyeResultsLabel.bottomAnchor.constraint(equalTo: rightEyeCardView.bottomAnchor, constant: -20),

            // Left eye card constraints
            leftEyeCardView.topAnchor.constraint(equalTo: rightEyeCardView.bottomAnchor, constant: 18),
            leftEyeCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            leftEyeCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // Left eye card internals
            leftEyeAccentView.leadingAnchor.constraint(equalTo: leftEyeCardView.leadingAnchor),
            leftEyeAccentView.topAnchor.constraint(equalTo: leftEyeCardView.topAnchor),
            leftEyeAccentView.bottomAnchor.constraint(equalTo: leftEyeCardView.bottomAnchor),
            leftEyeAccentView.widthAnchor.constraint(equalToConstant: 6),

            leftEyeTitleLabel.topAnchor.constraint(equalTo: leftEyeCardView.topAnchor, constant: 20),
            leftEyeTitleLabel.leadingAnchor.constraint(equalTo: leftEyeAccentView.trailingAnchor, constant: 16),
            leftEyeTitleLabel.trailingAnchor.constraint(equalTo: leftEyeCardView.trailingAnchor, constant: -20),

            leftEyeResultsLabel.topAnchor.constraint(equalTo: leftEyeTitleLabel.bottomAnchor, constant: 12),
            leftEyeResultsLabel.leadingAnchor.constraint(equalTo: leftEyeAccentView.trailingAnchor, constant: 16),
            leftEyeResultsLabel.trailingAnchor.constraint(equalTo: leftEyeCardView.trailingAnchor, constant: -20),
            leftEyeResultsLabel.bottomAnchor.constraint(equalTo: leftEyeCardView.bottomAnchor, constant: -20),
            
            // Home button constraints (top button - teal)
            homeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            homeButton.topAnchor.constraint(equalTo: leftEyeCardView.bottomAnchor, constant: 40),
            homeButton.widthAnchor.constraint(equalToConstant: 242),
            homeButton.heightAnchor.constraint(equalToConstant: 60),
            
            // Retest button constraints (middle button - red)
            retestButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            retestButton.topAnchor.constraint(equalTo: homeButton.bottomAnchor, constant: 16),
            retestButton.widthAnchor.constraint(equalToConstant: 242),
            retestButton.heightAnchor.constraint(equalToConstant: 60),
            
            // Save button constraints (bottom button - green)
            saveButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            saveButton.topAnchor.constraint(equalTo: retestButton.bottomAnchor, constant: 16),
            saveButton.widthAnchor.constraint(equalToConstant: 242),
            saveButton.heightAnchor.constraint(equalToConstant: 60),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -34)
        ])
        
        hideStoryboardResultsTitleIfPresent()
        displayResults()
    }

    /* Displays the results of the test for both eyes.
    */
    func displayResults() {
        // Left eye results
        if let leftEyeResult = VisualAcuitySession.finalAcuityResults[1], !isDefaultValue(leftEyeResult) {
            leftEyeResultsLabel.text = leftEyeResult.replacingOccurrences(of: "LogMAR: ", with: "LogMAR Score: ")
                                                  .replacingOccurrences(of: "Snellen: ", with: "Snellen Score: ")
        } else {
            leftEyeResultsLabel.text = "Not Tested"
        }
        
        // Right eye results
        if let rightEyeResult = VisualAcuitySession.finalAcuityResults[2], !isDefaultValue(rightEyeResult) {
            rightEyeResultsLabel.text = rightEyeResult.replacingOccurrences(of: "LogMAR: ", with: "LogMAR Score: ")
                                                    .replacingOccurrences(of: "Snellen: ", with: "Snellen Score: ")
        } else {
            rightEyeResultsLabel.text = "Not Tested"
        }
        
        // Show all three buttons
        homeButton.isHidden = false
        retestButton.isHidden = false
        saveButton.isHidden = false
    }
    
    // Helper function to check if the result contains default/invalid values
    private func isDefaultValue(_ result: String) -> Bool {
        // Check for default values that indicate the eye wasn't actually tested
        return result.contains("-1.000") || result.contains("20/-1") || result.contains("LogMAR: -1")
    }

    private func hideStoryboardResultsTitleIfPresent() {
        func walk(_ view: UIView) {
            for subview in view.subviews {
                if let field = subview as? UITextField, field.text == "Results" {
                    field.isHidden = true
                } else {
                    walk(subview)
                }
            }
        }

        walk(view)
    }

    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let instructionText = "Here are your test results. Your visual acuity scores are displayed for each eye tested. Choose Home to return to main menu, Retest to take the test again, or Save to save your results."
        SharedAudioManager.shared.playText(instructionText, source: "Results")
    }

    /* Returns to home screen without saving.
    */
    @objc func homeButtonTapped() {
        VisualAcuitySession.resetResults()
        finalAcuityScore = -Double.infinity
        
        // Navigate back to the main screen
        navigationController?.popToRootViewController(animated: true)
    }
    
    /* Retests by going back to test setup.
    */
    @objc func retestButtonTapped() {
        VisualAcuitySession.resetResults()
        finalAcuityScore = -Double.infinity
        
        // Navigate back to the previous screen (test setup)
        navigationController?.popViewController(animated: true)
    }
    
    /* Saves the results and initiates CSV export.
    */
    @objc func saveButtonTapped() {
        guard !hasTriggeredExport else { return }

        saveButton.isEnabled = false
        saveButton.alpha = 0.7

        // Create a timestamp for this test
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        // Create a dictionary for this test's results
        var testResults: [String: String] = [:]
        if let leftEyeResult = VisualAcuitySession.finalAcuityResults[1] {
            testResults["Left Eye"] = leftEyeResult
        }
        if let rightEyeResult = VisualAcuitySession.finalAcuityResults[2] {
            testResults["Right Eye"] = rightEyeResult
        }
        
        // Add to all tests dictionary
        TestDataManager.shared.saveTestResults(testResults, for: timestamp)
        
        // Debug: Print the saved data
        print("Test results saved for timestamp: \(timestamp)")
        print("All tests count: \(TestDataManager.shared.getTestCount())")
        
        // Now initiate CSV export with name prompt
        hasTriggeredExport = true
        initiateCSVExport()
    }
    
    // MARK: - CSV Export Methods
    
    /* Initiates the CSV export flow with name prompting and email composition.
    */
    private func initiateCSVExport() {
        print("📊 Initiating CSV export flow")
        
        // Prompt for subject name first
        promptForSubjectName(allowSkip: true) { [weak self] success in
            guard let self = self else { return }
            guard success else {
                print("📊 CSV export cancelled - no subject name provided")
                self.resetExportState()
                return
            }
            
            // Proceed with CSV generation and email
            self.generateAndEmailCSV()
        }
    }
    
    /* Generates CSV and uploads to Dropbox, with email as fallback.
    */
    private func generateAndEmailCSV() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let progressionDataCollector = TestProgressionDataCollector.shared
            let nameManager = SubjectNameManager.shared
            
            // Generate CSV content off the main thread so export doesn't stall the results UI.
            let csvContent = progressionDataCollector.generateCombinedCSV()
            
            // Generate filename with subject name - format: DateTime_FirstName_LastName.csv
            let fileName = nameManager.generateCSVFilename() ?? {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                return "\(timestamp)_test_data.csv"
            }()
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Check if we have actual data
                if csvContent.contains("No test data available") {
                    print("📊 No test data available for export")
                    self.showNoDataAlert()
                    self.resetExportState()
                    return
                }
                
                print("📊 Generated CSV filename: \(fileName)")
                
                // TEMPORARY: Using manual share sheet only
                // Automatic Dropbox API upload is disabled for now
                print("📊 Presenting share sheet for manual upload")
                self.showShareSheet(csvContent: csvContent, fileName: fileName)
            }
        }
        
        /* COMMENTED OUT: Automatic Dropbox API Upload
        // Store for fallback
        self.currentCSVContent = csvContent
        self.currentFileName = fileName
        
        // Show uploading indicator
        let uploadAlert = UIAlertController(
            title: "Uploading",
            message: "Uploading data to Dropbox...",
            preferredStyle: .alert
        )
        present(uploadAlert, animated: true)
        
        // Upload to Dropbox
        let dropboxManager = DropboxUploadManager.shared
        dropboxManager.uploadCSV(csvContent: csvContent, fileName: fileName) { [weak self] success, errorMessage in
            guard let self = self else { return }
            
            // Dismiss upload alert
            uploadAlert.dismiss(animated: true) {
                if success {
                    // Upload succeeded!
                    self.showDropboxSuccessAlert()
                } else {
                    // Upload failed, automatically show share sheet as fallback
                    print("📊 Dropbox upload failed: \(errorMessage ?? "Unknown error")")
                    print("📊 Automatically presenting share sheet for manual upload")
                    
                    // Use stored values for share sheet
                    if let csvContent = self.currentCSVContent, let fileName = self.currentFileName {
                        self.showShareSheet(csvContent: csvContent, fileName: fileName)
                    }
                }
            }
        }
        END COMMENTED OUT SECTION */
    }
    
    /* Shows success alert after Dropbox upload and returns to home.
    */
    private func showDropboxSuccessAlert() {
        let alert = UIAlertController(
            title: "Upload Successful",
            message: "Your test data has been successfully uploaded to Dropbox.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            // Clear progression data so next test starts fresh
            TestProgressionDataCollector.shared.clearAllProgressionData()
            
            // Reset all global variables
            VisualAcuitySession.resetResults()
            finalAcuityScore = -Double.infinity
            
            // Navigate back to the main screen
            self.navigationController?.popToRootViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    /* Shows alert when Dropbox upload fails.
    */
    private func showDropboxFailedAlert(errorMessage: String?) {
        let message = "Dropbox upload failed: \(errorMessage ?? "Unknown error")\n\nPlease check your internet connection and try again by tapping the Save button."
        
        let alert = UIAlertController(
            title: "Upload Failed",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            print("📊 User acknowledged Dropbox upload failure")
            // Stay on results screen - user can retry with Save button
        })
        
        present(alert, animated: true)
    }
    
    /* Shows alert when no data is available for export.
    */
    private func showNoDataAlert() {
        let alert = UIAlertController(
            title: "No Data Available",
            message: "There is no test data available to export.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /* Presents iOS share sheet to manually share CSV file.
       Used as fallback when Dropbox API upload fails.
    */
    private func showShareSheet(csvContent: String, fileName: String) {
        // Create temporary file
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            // Write CSV to temporary file
            try csvContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
            print("📤 Created temporary file for sharing: \(fileName)")
            
            // Present share sheet
            let activityVC = UIActivityViewController(
                activityItems: [tempFileURL],
                applicationActivities: nil
            )
            
            // For iPad: configure popover presentation
            if let popoverController = activityVC.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            // Handle completion
            activityVC.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempFileURL)

                DispatchQueue.main.async {
                    guard let self else { return }

                    if completed {
                        print("📤 File shared successfully via \(activityType?.rawValue ?? "unknown")")
                        TestProgressionDataCollector.shared.clearAllProgressionData()
                        VisualAcuitySession.resetResults()
                        finalAcuityScore = -Double.infinity
                        self.resetExportState()
                        self.navigationController?.popToRootViewController(animated: true)
                    } else {
                        print("📤 Sharing cancelled by user")
                        self.resetExportState()
                    }
                }
            }
            
            present(activityVC, animated: true)
            
        } catch {
            print("❌ Failed to create temporary file: \(error)")
            resetExportState()
            // Show error alert as fallback
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to prepare file for sharing: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    /* Adds decorative daisy flowers to the background for visual cohesion.
    */
    private func addDecorativeCircles() {
        // Decorative daisy 1 - top left (teal)
        addDecorativeDaisy(
            size: 115,
            petalColor: AppThemeColors.teal,
            centerColor: UIColor(red: 0.251, green: 0.427, blue: 0.455, alpha: 1.0),
            alpha: 0.14,
            leadingOffset: 12,
            topOffset: 70
        )
        
        // Decorative daisy 2 - bottom right (magenta)
        addDecorativeDaisy(
            size: 105,
            petalColor: AppThemeColors.magentaAccent,
            centerColor: UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0),
            alpha: 0.11,
            trailingOffset: 17,
            bottomOffset: 90
        )
    }

}
