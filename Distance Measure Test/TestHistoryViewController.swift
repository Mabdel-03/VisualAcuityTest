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
        
        // Add title label and clear button
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
            message: "All test history has been successfully deleted.",
            preferredStyle: .alert
        )
        successAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(successAlert, animated: true, completion: nil)
    }
} 
