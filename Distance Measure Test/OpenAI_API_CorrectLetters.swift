//import Foundation
//import AVFoundation
//
//func getCorrectLetter(transcription: String, completion: @escaping (String?) -> Void) {
//    let apiKey = "sk-proj-BeUPea8G5QnWIqpukCp1T3BlbkFJJ6U0ZpanciCSZCe6V22c"
//    let url = URL(string: "https://api.openai.com/v1/chat/completions")!
//
//    var request = URLRequest(url: url)
//    request.httpMethod = "POST"
//    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
//    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//    let prompt = "Transcribe the following spoken word to the nearest corresponding single letter when spoken aloud: \(transcription), and respond with only the letter"
//    let parameters: [String: Any] = [
//        "model": "gpt-3.5-turbo",
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
