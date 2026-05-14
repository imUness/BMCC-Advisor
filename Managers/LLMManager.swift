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
        // Build the full prompt
        let fullPrompt = buildFullPrompt(
            userMessage: userMessage,
            profile: userProfile,
            history: conversationHistory
        )
        
        // Print to console for debugging
        print("\n========== PROMPT SENT TO LLM ==========")
        print(fullPrompt)
        print("========================================\n")
        
        // Send to API
        guard let url = URL(string: "https://mipilar.com/chat") else {
            DispatchQueue.main.async { self.onComplete?("Error: Invalid URL") }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "user_input": fullPrompt,
            "conversation_id": conversationId,
            "user_id": userProfile.userId
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.onComplete?("Error: \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data, let raw = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.onComplete?("Error: No response from server")
                }
                return
            }
            
            let cleanedResponse = Self.stripThink(from: raw)
            DispatchQueue.main.async {
                self.onComplete?(cleanedResponse)
            }
        }.resume()
    }
    
    private func buildFullPrompt(userMessage: String, profile: UserProfile, history: [StoredMessage]) -> String {
        let systemPrompt = buildSystemPrompt(from: profile)
        let historyText = formatConversationHistory(history)
        
        return """
        \(systemPrompt)
        
        CONVERSATION HISTORY:
        \(historyText)
        
        STUDENT QUESTION: \(userMessage)
        
        Please respond as BMCC Advisor based on the student's context above.
        """
    }
    
    private func buildSystemPrompt(from profile: UserProfile) -> String {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentSemester = currentMonth >= 8 ? "Fall \(currentYear)" : "Spring \(currentYear)"
        
        return """
        You are BMCC Advisor, an academic advisor for Borough of Manhattan Community College (CUNY).
        
        STUDENT PROFILE:
        - Name: \(profile.fullName)
        - User ID: \(profile.userId)
        - Major: \(profile.major)
        - Schedule: \(profile.scheduleType) (\(profile.scheduleType == "Full-time" ? "12-15 credits/semester" : "6-9 credits/semester"))
        - Started: \(profile.startSemester) \(profile.startYear)
        - Expected Graduation: \(profile.graduationYear)
        - Current Semester: \(currentSemester)
        
        IMPORTANT RULES:
        1. Always reference actual BMCC courses with their codes (e.g., CSC 111, MAT 301)
        2. Verify prerequisites before recommending any course
        3. Consider the student's schedule type when planning credit load
        4. Calculate remaining semesters based on graduation year
        5. Be helpful, accurate, and honest. If unsure, say "I recommend speaking with your academic advisor"
        6. Never invent courses or requirements not in the BMCC catalog
        7. Format responses clearly with bullet points when listing multiple items
        
        BMCC CORE REQUIREMENTS:
        - Required Core: English Composition (ENG 101, ENG 201), Math (choose one), Life Science (choose one)
        - Flexible Core: 18 credits (1 from each of 5 areas + 1 additional)
        
        Respond naturally as a helpful academic advisor.
        """
    }
    
    private func formatConversationHistory(_ history: [StoredMessage]) -> String {
        // Get last 10 messages for context
        let lastMessages = history.suffix(10)
        guard !lastMessages.isEmpty else { return "No previous messages." }
        
        return lastMessages.map { msg in
            let role = msg.isUser ? "Student" : "Advisor"
            return "\(role): \(msg.text)"
        }.joined(separator: "\n")
    }
    
    static func stripThink(from text: String) -> String {
        var result = text
        while let start = result.range(of: "<think>"),
              let end = result.range(of: "</think>", range: start.upperBound..<result.endIndex) {
            result.removeSubrange(start.lowerBound...end.upperBound)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
