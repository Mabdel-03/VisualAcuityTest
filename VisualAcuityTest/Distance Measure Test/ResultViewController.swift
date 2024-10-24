// ResultViewController.swift
import UIKit

class ResultViewController: UIViewController {
    // MARK: - Properties
    var score: Int = 0
    var totalAttempts: Int = 0
    
    // MARK: - UI Elements
    private lazy var scoreLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var acuityLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var recommendationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Try Again", for: .normal)
        button.addTarget(self, action: #selector(retryTest), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        print("ResultViewController - viewDidLoad")
        setupUI()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        print("ResultViewController - setupUI started")
        view.backgroundColor = .white
        title = "Test Results"
        
        // Add subviews
        view.addSubview(scoreLabel)
        view.addSubview(acuityLabel)
        view.addSubview(recommendationLabel)
        view.addSubview(doneButton)
        view.addSubview(retryButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            scoreLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            scoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scoreLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            acuityLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 20),
            acuityLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            acuityLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            recommendationLabel.topAnchor.constraint(equalTo: acuityLabel.bottomAnchor, constant: 40),
            recommendationLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            recommendationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            retryButton.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -20),
            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // Calculate and display results
        let percentage = (Double(score) / Double(totalAttempts)) * 100
        scoreLabel.text = String(format: "Score: %d/%d (%.1f%%)", score, totalAttempts, percentage)
        acuityLabel.text = "Visual Acuity Assessment: \(calculateAcuityAssessment(percentage: percentage))"
        recommendationLabel.text = getRecommendation(percentage: percentage)
        
        print("ResultViewController - setupUI completed")
    }
    
    // MARK: - Private Methods
    private func calculateAcuityAssessment(percentage: Double) -> String {
        switch percentage {
        case 90...100: return "Excellent"
        case 70..<90: return "Good"
        case 50..<70: return "Fair"
        default: return "Needs Attention"
        }
    }
    
    private func getRecommendation(percentage: Double) -> String {
        switch percentage {
        case 90...100:
            return "Your vision appears to be normal. Continue with regular eye check-ups."
        case 70..<90:
            return "Minor vision issues may be present. Consider scheduling an eye examination."
        case 50..<70:
            return "Moderate vision issues detected. We recommend consulting an eye care professional."
        default:
            return "Significant vision issues detected. Please schedule an appointment with an eye care professional as soon as possible."
        }
    }
    
    // MARK: - Actions
    @objc private func retryTest() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func doneButtonTapped() {
        navigationController?.popToRootViewController(animated: true)
    }
}
