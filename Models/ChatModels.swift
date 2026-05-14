//
//  ChatModels.swift
//  BMCC_Advisor
//
//  Created by Youness El Akri on 5/7/26.
//

import Foundation

struct UserProfile: Codable {
    var userId: String
    var firstName: String
    var lastName: String
    var major: String
    var scheduleType: String
    var startSemester: String
    var startYear: String
    var graduationYear: String
    
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
    
    // ADD THIS DEFAULT PROFILE
    static let defaultProfile = UserProfile(
        userId: UUID().uuidString,
        firstName: "",
        lastName: "",
        major: "",
        scheduleType: "Full-time",
        startSemester: "Fall",
        startYear: "",
        graduationYear: ""
    )
}

struct StoredMessage: Codable, Identifiable {
    let id: String
    let text: String
    let isUser: Bool
    let timestamp: Date
    
    init(id: String = UUID().uuidString, text: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

struct Conversation: Codable, Identifiable {
    let id: String
    var title: String
    var createdAt: Date
    var lastUpdated: Date
    var messages: [StoredMessage]
    
    init(id: String = UUID().uuidString, title: String, createdAt: Date = Date(), lastUpdated: Date = Date(), messages: [StoredMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.messages = messages
    }
}

struct ConversationSummary: Codable, Identifiable {
    let id: String
    let title: String
    let lastUpdated: Date
    let previewText: String
    let messageCount: Int
    
    init(conversation: Conversation) {
        self.id = conversation.id
        self.title = conversation.title
        self.lastUpdated = conversation.lastUpdated
        let firstUserMessage = conversation.messages.first(where: { $0.isUser })?.text ?? "New conversation"
        self.previewText = String(firstUserMessage.prefix(50))
        self.messageCount = conversation.messages.count
    }
}
