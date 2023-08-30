/*
 See LICENSE folder for this sample’s licensing information.
 */

import Foundation

struct History: Identifiable, Codable {
    var transcript: String?
    
    init(transcript: String? = nil) {
        self.transcript = transcript
    }
}
