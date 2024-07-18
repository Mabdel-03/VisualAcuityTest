import Foundation
import AVFoundation

func getCorrectLetter(transcription: String, completion: @escaping (String?) -> Void) {
    let apiKey = "sk-proj-BeUPea8G5QnWIqpukCp1T3BlbkFJJ6U0ZpanciCSZCe6V22c"
    let url = URL(string: "https://api.openai.com/v1/completions")!
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let prompt = "Correct the following transcription mistake to a single alphanumeric letter: \(transcription)"
    let parameters: [String: Any] = [
        "model": "text-davinci-003",
        "prompt": prompt,
        "max_tokens": 1,
        "n": 1,
        "stop": ["\n"]
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            print("Network error: \(String(describing: error))")
            completion(nil)
            return
        }
        
        if let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let choices = jsonResponse["choices"] as? [[String: Any]],
           let text = choices.first?["text"] as? String {
            completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            completion(nil)
        }
    }
    
    task.resume()
}
