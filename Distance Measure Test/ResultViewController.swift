import UIKit
var finalAcuityDictionary: [Int: String] = [:] // Dictionary to store final acuity values
var eyeNumber: Int = 1 // 1 for left eye, 2 for right eye
var allTestsDictionary: [String: [String: String]] = [:] // Dictionary to store all test results
class ResultViewController: UIViewController {
    // MARK: - Properties
    var score: Int = 0
    var totalAttempts: Int = 0
    var logMARValue: Double = 0
    var snellenValue: Double = 0
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
    
    private lazy var rightEyeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Test Right Eye", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemBlue
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(startRightEyeTest), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
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
    
//    private lazy var retryButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Try Again", for: .normal)
//        button.setTitleColor(.white, for: .normal)
//        button.backgroundColor = UIColor.systemGreen
//        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
//        button.layer.cornerRadius = 10
//        button.addTarget(self, action: #selector(retryTest), for: .touchUpInside)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        return button
//    }()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
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
        contentView.addSubview(rightEyeButton)
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
            
            // Right eye button constraints
            rightEyeButton.topAnchor.constraint(equalTo: rightEyeResultsLabel.bottomAnchor, constant: 50),
            rightEyeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            rightEyeButton.widthAnchor.constraint(equalToConstant: 200),
            rightEyeButton.heightAnchor.constraint(equalToConstant: 50),
            rightEyeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
            
            // Done button constraints
            doneButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            doneButton.topAnchor.constraint(equalTo: rightEyeResultsLabel.bottomAnchor, constant: 50),
            doneButton.widthAnchor.constraint(equalToConstant: 200),
            doneButton.heightAnchor.constraint(equalToConstant: 50),
            doneButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
        
        // Calculate and display results
//        let percentage = (Double(score) / Double(totalAttempts)) * 100
        
        updateResults()
        
//        // Display the recommendation
//        recommendationLabel.text = getRecommendation(acuity: finalAcuityScore)
    }

    func updateResults() {
        logMARValue = finalAcuityScore
        snellenValue = 20 * pow(10, logMARValue)
        
        // Store the current eye's results
        finalAcuityDictionary[eyeNumber] = String(format: "LogMAR: %.4f, Snellen: 20/%.0f", logMARValue, snellenValue)
        
        if eyeNumber == 1 {
            // Left eye
            leftEyeResultsLabel.text = String(format: "LogMAR Score: %.4f\nSnellen Score: 20/%.0f", 
                                            finalAcuityScore, snellenValue)
            rightEyeResultsLabel.text = "Not tested yet"
            rightEyeButton.isHidden = false
            doneButton.isHidden = true
        } else if eyeNumber == 2 {
            // Right eye
            // Get both eyes' results from the dictionary
            if let leftEyeResult = finalAcuityDictionary[1] {
                leftEyeResultsLabel.text = leftEyeResult.replacingOccurrences(of: "LogMAR: ", with: "LogMAR Score: ")
                                                      .replacingOccurrences(of: "Snellen: ", with: "Snellen Score: ")
            }
            if let rightEyeResult = finalAcuityDictionary[2] {
                rightEyeResultsLabel.text = rightEyeResult.replacingOccurrences(of: "LogMAR: ", with: "LogMAR Score: ")
                                                        .replacingOccurrences(of: "Snellen: ", with: "Snellen Score: ")
            }
            rightEyeButton.isHidden = true
            doneButton.isHidden = false
        }
    }

    // MARK: - Private Methods

//    private func getRecommendation(acuity: Double) -> String {
//        switch acuity {
//        case 16..<40:
//            return "Your vision appears to be normal. Continue with regular eye check-ups."
//        case 40..<85:
//            return "Minor vision issues may be present. Consider scheduling an eye examination."
//        case 85..<150:
//            return "Moderate vision issues detected. We recommend consulting an eye care professional."
//        default:
//            return "Significant vision issues detected. Please schedule an appointment with an eye care professional as soon as possible."
//        }
//    }
//    
    // MARK: - Actions
    @IBAction func redoTest(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func tapDone(_ sender: Any) {
        // Store the final acuity score in the dictionary
                finalAcuityDictionary[eyeNumber] = String(format: "LogMAR: %.4f, Snellen: 20/%.0f", logMARValue, snellenValue)
        print(finalAcuityDictionary)
        // Increment eye number for the next test
        eyeNumber += 1
        navigationController?.popToRootViewController(animated: true)
    }
    
    @objc func startRightEyeTest() {
        // Store the left eye's results
        finalAcuityDictionary[1] = String(format: "LogMAR: %.4f, Snellen: 20/%.0f", logMARValue, snellenValue)
        
        // Set eye number for right eye test
        eyeNumber = 2
        
        // Navigate back to the capture acuity page
        if let captureVC = navigationController?.viewControllers.first(where: { $0 is DistanceOptimization }) {
            navigationController?.popToViewController(captureVC, animated: true)
        }
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
        
        // Navigate back to the main screen
        navigationController?.popToRootViewController(animated: true)
    }
}
