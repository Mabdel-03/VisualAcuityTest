//
//  SubjectNameManager.swift
//  Distance Measure Test
//
//  Created for CSV Export Enhancement
//

import Foundation

/// Manages subject name storage and formatting for CSV exports
class SubjectNameManager {
    static let shared = SubjectNameManager()
    
    private let firstNameKey = "SubjectFirstName"
    private let lastNameKey = "SubjectLastName"
    
    private init() {}
    
    // MARK: - Name Storage
    
    /// Saves subject's first and last name
    func saveSubjectName(firstName: String, lastName: String) {
        let cleanedFirst = cleanNameForStorage(firstName)
        let cleanedLast = cleanNameForStorage(lastName)
        
        UserDefaults.standard.set(cleanedFirst, forKey: firstNameKey)
        UserDefaults.standard.set(cleanedLast, forKey: lastNameKey)
        
        print("📝 Saved subject name: \(cleanedFirst) \(cleanedLast)")
    }
    
    /// Retrieves stored subject name
    func getSubjectName() -> (firstName: String, lastName: String)? {
        guard let firstName = UserDefaults.standard.string(forKey: firstNameKey),
              let lastName = UserDefaults.standard.string(forKey: lastNameKey),
              !firstName.isEmpty,
              !lastName.isEmpty else {
            return nil
        }
        
        return (firstName, lastName)
    }
    
    /// Clears stored subject name
    func clearSubjectName() {
        UserDefaults.standard.removeObject(forKey: firstNameKey)
        UserDefaults.standard.removeObject(forKey: lastNameKey)
        print("📝 Cleared subject name")
    }
    
    /// Checks if a subject name is currently stored
    func hasStoredName() -> Bool {
        return getSubjectName() != nil
    }
    
    // MARK: - Name Formatting
    
    /// Generates a filename-safe formatted name
    func getFormattedNameForFilename() -> String? {
        guard let (firstName, lastName) = getSubjectName() else {
            return nil
        }
        
        return "\(firstName)_\(lastName)"
    }
    
    /// Cleans a name string for storage and filename use
    private func cleanNameForStorage(_ name: String) -> String {
        // Remove leading/trailing whitespace
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove characters that are invalid in filenames
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        cleaned = cleaned.components(separatedBy: invalidCharacters).joined()
        
        // Replace spaces with underscores for filenames
        cleaned = cleaned.replacingOccurrences(of: " ", with: "_")
        
        // Keep only alphanumeric characters and underscores
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        cleaned = cleaned.unicodeScalars.filter { allowedCharacters.contains($0) }.map { String($0) }.joined()
        
        return cleaned
    }
    
    /// Validates that a name contains only acceptable characters
    func validateName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must not be empty
        guard !trimmed.isEmpty else {
            return false
        }
        
        // Must contain at least one letter
        let hasLetter = trimmed.rangeOfCharacter(from: .letters) != nil
        
        return hasLetter
    }
    
    // MARK: - Filename Generation
    
    /// Generates a timestamped filename with subject name
    /// - Parameters:
    ///   - suffix: Optional suffix to add before .csv (e.g., "left_eye", "right_eye", "combined")
    /// - Returns: Formatted filename or nil if no subject name is stored
    func generateCSVFilename(withSuffix suffix: String? = nil) -> String? {
        guard let formattedName = getFormattedNameForFilename() else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        if let suffix = suffix {
            return "\(timestamp)_\(formattedName)_\(suffix).csv"
        } else {
            return "\(timestamp)_\(formattedName).csv"
        }
    }
}









