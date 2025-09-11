import UIKit
import AVFoundation

/* TestHistoryViewController class is designed to display the test history scene.
    On this page, the user is given a list of all the tests they have completed.
*/
class TestHistoryViewController: UIViewController {
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
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.text = "Test History"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Clear All History", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0) // Red color for destructive action
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        button.layer.cornerRadius = 25
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(clearHistoryTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // Initially hidden
        return button
    }()
    
    private lazy var exportLeftEyeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📊 Export Left Eye CSV", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.318, green: 0.522, blue: 0.624, alpha: 1.0) // #51859F
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(exportLeftEyeCSVTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // Initially hidden
        return button
    }()
    
    private lazy var exportRightEyeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📊 Export Right Eye CSV", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.318, green: 0.522, blue: 0.624, alpha: 1.0) // #51859F
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(exportRightEyeCSVTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // Initially hidden
        return button
    }()
    
    private lazy var exportCombinedButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📊 Export Combined CSV", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0) // Green
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(exportCombinedCSVTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // Initially hidden
        return button
    }()
    
    private lazy var progressionDataLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.text = "Test Progression Data"
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true // Initially hidden
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        displayTestHistory()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
    }
    
    /* Plays audio instructions to the user.
    */
    private func playAudioInstructions() {
        let instructionText = "This screen shows your previous test results organized by date and time. You can review your visual acuity progress over time."
        SharedAudioManager.shared.playText(instructionText, source: "Test History")
    }
    
    /* Sets up the UI for the test history scene.
    */
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Add scroll view and content view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add title label and buttons
        contentView.addSubview(titleLabel)
        contentView.addSubview(clearButton)
        contentView.addSubview(progressionDataLabel)
        contentView.addSubview(exportLeftEyeButton)
        contentView.addSubview(exportRightEyeButton)
        contentView.addSubview(exportCombinedButton)
        
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
            
            // Title label constraints
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            
            // Clear button constraints
            clearButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            clearButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            clearButton.widthAnchor.constraint(equalToConstant: 200),
            clearButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Progression data label constraints
            progressionDataLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            progressionDataLabel.topAnchor.constraint(equalTo: clearButton.bottomAnchor, constant: 30),
            progressionDataLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            progressionDataLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            
            // Export buttons constraints
            exportLeftEyeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            exportLeftEyeButton.topAnchor.constraint(equalTo: progressionDataLabel.bottomAnchor, constant: 15),
            exportLeftEyeButton.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.45, constant: -15),
            exportLeftEyeButton.heightAnchor.constraint(equalToConstant: 44),
            
            exportRightEyeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            exportRightEyeButton.topAnchor.constraint(equalTo: progressionDataLabel.bottomAnchor, constant: 15),
            exportRightEyeButton.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.45, constant: -15),
            exportRightEyeButton.heightAnchor.constraint(equalToConstant: 44),
            
            exportCombinedButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            exportCombinedButton.topAnchor.constraint(equalTo: exportLeftEyeButton.bottomAnchor, constant: 10),
            exportCombinedButton.widthAnchor.constraint(equalToConstant: 200),
            exportCombinedButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    /* Displays the test history to the user.
    */
    private func displayTestHistory() {
        // Get test results from persistent storage
        let allTestsDictionary = TestDataManager.shared.getAllTests()
        
        // Check progression data availability
        let progressionDataCollector = TestProgressionDataCollector.shared
        let allProgressionData = progressionDataCollector.getAllStoredProgressionData()
        let hasProgressionData = !allProgressionData.isEmpty
        
        // Check if there are any tests
        if allTestsDictionary.isEmpty && !hasProgressionData {
            // Hide all buttons when no tests
            clearButton.isHidden = true
            hideAllExportButtons()
            
            let noTestsLabel = createLabel(text: "No test history available.\nComplete a test to see your results here.", fontSize: 18, weight: .regular)
            contentView.addSubview(noTestsLabel)
            
            NSLayoutConstraint.activate([
                noTestsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),
                noTestsLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                noTestsLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
                noTestsLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
                noTestsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
            ])
            return
        }
        
        // Show clear button when tests exist
        clearButton.isHidden = false
        
        // Show/hide export buttons based on progression data availability
        if hasProgressionData {
            showExportButtons(for: allProgressionData)
        } else {
            hideAllExportButtons()
        }
        
        var previousView: UIView = hasProgressionData ? exportCombinedButton : clearButton
        
        // Sort timestamps in descending order (newest first)
        let sortedTimestamps = allTestsDictionary.keys.sorted(by: >)
        
        for timestamp in sortedTimestamps {
            if let testResults = allTestsDictionary[timestamp] {
                // Create timestamp label
                let timestampLabel = createLabel(text: timestamp, fontSize: 20, weight: .semibold)
                contentView.addSubview(timestampLabel)
                
                NSLayoutConstraint.activate([
                    timestampLabel.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 30),
                    timestampLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                    timestampLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
                ])
                
                previousView = timestampLabel
                
                // Add right eye results
                if let rightEyeResult = testResults["Right Eye"] {
                    let displayText = isDefaultValue(rightEyeResult) ? "Right Eye: Not Tested" : "Right Eye: " + rightEyeResult
                    let rightEyeLabel = createLabel(text: displayText, fontSize: 18, weight: .regular)
                    contentView.addSubview(rightEyeLabel)
                    
                    NSLayoutConstraint.activate([
                        rightEyeLabel.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 10),
                        rightEyeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                        rightEyeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
                    ])
                    
                    previousView = rightEyeLabel
                }
                // Add left eye results
                if let leftEyeResult = testResults["Left Eye"] {
                    let displayText = isDefaultValue(leftEyeResult) ? "Left Eye: Not Tested" : "Left Eye: " + leftEyeResult
                    let leftEyeLabel = createLabel(text: displayText, fontSize: 18, weight: .regular)
                    contentView.addSubview(leftEyeLabel)
                    
                    NSLayoutConstraint.activate([
                        leftEyeLabel.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 10),
                        leftEyeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                        leftEyeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
                    ])
                    
                    previousView = leftEyeLabel
                }
            }
        }
        
        // Set the bottom constraint of the last view to the content view
        NSLayoutConstraint.activate([
            previousView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    /* Checks if the result contains default/invalid values.
    */
    private func isDefaultValue(_ result: String) -> Bool {
        // Check for default values that indicate the eye wasn't actually tested
        return result.contains("-1.000") || result.contains("20/-1") || result.contains("LogMAR: -1")
    }
    
    /* Creates a label for the test history scene.
    */
    private func createLabel(text: String, fontSize: CGFloat, weight: UIFont.Weight) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.textAlignment = .center
        label.textColor = UIColor.black
        label.numberOfLines = 0
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    /* Handles the clear history button tap with confirmation alert.
    */
    @objc private func clearHistoryTapped() {
        let alert = UIAlertController(
            title: "Clear Test History",
            message: "Are you sure you want to delete all test history? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let deleteAction = UIAlertAction(title: "Delete All", style: .destructive) { _ in
            self.clearAllTestHistory()
        }
        
        alert.addAction(cancelAction)
        alert.addAction(deleteAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    /* Clears all test history and refreshes the view.
    */
    private func clearAllTestHistory() {
        // Clear all test data
        TestDataManager.shared.clearAllTests()
        
        // Clear all progression data
        TestProgressionDataCollector.shared.clearAllProgressionData()
        
        // Remove all dynamically added subviews (except title and buttons)
        contentView.subviews.forEach { subview in
            if subview != titleLabel && subview != clearButton && 
               subview != progressionDataLabel && subview != exportLeftEyeButton && 
               subview != exportRightEyeButton && subview != exportCombinedButton {
                subview.removeFromSuperview()
            }
        }
        
        // Refresh the display
        displayTestHistory()
        
        // Show confirmation
        let successAlert = UIAlertController(
            title: "History Cleared",
            message: "All test history and progression data has been successfully deleted.",
            preferredStyle: .alert
        )
        successAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(successAlert, animated: true, completion: nil)
    }
    
    // MARK: - Export Button Management
    
    /*
     * Shows export buttons based on available data
     */
    private func showExportButtons(for progressionData: [TestResponseData]) {
        progressionDataLabel.isHidden = false
        
        let leftEyeData = progressionData.filter { $0.eye == "Left" }
        let rightEyeData = progressionData.filter { $0.eye == "Right" }
        
        exportLeftEyeButton.isHidden = leftEyeData.isEmpty
        exportRightEyeButton.isHidden = rightEyeData.isEmpty
        exportCombinedButton.isHidden = false
        
        // Update button titles with data counts
        if !leftEyeData.isEmpty {
            exportLeftEyeButton.setTitle("📊 Export Left Eye CSV (\(leftEyeData.count) responses)", for: .normal)
        }
        if !rightEyeData.isEmpty {
            exportRightEyeButton.setTitle("📊 Export Right Eye CSV (\(rightEyeData.count) responses)", for: .normal)
        }
        exportCombinedButton.setTitle("📊 Export Combined CSV (\(progressionData.count) responses)", for: .normal)
    }
    
    /*
     * Hides all export buttons
     */
    private func hideAllExportButtons() {
        progressionDataLabel.isHidden = true
        exportLeftEyeButton.isHidden = true
        exportRightEyeButton.isHidden = true
        exportCombinedButton.isHidden = true
    }
    
    // MARK: - Export Actions
    
    @objc private func exportLeftEyeCSVTapped() {
        exportCSV(for: "Left")
    }
    
    @objc private func exportRightEyeCSVTapped() {
        exportCSV(for: "Right")
    }
    
    @objc private func exportCombinedCSVTapped() {
        exportCSV(for: nil) // nil means combined data
    }
    
    /*
     * Exports CSV data for the specified eye or combined data
     */
    private func exportCSV(for eye: String?) {
        let progressionDataCollector = TestProgressionDataCollector.shared
        
        let csvContent: String
        let fileName: String
        
        if let eye = eye {
            csvContent = progressionDataCollector.generateCSV(for: eye)
            fileName = "visual_acuity_\(eye.lowercased())_eye_data.csv"
        } else {
            csvContent = progressionDataCollector.generateCombinedCSV()
            fileName = "visual_acuity_combined_data.csv"
        }
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Present activity view controller for sharing
            let activityViewController = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            // For iPad compatibility
            if let popoverController = activityViewController.popoverPresentationController {
                if let eye = eye {
                    let button = eye == "Left" ? exportLeftEyeButton : exportRightEyeButton
                    popoverController.sourceView = button
                    popoverController.sourceRect = button.bounds
                } else {
                    popoverController.sourceView = exportCombinedButton
                    popoverController.sourceRect = exportCombinedButton.bounds
                }
            }
            
            // Add completion handler to clean up temporary file
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: tempURL)
            }
            
            present(activityViewController, animated: true)
            
            // Play audio feedback
            if SharedAudioManager.shared.isAudioEnabled() {
                let eyeText = eye ?? "combined"
                SharedAudioManager.shared.playText("Exporting \(eyeText) test data", source: "Test History")
            }
            
        } catch {
            // Show error alert
            let errorAlert = UIAlertController(
                title: "Export Error",
                message: "Failed to create CSV file: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
            present(errorAlert, animated: true)
        }
    }
} 
