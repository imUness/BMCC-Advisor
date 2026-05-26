//
//  LLMManager.swift
//  BMCC_Advisor
//

import Foundation
import Combine   // <-- add this line

class LLMManager: NSObject, ObservableObject, URLSessionDataDelegate {

    var onToken:    ((String) -> Void)?
    var onComplete: ((String) -> Void)?

    @Published var isThinking = false

    private let baseURL = "" // Your AI API 

    // Keep session alive as instance property — NOT local var
    // (local var gets deallocated and delegate never fires)
    private var session: URLSession!
    private var activeTask: URLSessionDataTask?
    private var accumulated = Data()

    override init() {
        super.init()
        // Session lives as long as LLMManager lives
        session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: nil          // background queue, safe
        )
    }

    // ─── Send ────────────────────────────────────────────────────────────────

    func send(
        userMessage: String,
        userProfile: UserProfile,
        conversationHistory: [StoredMessage],
        conversationId: String
    ) {
        stop()                          // cancel previous if any
        accumulated   = Data()
        isThinking    = true

        // ── Read every field your Settings screen saves ──────────────────────
        // Print ALL fields so we can see what's empty
        print("\n========== SENDING REQUEST ==========")
        print("Message   : \(userMessage)")
        print("Major     : \(userProfile.major)")
        print("Name      : \(userProfile.fullName)")
        print("Schedule  : \(userProfile.scheduleType)")
        print("StartSem  : \(userProfile.startSemester)")
        print("StartYear : \(userProfile.startYear)")
        print("GradSem   : \(userProfile.gradSemester)")
        print("GradYear  : \(userProfile.graduationYear)")
        print("Completed : \(userProfile.completedCourses)")
        print("=====================================\n")

        let body: [String: Any] = [
            "user_input":             userMessage,
            "student_id":             conversationId,
            "name":                   userProfile.fullName,
            "major":                  userProfile.major,
            "schedule_type":          userProfile.scheduleType,
            "start_semester":         userProfile.startSemester,
            "start_year":             userProfile.startYear,
            "expected_grad_semester": userProfile.gradSemester,
            "expected_grad_year":     userProfile.graduationYear,
            "completed_courses":      userProfile.completedCourses
        ]

        guard
            let url      = URL(string: "\(baseURL)/chat"),
            let bodyData = try? JSONSerialization.data(withJSONObject: body)
        else {
            finish(fallback("Bad URL or encoding"))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod        = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody          = bodyData
        req.timeoutInterval   = 90

        activeTask = session.dataTask(with: req)
        activeTask?.resume()
    }

    // ─── Stop ────────────────────────────────────────────────────────────────

    func stop() {
        activeTask?.cancel()
        activeTask = nil
        DispatchQueue.main.async { self.isThinking = false }
    }

    // ─── URLSessionDataDelegate ──────────────────────────────────────────────

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {

        accumulated.append(data)

        // Forward raw text chunk to UI (typing effect)
        if let text = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async { self.onToken?(text) }
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {

        // Cancelled = user tapped stop, ignore
        if let e = error as NSError?, e.code == NSURLErrorCancelled {
            DispatchQueue.main.async { self.isThinking = false }
            return
        }

        let raw = String(data: accumulated, encoding: .utf8) ?? ""

        print("\n━━━━ RAW FROM SERVER ━━━━")
        print(raw.prefix(500))
        print("━━━━━━━━━━━━━━━━━━━━━━━━━\n")

        // Extract valid JSON from the streamed tokens
        let result = extractJSON(from: raw) ?? fallback(
            error != nil
                ? "Connection error: \(error!.localizedDescription)"
                : "Server returned no JSON."
        )

        finish(result)
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private func finish(_ json: String) {
        DispatchQueue.main.async {
            self.isThinking = false
            self.onComplete?(json)
        }
    }

    /// Find outermost { } in raw text and validate it parses as AdvisorResponse
    func extractJSON(from raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip ```json fences if model added them
        if text.hasPrefix("```") {
            text = text
                .components(separatedBy: "\n")
                .filter { !$0.hasPrefix("```") }
                .joined(separator: "\n")
        }

        guard let startIdx = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var endIdx: String.Index?

        for i in text[startIdx...].indices {
            switch text[i] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { endIdx = i }
            default: break
            }
            if depth == 0 && endIdx != nil { break }
        }

        guard let end = endIdx else { return nil }

        let candidate = String(text[startIdx...end])

        // Must decode as AdvisorResponse to be considered valid
        guard
            let data = candidate.data(using: .utf8),
            (try? JSONDecoder().decode(AdvisorResponse.self, from: data)) != nil
        else { return nil }

        return candidate
    }

    func fallback(_ message: String) -> String {
        let obj: [String: Any] = ["message": message, "plan": NSNull()]
        let data = try! JSONSerialization.data(withJSONObject: obj)
        return String(data: data, encoding: .utf8)!
    }
}
