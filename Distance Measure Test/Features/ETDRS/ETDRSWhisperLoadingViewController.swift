//
//  ETDRSWhisperLoadingViewController.swift
//  Distance Measure Test
//
//  Shows WhisperKit model loading progress immediately before the ETDRS test.
//

import UIKit

final class ETDRSWhisperLoadingViewController: UIViewController {
    enum LaunchPurpose {
        case appStartup
        case beforeETDRSTest
    }

    private let whisperLetterService = ETDRSWhisperLetterService.shared
    private let launchPurpose: LaunchPurpose
    private var hasStartedLoading = false
    private var isReadyToStart = false
    private var hasRoutedForward = false

    private lazy var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.97, green: 0.98, blue: 0.95, alpha: 1.0).cgColor,
            UIColor(red: 0.93, green: 0.96, blue: 0.98, alpha: 1.0).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.0, y: 0.0)
        layer.endPoint = CGPoint(x: 1.0, y: 1.0)
        return layer
    }()

    private lazy var loadingCard: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white.withAlphaComponent(0.88)
        view.layer.cornerRadius = 28
        view.layer.cornerCurve = .continuous
        view.layer.shadowColor = AppThemeColors.black.withAlphaComponent(0.08).cgColor
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = 30
        view.layer.shadowOffset = CGSize(width: 0, height: 14)
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading Speech Model"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 30, weight: .bold)
        label.textColor = UIColor(red: 0.19, green: 0.29, blue: 0.31, alpha: 1.0)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "WhisperKit is getting ready before the ETDRS test begins."
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        label.textColor = AppThemeColors.systemGrey
        return label
    }()

    private lazy var flowerView: DaisyFlowerView = {
        let flower = DaisyFlowerView(
            numberOfPetals: 18,
            petalColor: AppThemeColors.magentaAccent,
            centerColor: UIColor(red: 1.0, green: 0.97, blue: 0.84, alpha: 1.0)
        )
        flower.translatesAutoresizingMaskIntoConstraints = false
        return flower
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Preparing speech model..."
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 0.30, green: 0.35, blue: 0.37, alpha: 1.0)
        return label
    }()

    private lazy var progressPercentLabel: UILabel = {
        let label = UILabel()
        label.text = "0%"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        label.textColor = UIColor(red: 0.19, green: 0.29, blue: 0.31, alpha: 1.0)
        return label
    }()

    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = AppThemeColors.teal
        progressView.trackTintColor = UIColor(red: 0.88, green: 0.91, blue: 0.90, alpha: 1.0)
        progressView.transform = CGAffineTransform(scaleX: 1.0, y: 3.2)
        progressView.layer.cornerRadius = 6
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        return progressView
    }()

    private lazy var startButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("Start Test", for: .normal)
        button.drawStandardButton()
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        button.alpha = 0.0
        button.addTarget(self, action: #selector(startTestTapped), for: .touchUpInside)
        return button
    }()

    init(launchPurpose: LaunchPurpose = .beforeETDRSTest) {
        self.launchPurpose = launchPurpose
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)
        navigationItem.hidesBackButton = (launchPurpose == .appStartup)
        setupUI()
        observeWhisperLoadingProgress()
        updateLoadingUI(
            progress: whisperLetterService.loadingProgress,
            status: whisperLetterService.loadingStatus
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetLoadingStateForAppearance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startLoadingIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        view.addSubview(flowerView)
        view.addSubview(loadingCard)
        loadingCard.addSubview(titleLabel)
        loadingCard.addSubview(subtitleLabel)
        loadingCard.addSubview(progressPercentLabel)
        loadingCard.addSubview(progressView)
        loadingCard.addSubview(statusLabel)
        loadingCard.addSubview(startButton)

        NSLayoutConstraint.activate([
            flowerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            flowerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -184),
            flowerView.widthAnchor.constraint(equalToConstant: 120),
            flowerView.heightAnchor.constraint(equalToConstant: 120),

            loadingCard.topAnchor.constraint(equalTo: flowerView.bottomAnchor, constant: 34),
            loadingCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 26),
            loadingCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -26),

            titleLabel.topAnchor.constraint(equalTo: loadingCard.topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: loadingCard.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: loadingCard.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: loadingCard.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: loadingCard.trailingAnchor, constant: -24),

            progressPercentLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 26),
            progressPercentLabel.centerXAnchor.constraint(equalTo: loadingCard.centerXAnchor),

            progressView.topAnchor.constraint(equalTo: progressPercentLabel.bottomAnchor, constant: 18),
            progressView.leadingAnchor.constraint(equalTo: loadingCard.leadingAnchor, constant: 28),
            progressView.trailingAnchor.constraint(equalTo: loadingCard.trailingAnchor, constant: -28),

            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: loadingCard.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: loadingCard.trailingAnchor, constant: -24),

            startButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            startButton.centerXAnchor.constraint(equalTo: loadingCard.centerXAnchor),
            startButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 168),
            startButton.heightAnchor.constraint(equalToConstant: 50),
            startButton.bottomAnchor.constraint(equalTo: loadingCard.bottomAnchor, constant: -28)
        ])
    }

    private func observeWhisperLoadingProgress() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(whisperLoadingProgressChanged(_:)),
            name: ETDRSWhisperLetterService.loadingProgressDidChangeNotification,
            object: nil
        )
    }

    private func startLoadingIfNeeded() {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true

        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.whisperLetterService.prepareIfNeeded()
                await MainActor.run {
                    self.showReadyState()
                }
            } catch {
                await MainActor.run {
                    self.showLoadingError(error)
                }
            }
        }
    }

    @objc private func whisperLoadingProgressChanged(_ notification: Notification) {
        guard !isReadyToStart else { return }
        let progress = notification.userInfo?[ETDRSWhisperLetterService.loadingProgressKey] as? Double ?? 0.0
        let status = notification.userInfo?[ETDRSWhisperLetterService.loadingStatusKey] as? String ?? "Preparing speech model..."
        Task { @MainActor [weak self] in
            self?.updateLoadingUI(progress: progress, status: status)
        }
    }

    private func updateLoadingUI(progress: Double, status: String) {
        guard !isReadyToStart else { return }
        statusLabel.text = status
        progressView.setProgress(Float(progress), animated: true)
        progressPercentLabel.text = "\(Int((progress * 100).rounded()))%"
    }

    private func showReadyState() {
        guard !isReadyToStart else { return }
        isReadyToStart = true
        titleLabel.text = launchPurpose == .appStartup ? "Speech Model Ready" : "Model Ready"
        subtitleLabel.text = launchPurpose == .appStartup
            ? "WhisperKit is ready. Opening the main menu now."
            : "The ETDRS speech model is loaded. Start when you are ready for the test screen."
        statusLabel.text = "WhisperKit ready."
        progressView.setProgress(1.0, animated: true)
        progressPercentLabel.text = "100%"

        guard launchPurpose == .beforeETDRSTest else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.routeForwardIfPossible()
            }
            return
        }

        startButton.isHidden = false

        UIView.animate(withDuration: 0.25) {
            self.startButton.alpha = 1.0
        }
    }

    private func resetLoadingStateForAppearance() {
        hasStartedLoading = false
        isReadyToStart = false
        hasRoutedForward = false
        titleLabel.text = "Loading Speech Model"
        subtitleLabel.text = "WhisperKit is getting ready before the ETDRS test begins."
        statusLabel.text = "Preparing speech model..."
        progressPercentLabel.text = "0%"
        progressView.setProgress(0.0, animated: false)
        startButton.isHidden = true
        startButton.alpha = 0.0
    }

    @objc private func startTestTapped() {
        routeForwardIfPossible()
    }

    private func routeForwardIfPossible() {
        guard isReadyToStart, !hasRoutedForward else { return }
        hasRoutedForward = true

        switch launchPurpose {
        case .appStartup:
            openMainMenu()
        case .beforeETDRSTest:
            openETDRSTest()
        }
    }

    private func openETDRSTest() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let etdrsVC = storyboard.instantiateViewController(withIdentifier: "ETDRSViewController") as? ETDRSViewController else {
            hasRoutedForward = false
            showMissingTestScreenAlert()
            return
        }

        guard let navigationController else {
            return
        }

        var viewControllers = navigationController.viewControllers
        if let index = viewControllers.firstIndex(of: self) {
            viewControllers[index] = etdrsVC
            navigationController.setViewControllers(viewControllers, animated: true)
        } else {
            navigationController.pushViewController(etdrsVC, animated: true)
        }
    }

    private func openMainMenu() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard
            let storyboardNavigationController = storyboard.instantiateInitialViewController() as? UINavigationController,
            let mainMenuVC = storyboardNavigationController.viewControllers.first
        else {
            hasRoutedForward = false
            showMissingMainMenuAlert()
            return
        }

        navigationController?.setViewControllers([mainMenuVC], animated: true)
    }

    private func showLoadingError(_ error: Error) {
        isReadyToStart = false
        hasRoutedForward = false

        let alert = UIAlertController(
            title: "WhisperKit Couldn't Load",
            message: error.localizedDescription,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            guard let self else { return }
            self.hasStartedLoading = false
            self.startButton.isHidden = true
            self.startButton.alpha = 0.0
            self.startLoadingIfNeeded()
        })

        let secondaryActionTitle = launchPurpose == .appStartup ? "Close" : "Back"
        let secondaryActionStyle: UIAlertAction.Style = launchPurpose == .appStartup ? .destructive : .cancel
        alert.addAction(UIAlertAction(title: secondaryActionTitle, style: secondaryActionStyle) { [weak self] _ in
            if self?.launchPurpose == .appStartup {
                exit(0)
            } else {
                self?.navigationController?.popViewController(animated: true)
            }
        })

        present(alert, animated: true)
    }

    private func showMissingTestScreenAlert() {
        let alert = UIAlertController(
            title: "ETDRS Screen Missing",
            message: "The ETDRS test screen could not be opened from the storyboard.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Back", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showMissingMainMenuAlert() {
        let alert = UIAlertController(
            title: "Main Menu Missing",
            message: "The main menu could not be opened from the storyboard.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Close", style: .destructive))
        present(alert, animated: true)
    }
}
