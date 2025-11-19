import UIKit
import AVFoundation

var finalAcuityDictionary: [Int: String] = [:] // Dictionary to store final acuity values
var eyeNumber: Int = 2 // Start with right eye first (1 for left eye, 2 for right eye)
var logMARValue: Double = -1.000
var snellenValue: Double = -1

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
        label.textColor = UIColor.black
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
        label.textColor = UIColor.black
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
        button.titleLabel?.font = UIFont.systemFont(ofSize: 35, weight: .regular)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0) // Same red as Test History clear button
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(retestButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Save", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 35, weight: .regular)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
    }
    
    /* Sets up the UI for the result scene.
    */
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "Test Results"
        
        // Add decorative circles
        addDecorativeCircles()
        
        // Add scroll view and content view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add subviews to content view
        contentView.addSubview(leftEyeTitleLabel)
        contentView.addSubview(leftEyeResultsLabel)
        contentView.addSubview(rightEyeTitleLabel)
        contentView.addSubview(rightEyeResultsLabel)
        contentView.addSubview(homeButton)
        contentView.addSubview(retestButton)
        contentView.addSubview(saveButton)
        
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
            
            // Right eye title constraints
            rightEyeTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            rightEyeTitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 100),
            rightEyeTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            rightEyeTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            
            // Right eye results constraints
            rightEyeResultsLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            rightEyeResultsLabel.topAnchor.constraint(equalTo: rightEyeTitleLabel.bottomAnchor, constant: 20),
            rightEyeResultsLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            rightEyeResultsLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            
            // Left eye title constraints
            leftEyeTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            leftEyeTitleLabel.topAnchor.constraint(equalTo: rightEyeResultsLabel.bottomAnchor, constant: 50),
            leftEyeTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            leftEyeTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            
            // Left eye results constraints
            leftEyeResultsLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            leftEyeResultsLabel.topAnchor.constraint(equalTo: leftEyeTitleLabel.bottomAnchor, constant: 20),
            leftEyeResultsLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            leftEyeResultsLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            
            // Home button constraints (top button - teal)
            homeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            homeButton.topAnchor.constraint(equalTo: leftEyeResultsLabel.bottomAnchor, constant: 50),
            homeButton.widthAnchor.constraint(equalToConstant: 242),
            homeButton.heightAnchor.constraint(equalToConstant: 60),
            
            // Retest button constraints (middle button - red)
            retestButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            retestButton.topAnchor.constraint(equalTo: homeButton.bottomAnchor, constant: 20),
            retestButton.widthAnchor.constraint(equalToConstant: 242),
            retestButton.heightAnchor.constraint(equalToConstant: 60),
            
            // Save button constraints (bottom button - green)
            saveButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            saveButton.topAnchor.constraint(equalTo: retestButton.bottomAnchor, constant: 20),
            saveButton.widthAnchor.constraint(equalToConstant: 242),
            saveButton.heightAnchor.constraint(equalToConstant: 60),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
        
        displayResults()
    }

    /* Displays the results of the test for both eyes.
    */
    func displayResults() {
        // Left eye results
        if let leftEyeResult = finalAcuityDictionary[1], !isDefaultValue(leftEyeResult) {
            leftEyeResultsLabel.text = leftEyeResult.replacingOccurrences(of: "LogMAR: ", with: "LogMAR Score: ")
                                                  .replacingOccurrences(of: "Snellen: ", with: "Snellen Score: ")
        } else {
            leftEyeResultsLabel.text = "Not Tested"
        }
        
        // Right eye results
        if let rightEyeResult = finalAcuityDictionary[2], !isDefaultValue(rightEyeResult) {
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

    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let instructionText = "Here are your test results. Your visual acuity scores are displayed for each eye tested. Choose Home to return to main menu, Retest to take the test again, or Save to save your results."
        SharedAudioManager.shared.playText(instructionText, source: "Results")
    }

    /* Returns to home screen without saving.
    */
    @objc func homeButtonTapped() {
        // Reset all global variables to their initial state
        finalAcuityDictionary.removeAll()
        eyeNumber = 2
        finalAcuityScore = -Double.infinity
        logMARValue = -1.000
        snellenValue = -1
        
        // Navigate back to the main screen
        navigationController?.popToRootViewController(animated: true)
    }
    
    /* Retests by going back to test setup.
    */
    @objc func retestButtonTapped() {
        // Reset all global variables to their initial state
        finalAcuityDictionary.removeAll()
        eyeNumber = 2
        finalAcuityScore = -Double.infinity
        logMARValue = -1.000
        snellenValue = -1
        
        // Navigate back to the previous screen (test setup)
        navigationController?.popViewController(animated: true)
    }
    
    /* Saves the results and initiates CSV export.
    */
    @objc func saveButtonTapped() {
        // Create a timestamp for this test
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        // Create a dictionary for this test's results
        var testResults: [String: String] = [:]
        if let leftEyeResult = finalAcuityDictionary[1] {
            testResults["Left Eye"] = leftEyeResult
        }
        if let rightEyeResult = finalAcuityDictionary[2] {
            testResults["Right Eye"] = rightEyeResult
        }
        
        // Add to all tests dictionary
        TestDataManager.shared.saveTestResults(testResults, for: timestamp)
        
        // Debug: Print the saved data
        print("Test results saved for timestamp: \(timestamp)")
        print("All tests count: \(TestDataManager.shared.getTestCount())")
        
        // Now initiate CSV export with name prompt
        if !hasTriggeredExport {
            hasTriggeredExport = true
            initiateCSVExport()
        }
    }
    
    // MARK: - CSV Export Methods
    
    /* Initiates the CSV export flow with name prompting and email composition.
    */
    private func initiateCSVExport() {
        print("📊 Initiating CSV export flow")
        
        // Prompt for subject name first
        promptForSubjectName(allowSkip: true) { [weak self] success in
            guard let self = self, success else {
                print("📊 CSV export cancelled - no subject name provided")
                return
            }
            
            // Proceed with CSV generation and email
            self.generateAndEmailCSV()
        }
    }
    
    /* Generates CSV and uploads to Dropbox, with email as fallback.
    */
    private func generateAndEmailCSV() {
        let progressionDataCollector = TestProgressionDataCollector.shared
        let nameManager = SubjectNameManager.shared
        
        // Generate CSV content
        let csvContent = progressionDataCollector.generateCombinedCSV()
        
        // Check if we have actual data
        if csvContent.contains("No test data available") {
            print("📊 No test data available for export")
            showNoDataAlert()
            return
        }
        
        // Generate filename with subject name - format: DateTime_FirstName_LastName.csv
        let fileName = nameManager.generateCSVFilename() ?? {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            return "\(timestamp)_test_data.csv"
        }()
        
        print("📊 Generated CSV filename: \(fileName)")
        
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
                    // Upload failed, show error
                    print("📊 Dropbox upload failed: \(errorMessage ?? "Unknown error")")
                    self.showDropboxFailedAlert(errorMessage: errorMessage)
                }
            }
        }
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
            
            // Reset all global variables
            finalAcuityDictionary.removeAll()
            eyeNumber = 2
            finalAcuityScore = -Double.infinity
            logMARValue = -1.000
            snellenValue = -1
            
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
    
    /* Adds decorative daisy flowers to the background for visual cohesion.
    */
    private func addDecorativeCircles() {
        // Decorative daisy 1 - top left (teal)
        addDecorativeDaisy(
            size: 115,
            petalColor: UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0),
            centerColor: UIColor(red: 0.251, green: 0.427, blue: 0.455, alpha: 1.0),
            alpha: 0.14,
            leadingOffset: 12,
            topOffset: 70
        )
        
        // Decorative daisy 2 - bottom right (magenta)
        addDecorativeDaisy(
            size: 105,
            petalColor: UIColor(red: 0.788, green: 0.169, blue: 0.369, alpha: 1.0),
            centerColor: UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0),
            alpha: 0.11,
            trailingOffset: 17,
            bottomOffset: 90
        )
    }

}
