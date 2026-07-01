import UIKit
import AVFoundation

/* TestHistoryViewController class is designed to display the test history scene.
    On this page, the user is given a list of all the tests they have completed.
*/
class TestHistoryViewController: UIViewController {
    // Stores test data keyed by button tag so per-test share buttons can retrieve it
    private var testShareData: [Int: (timestamp: String, testResults: [String: String])] = [:]
    private var shareButtonCounter = 0

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
        label.drawHeader()
        label.textAlignment = .center
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
        
        // Add decorative circles
        addDecorativeCircles()
        
        // Add scroll view and content view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add title label and clear button (export buttons will be added dynamically)
        contentView.addSubview(titleLabel)
        contentView.addSubview(clearButton)
        
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
            clearButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    /* Displays the test history to the user.
    */
    private func displayTestHistory() {
        // Get test results from persistent storage
        let allTestsDictionary = TestDataManager.shared.getAllTests()

        // Check if there are any tests
        if allTestsDictionary.isEmpty {
            // Hide clear button when no tests
            clearButton.isHidden = true
            
            let noTestsLabel = UILabel()
            noTestsLabel.text = "No test history available.\nComplete a test to see your results here."
            noTestsLabel.textAlignment = .center
            noTestsLabel.numberOfLines = 0
            noTestsLabel.drawSmallText()
            noTestsLabel.translatesAutoresizingMaskIntoConstraints = false
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
        testShareData.removeAll()
        shareButtonCounter = 0
        var previousView: UIView = clearButton

        // Sort timestamps in descending order (newest first)
        let sortedTimestamps = allTestsDictionary.keys.sorted(by: >)

        for timestamp in sortedTimestamps {
            if let testResults = allTestsDictionary[timestamp] {
                // Create timestamp label
                let timestampLabel = createLabel(text: timestamp, fontSize: 20, weight: .semibold)
                contentView.addSubview(timestampLabel)

                NSLayoutConstraint.activate([
                    timestampLabel.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 30),
                    timestampLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                    timestampLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
                    timestampLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20)
                ])

                previousView = timestampLabel

                // Add right eye results
                if let rightEyeResult = testResults["Right Eye"] {
                    let displayText = isDefaultValue(rightEyeResult) ? "Right Eye: Not Tested" : "Right Eye: " + rightEyeResult
                    let rightEyeLabel = createLabel(text: displayText, fontSize: 18, weight: .regular)
                    contentView.addSubview(rightEyeLabel)

                    NSLayoutConstraint.activate([
                        rightEyeLabel.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 15),
                        rightEyeLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                        rightEyeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
                        rightEyeLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20)
                    ])

                    previousView = rightEyeLabel
                }

