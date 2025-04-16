//
//  Main Menu.swift
//  Distance Measure Test
//
//  Created by Anderson Men on 8/7/23.
//

import UIKit

class MainMenu: UIViewController {
    // MARK: - Properties
    private lazy var completedTestsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Completed Tests", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .clear
        button.titleLabel?.font = UIFont.systemFont(ofSize: 30)
        button.addTarget(self, action: #selector(completedTestsButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Add completed tests button
        view.addSubview(completedTestsButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            completedTestsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 75),
            completedTestsButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 559),
            completedTestsButton.widthAnchor.constraint(equalToConstant: 242),
            completedTestsButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Actions
    @objc private func completedTestsButtonTapped() {
        let testHistoryVC = TestHistoryViewController()
        navigationController?.pushViewController(testHistoryVC, animated: true)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
}
