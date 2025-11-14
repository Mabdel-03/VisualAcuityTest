//
//  UIViewController+NamePrompt.swift
//  Distance Measure Test
//
//  Created for CSV Export Enhancement
//

import UIKit

extension UIViewController {
    
    /// Prompts the user to enter their first and last name
    /// - Parameters:
    ///   - allowSkip: Whether to show a "Use Previous" option if a name is already stored
    ///   - completion: Callback with success status - true if name was entered/confirmed, false if cancelled
    func promptForSubjectName(allowSkip: Bool = true, completion: @escaping (Bool) -> Void) {
        let nameManager = SubjectNameManager.shared
        
        // Check if there's already a stored name
        if allowSkip, let (firstName, lastName) = nameManager.getSubjectName() {
            // Show option to use previous name or enter new one
            let confirmAlert = UIAlertController(
                title: "Subject Name",
                message: "Use the previously entered name '\(firstName) \(lastName)' or enter a new name?",
                preferredStyle: .alert
            )
            
            confirmAlert.addAction(UIAlertAction(title: "Use Previous", style: .default) { _ in
                completion(true)
            })
            
            confirmAlert.addAction(UIAlertAction(title: "Enter New Name", style: .default) { _ in
                self.showNameEntryAlert(completion: completion)
            })
            
            confirmAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completion(false)
            })
            
            present(confirmAlert, animated: true)
        } else {
            // No stored name, show entry dialog
            showNameEntryAlert(completion: completion)
        }
    }
    
    /// Shows the alert dialog for entering first and last name
    private func showNameEntryAlert(completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Enter Subject Information",
            message: "Please enter the subject's first and last name for the CSV export.",
            preferredStyle: .alert
        )
        
        // Add text fields
        alert.addTextField { textField in
            textField.placeholder = "First Name"
            textField.autocapitalizationType = .words
            textField.autocorrectionType = .no
            textField.returnKeyType = .next
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Last Name"
            textField.autocapitalizationType = .words
            textField.autocorrectionType = .no
            textField.returnKeyType = .done
        }
        
        // Add Save action
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak alert] _ in
            guard let firstNameField = alert?.textFields?[0],
                  let lastNameField = alert?.textFields?[1],
                  let firstName = firstNameField.text,
                  let lastName = lastNameField.text else {
                completion(false)
                return
            }
            
            let nameManager = SubjectNameManager.shared
            
            // Validate names
            if !nameManager.validateName(firstName) {
                self.showValidationError(message: "First name must contain at least one letter.") {
                    self.showNameEntryAlert(completion: completion)
                }
                return
            }
            
            if !nameManager.validateName(lastName) {
                self.showValidationError(message: "Last name must contain at least one letter.") {
                    self.showNameEntryAlert(completion: completion)
                }
                return
            }
            
            // Save the names
            nameManager.saveSubjectName(firstName: firstName, lastName: lastName)
            completion(true)
        }
        
        // Add Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        }
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    /// Shows a validation error message
    private func showValidationError(message: String, retry: @escaping () -> Void) {
        let errorAlert = UIAlertController(
            title: "Invalid Input",
            message: message,
            preferredStyle: .alert
        )
        
        errorAlert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
            retry()
        })
        
        errorAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(errorAlert, animated: true)
    }
}






