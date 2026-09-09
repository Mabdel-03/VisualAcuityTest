// DistanceGuidanceController.swift
// Shared helper to unify distance UI behavior across tests

import UIKit

final class DistanceGuidanceController {
    private weak var warningLabel: UILabel?
    private weak var checkmarkLabel: UILabel?
    private weak var moveCloserLabel: UILabel?
    private weak var moveFartherLabel: UILabel?

    init(warningLabel: UILabel, checkmarkLabel: UILabel, moveCloserLabel: UILabel, moveFartherLabel: UILabel) {
        self.warningLabel = warningLabel
        self.checkmarkLabel = checkmarkLabel
        self.moveCloserLabel = moveCloserLabel
        self.moveFartherLabel = moveFartherLabel
    }

    func showWarning() {
        warningLabel?.isHidden = false
        checkmarkLabel?.isHidden = true
        moveCloserLabel?.isHidden = true
        moveFartherLabel?.isHidden = true
    }

    func showOK() {
        checkmarkLabel?.isHidden = false
        warningLabel?.isHidden = true
        moveCloserLabel?.isHidden = true
        moveFartherLabel?.isHidden = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkmarkLabel?.isHidden = true
        }
    }

    func showMoveCloser() {
        showWarning()
        moveCloserLabel?.isHidden = false
        moveFartherLabel?.isHidden = true
    }

    func showMoveFarther() {
        showWarning()
        moveCloserLabel?.isHidden = true
        moveFartherLabel?.isHidden = false
    }

    func hideAll() {
        warningLabel?.isHidden = true
        checkmarkLabel?.isHidden = true
        moveCloserLabel?.isHidden = true
        moveFartherLabel?.isHidden = true
    }
}