                // Add left eye results
                if let leftEyeResult = testResults["Left Eye"] {
                    let displayText = isDefaultValue(leftEyeResult) ? "Left Eye: Not Tested" : "Left Eye: " + leftEyeResult
                    let leftEyeLabel = createLabel(text: displayText, fontSize: 18, weight: .regular)
                    contentView.addSubview(leftEyeLabel)

                    NSLayoutConstraint.activate([
                        leftEyeLabel.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 15),
                        leftEyeLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                        leftEyeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
                        leftEyeLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20)
                    ])

                    previousView = leftEyeLabel
                }

                // Per-test save/share button
                let shareButton = createPerTestShareButton(tag: shareButtonCounter)
                testShareData[shareButtonCounter] = (timestamp: timestamp, testResults: testResults)
                shareButtonCounter += 1
                contentView.addSubview(shareButton)

                NSLayoutConstraint.activate([
                    shareButton.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 12),
                    shareButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                    shareButton.widthAnchor.constraint(equalToConstant: 220),
                    shareButton.heightAnchor.constraint(equalToConstant: 44)
                ])

                previousView = shareButton
            }
        }
        
        // Share All button — exports every test in history with participant name
        let shareAllButton = UIButton(type: .system)
        shareAllButton.setTitle("Share All Tests", for: .normal)
        shareAllButton.drawStandardButton()
        shareAllButton.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        shareAllButton.addTarget(self, action: #selector(shareAllTapped), for: .touchUpInside)
        shareAllButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shareAllButton)

        NSLayoutConstraint.activate([
            shareAllButton.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 30),
            shareAllButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shareAllButton.widthAnchor.constraint(equalToConstant: 240),
            shareAllButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        previousView = shareAllButton
        
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
        
        // Clear subject name for privacy
        SubjectNameManager.shared.clearSubjectName()
        
        // Remove all dynamically added subviews (except title and clear button)
        contentView.subviews.forEach { subview in
            if subview != titleLabel && subview != clearButton {
                subview.removeFromSuperview()
            }
        }
        
        // Refresh the display
        displayTestHistory()
        
        // Show confirmation
        let successAlert = UIAlertController(
            title: "History Cleared",
            message: "All test history, progression data, and subject information has been successfully deleted.",
            preferredStyle: .alert
        )
        successAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(successAlert, animated: true, completion: nil)
    }
    
    // MARK: - Share All Tests

    @objc private func shareAllTapped() {
        performShareAll()
    }

    private func performShareAll() {
        let allProgressionData = TestProgressionDataCollector.shared.getAllStoredProgressionData()
        guard !allProgressionData.isEmpty else { return }

        // Build a lookup: for each history entry, what timestamp window does it cover
        // and what name was stored when it was individually shared?
        let allTests = TestDataManager.shared.getAllTests()
        let historyFormatter = DateFormatter()
        historyFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let sortedTimestampsAsc = allTests.keys.sorted(by: <)

        // Pre-compute (lowerBound, saveDate, name) tuples for efficient per-row lookup
        let windows: [(lower: Date, upper: Date, name: String)] = sortedTimestampsAsc.enumerated().compactMap { idx, ts in
            guard let saveDate = historyFormatter.date(from: ts) else { return nil }
            let lower: Date = idx > 0
                ? (historyFormatter.date(from: sortedTimestampsAsc[idx - 1]) ?? Date.distantPast)
                : Date.distantPast
            let name = allTests[ts]?["Name"] ?? "Unknown"
            return (lower: lower, upper: saveDate, name: name)
        }

        let responseFormatter = DateFormatter()
        responseFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        var csv = "Name,Timestamp,Eye,Test_Type,Acuity_Level,Letter_Displayed,Distance_CM,Response_Time_MS,User_Response,Is_Correct,Trial_Number,Session_ID\n"
        for r in allProgressionData.sorted(by: { $0.timestamp < $1.timestamp }) {
            let participantName = windows.first(where: {
                r.timestamp > $0.lower && r.timestamp <= $0.upper
            })?.name ?? "Unknown"

            let row = (["\"\(participantName)\""] + [
                responseFormatter.string(from: r.timestamp),
                r.eye, r.testType, r.acuityLevel, r.letterDisplayed,
                String(format: "%.1f", r.distanceCM),
                String(r.responseTimeMS),
                r.userResponse,
                r.isCorrect ? "TRUE" : "FALSE",
                String(r.trialNumber),
                r.sessionId
            ]).joined(separator: ",")
            csv += row + "\n"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "visual_acuity_all_tests_\(dateFormatter.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: tempURL)
            }
            present(activityVC, animated: true)
        } catch {
            let alert = UIAlertController(
                title: "Export Error",
                message: "Failed to create file: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - Per-Test Share

    private func createPerTestShareButton(tag: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Share", for: .normal)
        button.drawStandardButton()
        button.backgroundColor = AppThemeColors.actionBlue
        button.tag = tag
        button.addTarget(self, action: #selector(perTestShareTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    @objc private func perTestShareTapped(_ sender: UIButton) {
        guard let entry = testShareData[sender.tag] else { return }
        promptForSubjectName(allowSkip: true) { [weak self] success in
            guard let self = self, success else { return }

            // Persist the name into this test's history entry so Share All can read it later
            var updatedResults = entry.testResults
            if let stored = SubjectNameManager.shared.getSubjectName() {
                updatedResults["Name"] = "\(stored.firstName) \(stored.lastName)"
                    .replacingOccurrences(of: "_", with: " ")
                TestDataManager.shared.saveTestResults(updatedResults, for: entry.timestamp)
                self.testShareData[sender.tag] = (timestamp: entry.timestamp, testResults: updatedResults)
            }

            self.shareTestResult(timestamp: entry.timestamp, testResults: updatedResults)
        }
    }

    private func shareTestResult(timestamp: String, testResults: [String: String]) {
        let historyFormatter = DateFormatter()
        historyFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let saveDate = historyFormatter.date(from: timestamp) else { return }

        // Lower bound = the save timestamp of the previous history entry (so we only
        // include responses that occurred during this specific test session).
        let allTests = TestDataManager.shared.getAllTests()
        let sortedAsc = allTests.keys.sorted(by: <)
        let lowerBound: Date
        if let idx = sortedAsc.firstIndex(of: timestamp), idx > 0 {
            lowerBound = historyFormatter.date(from: sortedAsc[idx - 1]) ?? Date.distantPast
        } else {
            lowerBound = Date.distantPast
        }

        // Participant name (already prompted before this is called)
        let nameManager = SubjectNameManager.shared
        let participantName: String
        if let stored = nameManager.getSubjectName() {
            participantName = "\(stored.firstName) \(stored.lastName)"
                .replacingOccurrences(of: "_", with: " ")
        } else {
            participantName = "Unknown"
        }

        // Grab only the progression rows that belong to this test window.
        let allProgressionData = TestProgressionDataCollector.shared.getAllStoredProgressionData()
        let sessionData = allProgressionData.filter {
            $0.timestamp > lowerBound && $0.timestamp <= saveDate
        }.sorted { $0.timestamp < $1.timestamp }

        let csvContent: String
        if sessionData.isEmpty {
            // No detailed data saved for this session — fall back to summary.
            let right = isDefaultValue(testResults["Right Eye"] ?? "") ? "Not Tested" : (testResults["Right Eye"] ?? "Not Tested")
            let left  = isDefaultValue(testResults["Left Eye"]  ?? "") ? "Not Tested" : (testResults["Left Eye"]  ?? "Not Tested")
            csvContent = "Name,Test_Date,Right_Eye_Result,Left_Eye_Result\n\"\(participantName)\",\"\(timestamp)\",\"\(right)\",\"\(left)\"\n"
        } else {
            let responseFormatter = DateFormatter()
            responseFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            var csv = "Name,Timestamp,Eye,Test_Type,Acuity_Level,Letter_Displayed,Distance_CM,Response_Time_MS,User_Response,Is_Correct,Trial_Number,Session_ID\n"
            for r in sessionData {
                let row = (["\"\(participantName)\""] + [
                    responseFormatter.string(from: r.timestamp),
                    r.eye, r.testType, r.acuityLevel, r.letterDisplayed,
                    String(format: "%.1f", r.distanceCM),
                    String(r.responseTimeMS),
                    r.userResponse,
                    r.isCorrect ? "TRUE" : "FALSE",
                    String(r.trialNumber),
                    r.sessionId
                ]).joined(separator: ",")
                csv += row + "\n"
            }
            csvContent = csv
        }

        let safeName = timestamp
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let fileName = nameManager.generateCSVFilename(withSuffix: safeName) ?? "visual_acuity_\(safeName).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: tempURL)
            }
            present(activityVC, animated: true)
        } catch {
            let alert = UIAlertController(
                title: "Export Error",
                message: "Failed to create file: \(error.localizedDescription)",
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
            size: 110,
            petalColor: UIColor(red: 0.224, green: 0.424, blue: 0.427, alpha: 1.0),
            centerColor: UIColor(red: 0.251, green: 0.427, blue: 0.455, alpha: 1.0),
            alpha: 0.12,
            leadingOffset: 15,
            topOffset: 80
        )
        
        // Decorative daisy 2 - bottom right (magenta)
        addDecorativeDaisy(
            size: 100,
            petalColor: UIColor(red: 0.788, green: 0.169, blue: 0.369, alpha: 1.0),
            centerColor: UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0),
            alpha: 0.1,
            trailingOffset: 20,
            bottomOffset: 100
        )
    }
} 
