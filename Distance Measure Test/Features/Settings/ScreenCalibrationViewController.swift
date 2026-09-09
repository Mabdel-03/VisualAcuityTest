import UIKit

final class ScreenCalibrationViewController: UIViewController {
    var completion: ((ScreenCalibration) -> Void)?

    private let calibrationLengthMillimeters = 50.0
    private let calibrationProvider: ScreenCalibrationProvider
    private var rulerHeightConstraint: NSLayoutConstraint!

    var rulerHeightPoints: CGFloat { rulerHeightConstraint?.constant ?? 0 }

    init(calibrationProvider: ScreenCalibrationProvider = .shared) {
        self.calibrationProvider = calibrationProvider
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        calibrationProvider = .shared
        super.init(coder: coder)
    }

    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Place a physical ruler against the screen and adjust the vertical line to exactly 50 mm."
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var calibrationRuler: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let line = UIView()
        line.backgroundColor = .label
        line.translatesAutoresizingMaskIntoConstraints = false

        let topTick = UIView()
        topTick.backgroundColor = .label
        topTick.translatesAutoresizingMaskIntoConstraints = false

        let bottomTick = UIView()
        bottomTick.backgroundColor = .label
        bottomTick.translatesAutoresizingMaskIntoConstraints = false

        [line, topTick, bottomTick].forEach(container.addSubview)
        NSLayoutConstraint.activate([
            line.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.widthAnchor.constraint(equalToConstant: 4),
            topTick.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            topTick.topAnchor.constraint(equalTo: container.topAnchor),
            topTick.widthAnchor.constraint(equalToConstant: 28),
            topTick.heightAnchor.constraint(equalToConstant: 2),
            bottomTick.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bottomTick.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bottomTick.widthAnchor.constraint(equalToConstant: 28),
            bottomTick.heightAnchor.constraint(equalToConstant: 2)
        ])
        return container
    }()

    private lazy var lengthLabel: UILabel = {
        let label = UILabel()
        label.text = "Vertical ruler: 50 mm"
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var slider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 180
        slider.maximumValue = 360
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()

    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Save Calibration", for: .normal)
        button.drawStandardButton()
        button.addTarget(self, action: #selector(saveCalibration), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Screen Calibration"
        view.backgroundColor = .systemBackground
        isModalInPresentation = true

        [instructionLabel, calibrationRuler, lengthLabel, slider, saveButton].forEach(view.addSubview)
        let suggestedHeight = calibrationProvider.suggestedPointsPerMillimeter
            * calibrationLengthMillimeters
        let initialHeight = min(max(suggestedHeight, 180), 500)
        rulerHeightConstraint = calibrationRuler.heightAnchor.constraint(equalToConstant: initialHeight)
        slider.value = Float(initialHeight)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            instructionLabel.leadingAnchor.constraint(equalTo: calibrationRuler.trailingAnchor, constant: 24),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            calibrationRuler.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            calibrationRuler.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            calibrationRuler.widthAnchor.constraint(equalToConstant: 32),
            calibrationRuler.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            calibrationRuler.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            rulerHeightConstraint,
            lengthLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 24),
            lengthLabel.centerXAnchor.constraint(equalTo: instructionLabel.centerXAnchor),
            slider.topAnchor.constraint(equalTo: lengthLabel.bottomAnchor, constant: 30),
            slider.leadingAnchor.constraint(equalTo: instructionLabel.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: instructionLabel.trailingAnchor),
            saveButton.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 40),
            saveButton.leadingAnchor.constraint(equalTo: instructionLabel.leadingAnchor),
            saveButton.trailingAnchor.constraint(equalTo: instructionLabel.trailingAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let maximumHeight = max(180, view.safeAreaLayoutGuide.layoutFrame.height - 40)
        slider.maximumValue = Float(maximumHeight)
        if rulerHeightConstraint.constant > maximumHeight {
            rulerHeightConstraint.constant = maximumHeight
            slider.value = Float(maximumHeight)
        }
    }

    @objc private func sliderChanged() {
        rulerHeightConstraint.constant = CGFloat(slider.value)
    }

    @objc private func saveCalibration() {
        let pointsPerMillimeter = Double(rulerHeightConstraint.constant) / calibrationLengthMillimeters
        guard let calibration = calibrationProvider.saveManualCalibration(
            pointsPerMillimeter: pointsPerMillimeter
        ) else { return }
        dismiss(animated: true) { [completion] in
            completion?(calibration)
        }
    }
}
