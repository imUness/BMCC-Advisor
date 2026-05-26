//
//  LLMManager 2.swift
//  BMCC_Advisor
//
//  Created by Youness El Akri on 5/12/26.
//


//
//  LLMManager.swift
//  BMCC_Advisor
//
//  Created by Youness El Akri on 5/7/26.
//

import Foundation
import Combine

class LLMManager: NSObject, ObservableObject {
    var onComplete: ((String) -> Void)?
    
    func send(
        userMessage: String,
        userProfile: UserProfile,
        conversationHistory: [StoredMessage],
        conversationId: String
    ) {
        // Build conversation history for context
        let historyText = formatConversationHistory(conversationHistory)
        
        // Build the complete request body
        let body: [String: Any] = [
            "user_input": userMessage,
            "student_id": userProfile.userId,
            "name": userProfile.fullName,
            "major": userProfile.major,
            "schedule_type": userProfile.scheduleType,
            "start_semester": userProfile.startSemester,
            "start_year": userProfile.startYear,
            "expected_grad_semester": userProfile.gradSemester,
            "expected_grad_year": userProfile.graduationYear,
            "completed_courses": userProfile.completedCourses,
            "conversation_history": historyText,
            "conversation_id": conversationId
        ]
        
        // Print request for debugging
        print("\n========== SENDING REQUEST TO LLM ==========")
        print("User: \(userProfile.fullName)")
        print("Major: \(userProfile.major)")
        print("Message: \(userMessage)")
        print("Completed Courses: \(userProfile.completedCourses)")
        print("===========================================\n")
        
        guard let url = URL(string: "https://mipilar.com/chat") else {
            DispatchQueue.main.async {
                self.onComplete?("❌ Error: Invalid URL. Please check your connection.")
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 90 // Longer timeout for complex responses
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        } catch {
            DispatchQueue.main.async {
                self.onComplete?("❌ Error: Failed to encode request. Please try again.")
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle network error
            if let error = error {
                DispatchQueue.main.async {
                    self.onComplete?("🌐 Network Error: \(error.localizedDescription)\n\nPlease check your internet connection and try again.")
                }
                return
            }
            
            // Check for HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.onComplete?("❌ Error: Invalid server response. Please try again.")
                }
                return
            }
            
            // Handle status codes
            switch httpResponse.statusCode {
            case 200:
                // Success - parse response
                guard let data = data else {
                    DispatchQueue.main.async {
                        self.onComplete?("❌ Error: No data received from server.")
                    }
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Try to get response field
                        if let responseText = json["response"] as? String {
                            let cleaned = Self.cleanResponse(responseText)
                            DispatchQueue.main.async {
                                self.onComplete?(cleaned)
                            }
                            return
                        }
                        // Try to get error field
                        if let errorText = json["error"] as? String {
                            DispatchQueue.main.async {
                                self.onComplete?("⚠️ Server Error: \(errorText)")
                            }
                            return
                        }
                    }
                    // Fallback: return raw data as string
                    let rawResponse = String(data: data, encoding: .utf8) ?? "No response content"
                    DispatchQueue.main.async {
                        self.onComplete?(Self.cleanResponse(rawResponse))
                    }
                } catch {
                    print("❌ JSON Parse Error: \(error)")
                    let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to parse response"
                    DispatchQueue.main.async {
                        self.onComplete?(Self.cleanResponse(rawResponse))
                    }
                }
                
            case 404:
                DispatchQueue.main.async {
                    self.onComplete?("📚 Course Catalog Error: The requested major information wasn't found. Please contact your academic advisor.")
                }
                
            case 429:
                DispatchQueue.main.async {
                    self.onComplete?("⏳ Rate Limited: Too many requests. Please wait a moment and try again.")
                }
                
            case 500:
                DispatchQueue.main.async {
                    self.onComplete?("🔧 Server Error: Our advisor service is temporarily unavailable. Please try again in a few minutes.")
                }
                
            default:
                DispatchQueue.main.async {
                    self.onComplete?("⚠️ Unexpected Error (Status \(httpResponse.statusCode)). Please try again.")
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Functions
    
    private func formatConversationHistory(_ history: [StoredMessage]) -> String {
        let lastMessages = history.suffix(10)
        guard !lastMessages.isEmpty else { return "No previous messages." }
        
        return lastMessages.map { msg in
            let role = msg.isUser ? "Student" : "Advisor"
            return "\(role): \(msg.text)"
        }.joined(separator: "\n")
    }
    
    static func cleanResponse(_ text: String) -> String {
        var result = text
        
        // Remove  tags
        while let start = result.range(of: "<think>"),
              let end = result.range(of: "</think>", range: start.upperBound..<result.endIndex) {
            result.removeSubrange(start.lowerBound...end.upperBound)
        }
        
        // Remove any other markdown code block indicators that might break display
        if result.hasPrefix("```markdown") {
            result = String(result.dropFirst(11))
        }
        if result.hasPrefix("```") {
            result = String(result.dropFirst(3))
        }
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }
        
        // Ensure proper spacing after headers
        result = result.replacingOccurrences(of: "##", with: "\n##")
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func stripThink(from text: String) -> String {
        return cleanResponse(text)
    }
}