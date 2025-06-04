import UIKit
import AVFoundation

var finalAcuityDictionary: [Int: String] = [:] // Dictionary to store final acuity values
var eyeNumber: Int = 1 // 1 for left eye, 2 for right eye
var allTestsDictionary: [String: [String: String]] = [:] // Dictionary to store all test results
var logMARValue: Double = -1.000
var snellenValue: Double = -1

class ResultViewController: UIViewController {
    // MARK: - Properties
    var score: Int = 0
    var totalAttempts: Int = 0
    
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
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playAudioInstructions()
    }
    
    // MARK: - Setup Methods
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
            
            // Left eye title constraints
            leftEyeTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            leftEyeTitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 100),
            leftEyeTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            leftEyeTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            
            // Left eye results constraints
            leftEyeResultsLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            leftEyeResultsLabel.topAnchor.constraint(equalTo: leftEyeTitleLabel.bottomAnchor, constant: 20),
            leftEyeResultsLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            leftEyeResultsLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            
            // Right eye title constraints
            rightEyeTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            rightEyeTitleLabel.topAnchor.constraint(equalTo: leftEyeResultsLabel.bottomAnchor, constant: 50),
            rightEyeTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            rightEyeTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            
            // Right eye results constraints
            rightEyeResultsLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            rightEyeResultsLabel.topAnchor.constraint(equalTo: rightEyeTitleLabel.bottomAnchor, constant: 20),
            rightEyeResultsLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            rightEyeResultsLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
//            
            // Done button constraints
            doneButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            doneButton.topAnchor.constraint(equalTo: rightEyeResultsLabel.bottomAnchor, constant: 50),
            doneButton.widthAnchor.constraint(equalToConstant: 200),
            doneButton.heightAnchor.constraint(equalToConstant: 50),
            doneButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
        
        displayResults()
    }

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
    }
    
    // Helper function to check if the result contains default/invalid values
    private func isDefaultValue(_ result: String) -> Bool {
        // Check for default values that indicate the eye wasn't actually tested
        return result.contains("-1.000") || result.contains("20/-1") || result.contains("LogMAR: -1")
    }

    // MARK: - Private Methods

    // MARK: - Actions
    @IBAction func redoTest(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func tapDone(_ sender: Any) {
        // Store the final acuity score in the dictionary
                finalAcuityDictionary[eyeNumber] = String(format: "LogMAR: %.4f, Snellen: 20/%.0f", logMARValue, snellenValue)
        print(finalAcuityDictionary)
        // Increment eye number for the next test
        //eyeNumber += 1
        navigationController?.popToRootViewController(animated: true)
    }

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
        allTestsDictionary[timestamp] = testResults
        
        // Reset all global variables to their initial state
        finalAcuityDictionary.removeAll()
        eyeNumber = 1
        finalAcuityScore = -Double.infinity
        logMARValue = -1.000
        snellenValue = -1
        
        // Navigate back to the main screen
        navigationController?.popToRootViewController(animated: true)
    }

    private func playAudioInstructions() {
        let instructionText = "Here are your test results. Your visual acuity scores are displayed for each eye tested. Tap 'Done' when you're finished reviewing your results."
        SharedAudioManager.shared.playText(instructionText, source: "Results")
    }
}
