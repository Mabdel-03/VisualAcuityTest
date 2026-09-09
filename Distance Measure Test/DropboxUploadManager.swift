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
    // NOTE: This is a SHORT-LIVED token (starts with "sl.") that will expire.
    //       For production, generate a non-expiring token from Dropbox App Console.
    private let accessToken = "sl.u.AGJdU0SeRfV64rO_l4EPtgsq259s6DbB9ulPwERTb0GzfEuvLkkV00B9iOsRgP_pwLOHGxTm1dz1gsMysIP106z1TpsM00XI2IRzqp0WOr9sBTcJ_lML_UQR6zdQLflnk-_UH6PqqjkjeI8P-W9b0BRUS5NHl_wJizZgd-xClVw4WXLKc4elnOTFZ5E8qcydEo7Ih0rOtTI_3IURsb7XqVGV4e-9gg-QjgF0M3yx_iLyBZullPQ9rUJFl3MTKJ1MKfQyM6NM-K-CT06tvuviOdS72ygw6alMVNq9U_3FKCXvLK-WsQJzoeN_7O5_ZQP8Svqzo4gUg7BNgG7MkcP88KBVj3DaOdGbVF9GJnbTjQUDYRRUYEUgWsbH3n-DLttUaieCqmvkSaGW4QTvwgVv0plj6JavkwVf4pPWkrA23C_cEdXx0t1Ym3JgZZ93z7LcnhJnulIyo30qdjr7P-9cFtZ19HeK6eZDCVSRTqOTG2G1WYxGb5EZ7UQjCiJpyC8j8dRj8fbL42kvWSt55GFmqcWOYhLkrt8i5kXc_U8CuEBeMc9VPjRggEUOmNegoQ5hiQnh4VlI030nMs-JXomID9XBnbCbKSQgt4p9KYWeojoPEjLvqP0XLxXSIl09-Ta1pFNpEh7md10DUN-mdVz53aNMbYD1J6PI7UX8DlH2w91PnHixQngqgcFF7HuawlMjRmS3BpSWC_UiVunxxbNsb0KHAsKKLQpCN5E3Sh_mj61j-Qsg0H0Va3yASUhuJqPIQH8knZeKDuByxD-PlvcI0KpXOKMJrOYnzRYC9rb_SsH1MGfNcbOLMEWfhrmjrU4FNr9ZzWvAJL53i_CHdZOKVXoiYCYqN-zO8cURFTpj7ojjc7HqnoxSE1KHfz7w_4xeZKga2B-Zgv6B6dmm6BA7ZgcJ2Um15m806FQDQyzgwYMAtgHyQM8L1AVe6Pyh3R1rPiJdyoF8N9PX6iGFJQrcVywrV-jRq6p1__sG3JeW8FNY7VEJza3VGdKHWVnEQjKChdxLcXpliFcm2PC0w_AoCyjpw7j4ayAqP9PUeuw0RqsnvuRnxVsqUjsF4g1SDgEs5xH3FhVoC93eooIeki3-DbiQbZ-m2txm-w2nsiRnJHt59-8LrfoqLIR4ufpZs10KPtIhecVAbcv0Co48leNiGAoCPMf5Hu8erEnwWp0nIBCWFhhK0Z4IYksj1JqZne11_56LK_YvYCjHSnHg_EJeDf9szCuNtyEOjgP9TcVrljD_fx7Llk6SC0dsKURkq5r92Q0tMp1sV_bmcQNX3IE4vrD4eg9pG0urLsaLvRlPxZFltRWw1iyNYon9uslF6hKOs-s"
    
    // Target folder path in Dropbox
    // For "App folder" access: Use "" (empty string) or "/subfolder_name"
    // For "Full Dropbox" access: Use "/Mahmoud Abdelmoneum/OHSU/Clinical_Trials/Landolt_C_Only_Trials"
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

