//
//  ChatStorageManager.swift
//  BMCC_Advisor
//
//  Created by Youness El Akri on 5/7/26.
//

import Foundation
import Combine

class ChatStorageManager: ObservableObject {
    static let shared = ChatStorageManager()
    private let fileManager = FileManager.default
    
    @Published var allConversations: [ConversationSummary] = []
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var conversationsDirectory: URL {
        documentsDirectory.appendingPathComponent("conversations", isDirectory: true)
    }
    
    private var metadataFileURL: URL {
        documentsDirectory.appendingPathComponent("conversations_metadata.json")
    }
    
    private var userProfileFileURL: URL {
        documentsDirectory.appendingPathComponent("user_profile.json")
    }
    
    init() {
        createDirectoriesIfNeeded()
        loadAllConversationsMetadata()
    }
    
    // MARK: - Setup
    private func createDirectoriesIfNeeded() {
        if !fileManager.fileExists(atPath: conversationsDirectory.path) {
            try? fileManager.createDirectory(at: conversationsDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - User Profile
    func saveUserProfile(_ profile: UserProfile) {
        do {
            let data = try JSONEncoder().encode(profile)
            try data.write(to: userProfileFileURL)
        } catch {
            print("❌ Failed to save user profile: \(error)")
        }
    }
    
    func loadUserProfile() -> UserProfile? {
        guard fileManager.fileExists(atPath: userProfileFileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: userProfileFileURL)
            return try JSONDecoder().decode(UserProfile.self, from: data)
        } catch {
            print("❌ Failed to load user profile: \(error)")
            return nil
        }
    }
    
    // MARK: - Conversation Management
    func generateConversationId() -> String {
        return "conv_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8))"
    }
    
    func saveConversation(_ conversation: Conversation) {
        let fileURL = conversationsDirectory.appendingPathComponent("\(conversation.id).json")
        do {
            let data = try JSONEncoder().encode(conversation)
            try data.write(to: fileURL)
            saveConversationMetadata()
        } catch {
            print("❌ Failed to save conversation: \(error)")
        }
    }
    
    func loadConversation(id: String) -> Conversation? {
        let fileURL = conversationsDirectory.appendingPathComponent("\(id).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(Conversation.self, from: data)
        } catch {
            print("❌ Failed to load conversation \(id): \(error)")
            return nil
        }
    }
    
    func deleteConversation(id: String) {
        let fileURL = conversationsDirectory.appendingPathComponent("\(id).json")
        try? fileManager.removeItem(at: fileURL)
        saveConversationMetadata()
    }
    
    func createNewConversation(title: String = "New Chat") -> Conversation {
        let newConversation = Conversation(
            id: generateConversationId(),
            title: title
        )
        saveConversation(newConversation)
        return newConversation
    }
    
    // MARK: - Metadata Management
    private func saveConversationMetadata() {
        var summaries: [ConversationSummary] = []
        
        do {
            let files = try fileManager.contentsOfDirectory(at: conversationsDirectory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                let data = try Data(contentsOf: file)
                let conversation = try JSONDecoder().decode(Conversation.self, from: data)
                summaries.append(ConversationSummary(conversation: conversation))
            }
        } catch {
            print("❌ Failed to load conversations for metadata: \(error)")
        }
        
        // Sort by last updated (newest first)
        summaries.sort { $0.lastUpdated > $1.lastUpdated }
        
        do {
            let data = try JSONEncoder().encode(summaries)
            try data.write(to: metadataFileURL)
            DispatchQueue.main.async {
                self.allConversations = summaries
            }
        } catch {
            print("❌ Failed to save metadata: \(error)")
        }
    }
    
    private func loadAllConversationsMetadata() {
        guard fileManager.fileExists(atPath: metadataFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: metadataFileURL)
            let summaries = try JSONDecoder().decode([ConversationSummary].self, from: data)
            DispatchQueue.main.async {
                self.allConversations = summaries
            }
        } catch {
            print("❌ Failed to load metadata: \(error)")
        }
    }
    
    // MARK: - Helper
    func getConversationHistory(for id: String) -> [StoredMessage] {
        return loadConversation(id: id)?.messages ?? []
    }
}
