//
//  DropboxUploadManager.swift
//  Distance Measure Test
//
//  Created for Dropbox Integration
//

import Foundation

/// Manages file uploads to Dropbox using the Dropbox HTTP API
class DropboxUploadManager {
    static let shared = DropboxUploadManager()
    
    // Dropbox access token - keep this secure
    private let accessToken = "sl.u.AGH5oEiqDGsZ0J0mDcKzIByiL8RM6-DZ9ELGoa7pky7UaD56qGxTofP6gsDWc7ijs6a_4mnPrwGcIXDcc2EyzaOTxEN9FLaJ5WpRjIh6eiVRFfYiFU2j2CHfDwlzeyewFXjWvumoqX-aT7EGcbuAZZK7aeHkQidau86yq6uto2IgMwc9amokbZN9hKRBJwWaP5WEjAhr9HDiT1ILaJa4dhBMUW242UEOc65PM1-cpeGYRP3UZgO99OSOc0cFtRdylvblUaqmY8cejM2Mi4Onj9NKGk8HWHcF4NYZF1Q86f5lFFOzGqtl437umc_k7qMDUnG-CgisWezE_JJ3h_tDqRC4pu7JHcvtWbaazaLztjvTNz-mNELS5ObNsxE9hd_1opEB6SLjaXu4-pl0PeM_xuXCFcmqHlV_WB1fWX3JxvzWg4ZvAaPcvGQFaSlNjzknU82ZPtLeAk16oVO1Vo4BBMnHnFIioKC1KV3E-cBwgO40NoF-8-JuUADknaenZ9qb3rfj8R1_kYFfffqG45Ko-mklod6kSyEqhyfISwbTOwP8lvgEIFjb9uH_fioWj64JpU9UkyhyCDQ0Hj6CVbI2HFlyH_xrAYJd_jv-9fdCJYmJnkH7niRk5JGR_WLKJZ4oGe_pg1mT1d41A0U0ag0v7Pb8RMaLoJZ9wcCRaWGlTLhNYXerjIIvvKYDTIi5l2BaJQ9QBJfLu7CnFQd06k1Dyx61r2MPTtBB4QtVh58FvI-NjwUF2DNA-YVyZuXrdzNxaiSV0jGcA1i3QPI-yI7tOVRHP_oG9el4DBLUVjqGvkM_ZI7j6W2KBMMZOQhvAirlhn-5cKjJJrOuZQYRlIMWbBSCcKUYXGlp06fww0XpQWKlqmxoer-R41koj_az_3CZ5y5lXbdyPylCJi1HSXZtCrsPHGqXfpmVOC0qK8TiOCEMzQY1mKaCk1_qU9fVv7TmKaYtucYtkoch-jR9AEW9-45X3wibKEjlkYYqRxQY_mk4MAyw9cy2riPwjpojzuAkiHd8pt6Mr30iPiZNjfwLsjbMb0114LQFShG7lerdAMR4X3ZjM5sXRYr5EuKW_jn0SmN9vJr7tm5jyXibZJ6VTNy95VG9CvWPbt9iO1JxKZrw5axzXKbTSX-Oqk1rcWwlsTj9wD8N2DivzrJGbTAm9lWkDGymHIDX1QI7Y3Od386FLw-CVzN-OFX18vHAyucU9h7A6I1BadhBfvuxoggL5P67YWxPYgMD7WtKZPbz__cRyaYzrun9E6YuXBmeTUErWQfLmScFVaTMXICBARyAM3Pyt_BOKliUwl7X_ZXebVYT3xVGG5eB4V-UwySAIW8Qi5M"
    
    // Target folder path in Dropbox
    private let targetFolderPath = "/Mahmoud Abdelmoneum/OHSU/Clinical_Trials/Landolt_C_Only_Trials"
    
    // Dropbox API endpoint for file upload
    private let uploadEndpoint = "https://content.dropboxapi.com/2/files/upload"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Uploads a file to Dropbox
    /// - Parameters:
    ///   - data: The file data to upload
    ///   - fileName: The name of the file (e.g., "20240115-143022_John_Doe.csv")
    ///   - completion: Completion handler with success status and optional error message
    func uploadFile(data: Data, fileName: String, completion: @escaping (Bool, String?) -> Void) {
        // Construct the full path
        let fullPath = "\(targetFolderPath)/\(fileName)"
        
        print("📦 Starting Dropbox upload: \(fileName)")
        print("📦 Target path: \(fullPath)")
        
        // Create the request
        guard let url = URL(string: uploadEndpoint) else {
            completion(false, "Invalid Dropbox URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set headers
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        // Create the Dropbox-API-Arg header with upload parameters
        let dropboxAPIArg: [String: Any] = [
            "path": fullPath,
            "mode": "add",  // or "overwrite" if you want to replace existing files
            "autorename": true,  // Automatically rename if file exists
            "mute": false
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: dropboxAPIArg),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            request.setValue(jsonString, forHTTPHeaderField: "Dropbox-API-Arg")
        } else {
            completion(false, "Failed to create Dropbox API arguments")
            return
        }
        
        request.httpBody = data
        
        // Create the upload task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Ensure completion runs on main thread for UI updates
            DispatchQueue.main.async {
                // Check for network errors
                if let error = error {
                    print("📦 Dropbox upload failed with error: \(error.localizedDescription)")
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                // Check HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("📦 Dropbox upload failed: Invalid response")
                    completion(false, "Invalid server response")
                    return
                }
                
                print("📦 Dropbox response status code: \(httpResponse.statusCode)")
                
                // Check status code
                if httpResponse.statusCode == 200 {
                    // Success!
                    if let data = data,
                       let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📦 Dropbox upload successful!")
                        print("📦 Response: \(jsonResponse)")
                    }
                    completion(true, nil)
                } else {
                    // Parse error message from response
                    var errorMessage = "Upload failed with status code \(httpResponse.statusCode)"
                    
                    if let data = data,
                       let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorResponse["error_summary"] as? String {
                        errorMessage = error
                        print("📦 Dropbox error: \(error)")
                    } else if let data = data,
                              let responseString = String(data: data, encoding: .utf8) {
                        print("📦 Dropbox response: \(responseString)")
                    }
                    
                    completion(false, errorMessage)
                }
            }
        }
        
        task.resume()
    }
    
    /// Convenience method to upload CSV content as string
    /// - Parameters:
    ///   - csvContent: The CSV content as a string
    ///   - fileName: The name of the file
    ///   - completion: Completion handler with success status and optional error message
    func uploadCSV(csvContent: String, fileName: String, completion: @escaping (Bool, String?) -> Void) {
        guard let data = csvContent.data(using: .utf8) else {
            completion(false, "Failed to convert CSV content to data")
            return
        }
        
        uploadFile(data: data, fileName: fileName, completion: completion)
    }
}

