//
//  TestProgressionDataCollector.swift
//  Distance Measure Test
//
//  Created by Visual Acuity Test Assistant
//

import Foundation

/// Data structure representing a single test response
public struct TestResponseData {
    let timestamp: Date
    let eye: String // "Left" or "Right"
    let testType: String // "ETDRS" or "Landolt_C"
    let acuityLevel: String // "20/200", "20/100", etc.
    let letterDisplayed: String // The letter or orientation shown
    let distanceCM: Double
    let responseTimeMS: Int64
    let userResponse: String
    let isCorrect: Bool
    let trialNumber: Int
    let sessionId: String
}

/// Manages collection and storage of detailed test progression data
public class TestProgressionDataCollector {
    public static let shared = TestProgressionDataCollector()
    
    private var currentSessionData: [TestResponseData] = []
    private var currentSessionId: String = ""
    private var sessionStartTime: Date?
    
    private init() {}
    
    // MARK: - Session Management
    
    /// Starts a new test session
    public func startNewSession(eye: String, testType: String) {
        currentSessionId = generateSessionId(eye: eye, testType: testType)
        currentSessionData.removeAll()
        sessionStartTime = Date()
        
        print("📊 Started new test session: \(currentSessionId)")
    }
    
    /// Ends the current session and saves data
    public func endCurrentSession() {
        guard !currentSessionData.isEmpty else {
            print("📊 No data to save for session")
            return
        }
        
        saveSessionData()
        
        print("📊 Ended session \(currentSessionId) with \(currentSessionData.count) responses")
        
        // Clear current session
        currentSessionData.removeAll()
        currentSessionId = ""
        sessionStartTime = nil
    }
    
    // MARK: - Data Collection
    
    /// Records a test response
    public func recordResponse(
        eye: String,
        testType: String,
        acuityLevel: String,
        letterDisplayed: String,
        distanceCM: Double,
        responseTimeMS: Int64,
        userResponse: String,
        isCorrect: Bool,
        trialNumber: Int
    ) {
        let responseData = TestResponseData(
            timestamp: Date(),
            eye: eye,
            testType: testType,
            acuityLevel: acuityLevel,
            letterDisplayed: letterDisplayed,
            distanceCM: distanceCM,
            responseTimeMS: responseTimeMS,
            userResponse: userResponse,
            isCorrect: isCorrect,
            trialNumber: trialNumber,
            sessionId: currentSessionId
        )
        
        currentSessionData.append(responseData)
        
        print("📊 Recorded response: \(letterDisplayed) → \(userResponse) (\(isCorrect ? "✓" : "✗")) at \(String(format: "%.1f", distanceCM))cm in \(responseTimeMS)ms")
    }
    
    // MARK: - Data Persistence
    
    private func saveSessionData() {
        guard !currentSessionData.isEmpty else { return }
        
        // Get or create the stored data
        var allStoredData = getAllStoredProgressionData()
        
        // Add current session data
        allStoredData.append(contentsOf: currentSessionData)
        
        // Save back to UserDefaults
        if let encodedData = try? JSONEncoder().encode(allStoredData) {
            UserDefaults.standard.set(encodedData, forKey: "TestProgressionData")
            print("📊 Saved \(currentSessionData.count) responses to persistent storage")
        } else {
            print("📊 ❌ Failed to encode progression data")
        }
    }
    
    /// Retrieves all stored test progression data
    public func getAllStoredProgressionData() -> [TestResponseData] {
        guard let data = UserDefaults.standard.data(forKey: "TestProgressionData"),
              let decodedData = try? JSONDecoder().decode([TestResponseData].self, from: data) else {
            return []
        }
        return decodedData
    }
    
    /// Clears all stored progression data
    public func clearAllProgressionData() {
        UserDefaults.standard.removeObject(forKey: "TestProgressionData")
        currentSessionData.removeAll()
        print("📊 Cleared all progression data")
    }
    
    // MARK: - CSV Export
    
    /// Generates CSV content for a specific eye
    public func generateCSV(for eye: String) -> String {
        let allData = getAllStoredProgressionData()
        let eyeData = allData.filter { $0.eye == eye }
        
        guard !eyeData.isEmpty else {
            return "No data available for \(eye) eye"
        }
        
        // CSV Header
        var csv = "Timestamp,Eye,Test_Type,Acuity_Level,Letter_Displayed,Distance_CM,Response_Time_MS,User_Response,Is_Correct,Trial_Number,Session_ID\n"
        
        // Sort by timestamp
        let sortedData = eyeData.sorted { $0.timestamp < $1.timestamp }
        
        // CSV Rows
        for response in sortedData {
            let row = [
                formatTimestamp(response.timestamp),
                response.eye,
                response.testType,
                response.acuityLevel,
                response.letterDisplayed,
                String(format: "%.1f", response.distanceCM),
                String(response.responseTimeMS),
                response.userResponse,
                response.isCorrect ? "TRUE" : "FALSE",
                String(response.trialNumber),
                response.sessionId
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    /// Generates CSV content for both eyes
    public func generateCombinedCSV() -> String {
        let allData = getAllStoredProgressionData()
        
        guard !allData.isEmpty else {
            return "No test data available"
        }
        
        // CSV Header
        var csv = "Timestamp,Eye,Test_Type,Acuity_Level,Letter_Displayed,Distance_CM,Response_Time_MS,User_Response,Is_Correct,Trial_Number,Session_ID\n"
        
        // Sort by timestamp
        let sortedData = allData.sorted { $0.timestamp < $1.timestamp }
        
        // CSV Rows
        for response in sortedData {
            let row = [
                formatTimestamp(response.timestamp),
                response.eye,
                response.testType,
                response.acuityLevel,
                response.letterDisplayed,
                String(format: "%.1f", response.distanceCM),
                String(response.responseTimeMS),
                response.userResponse,
                response.isCorrect ? "TRUE" : "FALSE",
                String(response.trialNumber),
                response.sessionId
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    // MARK: - Statistics
    
    /// Gets basic statistics about stored data
    func getDataStatistics() -> [String: Any] {
        let allData = getAllStoredProgressionData()
        let leftEyeData = allData.filter { $0.eye == "Left" }
        let rightEyeData = allData.filter { $0.eye == "Right" }
        
        let uniqueSessions = Set(allData.map { $0.sessionId }).count
        
        return [
            "total_responses": allData.count,
            "left_eye_responses": leftEyeData.count,
            "right_eye_responses": rightEyeData.count,
            "unique_sessions": uniqueSessions,
            "date_range": getDateRange(from: allData)
        ]
    }
    
    // MARK: - Helper Methods
    
    private func generateSessionId(eye: String, testType: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        return "\(testType)_\(eye)_\(timestamp)"
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func getDateRange(from data: [TestResponseData]) -> String {
        guard !data.isEmpty else { return "No data" }
        
        let timestamps = data.map { $0.timestamp }
        let earliest = timestamps.min()!
        let latest = timestamps.max()!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if Calendar.current.isDate(earliest, inSameDayAs: latest) {
            return formatter.string(from: earliest)
        } else {
            return "\(formatter.string(from: earliest)) to \(formatter.string(from: latest))"
        }
    }
}

// MARK: - Codable Conformance

extension TestResponseData: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, eye, testType, acuityLevel, letterDisplayed
        case distanceCM, responseTimeMS, userResponse, isCorrect
        case trialNumber, sessionId
    }
}
