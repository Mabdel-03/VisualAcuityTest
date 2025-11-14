import UIKit
import AVFoundation
import MessageUI

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
class ResultViewController: UIViewController, MFMailComposeViewControllerDelegate {
    var score: Int = 0
    var totalAttempts: Int = 0
    
    // Flag to prevent duplicate CSV export prompts
    private var hasTriggeredExport = false
    
    // Track temporary CSV file for cleanup
    private var tempCSVFileURL: URL?
    
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
        label.font = UIFont.systemFont(ofSize: 27, weight: .heavy)
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.text = "Left Eye"
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
        label.font = UIFont.systemFont(ofSize: 27, weight: .heavy)
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.text = "Right Eye"
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
    
    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Done", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0) // #396C6D
        button.titleLabel?.font = UIFont.systemFont(ofSize: 30)
        button.layer.cornerRadius = CORNER_RADIUS
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
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
        
        // Add scroll view and content view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add subviews to content view
        contentView.addSubview(leftEyeTitleLabel)
        contentView.addSubview(leftEyeResultsLabel)
        contentView.addSubview(rightEyeTitleLabel)
        contentView.addSubview(rightEyeResultsLabel)
        // contentView.addSubview(rightEyeButton)
        contentView.addSubview(doneButton)
        
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
//            
            // Done button constraints
            doneButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            doneButton.topAnchor.constraint(equalTo: leftEyeResultsLabel.bottomAnchor, constant: 50),
            doneButton.widthAnchor.constraint(equalToConstant: 242),
            doneButton.heightAnchor.constraint(equalToConstant: 50),
            doneButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
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
        
        doneButton.isHidden = false
        
        // Trigger CSV export only once
        if !hasTriggeredExport {
            hasTriggeredExport = true
            // Delay slightly to let the UI settle before showing prompts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.initiateCSVExport()
            }
        }
    }
    
    // Helper function to check if the result contains default/invalid values
    private func isDefaultValue(_ result: String) -> Bool {
        // Check for default values that indicate the eye wasn't actually tested
        return result.contains("-1.000") || result.contains("20/-1") || result.contains("LogMAR: -1")
    }

    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let instructionText = "Here are your test results. Your visual acuity scores are displayed for each eye tested. Tap 'Done' when you're finished reviewing your results."
        SharedAudioManager.shared.playText(instructionText, source: "Results")
    }

    /* Redoes the test.
    */
    @IBAction func redoTest(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    /* Saves the results of the test and navigates back to the main menu.
    */
    // @IBAction func tapDone(_ sender: Any) {
    //     // Store the final acuity score in the dictionary
    //     finalAcuityDictionary[eyeNumber] = String(format: "LogMAR: %.4f, Snellen: 20/%.0f", logMARValue, snellenValue)
    //     print(finalAcuityDictionary)
    //     // Increment eye number for the next test
    //     //eyeNumber += 1
    //     navigationController?.popToRootViewController(animated: true)
    // }

    /* Saves the results of the test and navigates back to the main menu.
    */
    @objc func doneButtonTapped() {
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
        
        // Reset all global variables to their initial state
        finalAcuityDictionary.removeAll()
        eyeNumber = 2
        finalAcuityScore = -Double.infinity
        logMARValue = -1.000
        snellenValue = -1
        
        // Navigate back to the main screen
        navigationController?.popToRootViewController(animated: true)
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
    
    /* Generates CSV and presents email composer.
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
        
        // Check if device can send email
        guard MFMailComposeViewController.canSendMail() else {
            print("📊 Device cannot send email")
            showCannotSendEmailAlert(csvContent: csvContent, fileName: fileName)
            return
        }
        
        // Create temporary CSV file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            print("📊 CSV file created at: \(tempURL.path)")
            
            // Store the temp file URL for cleanup later
            tempCSVFileURL = tempURL
            
            // Create mail composer
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            
            // Set recipient
            mailComposer.setToRecipients(["mabdel03@mit.edu"])
            
            // Set subject with patient name if available
            let subjectText: String
            if let (firstName, lastName) = nameManager.getSubjectName() {
                subjectText = "Visual Acuity Test Results - \(firstName) \(lastName)"
            } else {
                subjectText = "Visual Acuity Test Results"
            }
            mailComposer.setSubject(subjectText)
            
            // Set email body
            let bodyText = "Please find attached the visual acuity test results.\n\nTest Date: \(Date())\n"
            mailComposer.setMessageBody(bodyText, isHTML: false)
            
            // Attach CSV file
            if let csvData = try? Data(contentsOf: tempURL) {
                mailComposer.addAttachmentData(csvData, mimeType: "text/csv", fileName: fileName)
                print("📊 CSV attachment added: \(fileName)")
            }
            
            // Present mail composer
            present(mailComposer, animated: true) {
                print("📊 Mail composer presented")
            }
            
        } catch {
            print("📊 Error creating CSV file: \(error.localizedDescription)")
            showExportErrorAlert(error: error)
        }
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
    
    /* Shows alert when device cannot send email.
    */
    private func showCannotSendEmailAlert(csvContent: String, fileName: String) {
        let alert = UIAlertController(
            title: "Cannot Send Email",
            message: "Your device is not configured to send email. The CSV data has been saved and can be accessed from the Test History screen.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /* Shows alert when CSV export fails.
    */
    private func showExportErrorAlert(error: Error) {
        let alert = UIAlertController(
            title: "Export Error",
            message: "Failed to create CSV file: \(error.localizedDescription)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - MFMailComposeViewControllerDelegate
    
    /* Handles mail composer dismissal.
    */
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Clean up temporary CSV file
        if let tempURL = tempCSVFileURL {
            try? FileManager.default.removeItem(at: tempURL)
            print("📊 Cleaned up temporary file: \(tempURL.path)")
            tempCSVFileURL = nil
        }
        
        // Handle result
        switch result {
        case .sent:
            print("📊 Email sent successfully")
        case .saved:
            print("📊 Email saved as draft")
        case .cancelled:
            print("📊 Email cancelled by user")
        case .failed:
            print("📊 Email failed to send: \(error?.localizedDescription ?? "unknown error")")
        @unknown default:
            print("📊 Unknown mail composer result")
        }
        
        // Dismiss the mail composer
        controller.dismiss(animated: true)
    }

}
