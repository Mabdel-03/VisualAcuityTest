private lazy var historyButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("View Test History", for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
    button.setTitleColor(UIColor.white, for: .normal)
    button.backgroundColor = UIColor.systemBlue
    button.layer.cornerRadius = 10
    button.addTarget(self, action: #selector(historyButtonTapped), for: .touchUpInside)
    button.translatesAutoresizingMaskIntoConstraints = false
    return button
}()

private func setupUI() {
    // ... existing code ...
    
    // Add history button
    view.addSubview(historyButton)
    
    NSLayoutConstraint.activate([
        // ... existing constraints ...
        
        // History button constraints
        historyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        historyButton.topAnchor.constraint(equalTo: rightEyeButton.bottomAnchor, constant: 20),
        historyButton.widthAnchor.constraint(equalToConstant: 200),
        historyButton.heightAnchor.constraint(equalToConstant: 50)
    ])
}

@objc private func historyButtonTapped() {
    let historyVC = TestHistoryViewController()
    navigationController?.pushViewController(historyVC, animated: true)
} 