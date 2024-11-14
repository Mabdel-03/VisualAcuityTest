//import Foundation
//import AVFoundation
//
//func getCorrectLetter(transcription: String, completion: @escaping (String?) -> Void) {
//    let apiKey = "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"
//    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
//
//    var request = URLRequest(url: url)
//    request.httpMethod = "POST"
//    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
//    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//    let prompt = "Transcribe the following spoken word to the nearest corresponding single letter when spoken aloud: \(transcription), and respond with only the letter. Some example conversions include 'aye' to 'A', 'see' to 'C', 'oh' to 'O', 'yes' to 'S', 'ok' to 'K', 'and' to 'N', 'Z' to 'Z', 'are' to 'R'. This is for an ETDRS visual acuity test, so limit conversions to only ETDRS letters."
//    let parameters: [String: Any] = [
//        "model": "gpt-4o",
//        "messages": [["role": "user", "content": prompt]],
//        "max_tokens": 1,
//        "temperature": 0
//    ]
//
//    do {
//        request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
//    } catch {
//        print("Failed to serialize request body: \(error)")
//        completion(nil)
//        return
//    }
//
//    let task = URLSession.shared.dataTask(with: request) { data, response, error in
//        if let error = error {
//            print("Network error: \(error)")
//            completion(nil)
//            return
//        }
//
//        guard let data = data else {
//            print("No data received")
//            completion(nil)
//            return
//        }
//
//        do {
//            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
//                print("API Response: \(jsonResponse)")
//                if let choices = jsonResponse["choices"] as? [[String: Any]],
//                   let message = choices.first?["message"] as? [String: Any],
//                   let text = message["content"] as? String {
//                    let correctedLetter = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
//                    if correctedLetter.count == 1 && correctedLetter.rangeOfCharacter(from: CharacterSet.letters) != nil {
//                        completion(correctedLetter)
//                    } else {
//                        completion(nil)
//                    }
//                } else {
//                    completion(nil)
//                }
//            } else {
//                print("Failed to parse JSON response")
//                completion(nil)
//            }
//        } catch {
//            print("JSON parsing error: \(error)")
//            completion(nil)
//        }
//    }
//
//    task.resume()
//}
