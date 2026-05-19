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
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
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
    
    private func createDirectoriesIfNeeded() {
        if !fileManager.fileExists(atPath: conversationsDirectory.path) {
            do {
                try fileManager.createDirectory(at: conversationsDirectory, withIntermediateDirectories: true)
                print("✅ Created conversations directory")
            } catch {
                print("❌ Failed to create conversations directory: \(error)")
            }
        }
    }
    
    // MARK: - User Profile
    func saveUserProfile(_ profile: UserProfile) {
        do {
            let data = try encoder.encode(profile)
            try data.write(to: userProfileFileURL)
            print("✅ Saved user profile for: \(profile.fullName)")
        } catch {
            print("❌ Failed to save user profile: \(error)")
        }
    }
    
    func loadUserProfile() -> UserProfile? {
        guard fileManager.fileExists(atPath: userProfileFileURL.path) else {
            print("ℹ️ No saved user profile found")
            return nil
        }
        do {
            let data = try Data(contentsOf: userProfileFileURL)
            let profile = try decoder.decode(UserProfile.self, from: data)
            print("✅ Loaded user profile for: \(profile.fullName)")
            return profile
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
            let data = try encoder.encode(conversation)
            try data.write(to: fileURL)
            saveConversationMetadata()
            print("✅ Saved conversation: \(conversation.title) (\(conversation.id))")
        } catch {
            print("❌ Failed to save conversation: \(error)")
        }
    }
    
    func loadConversation(id: String) -> Conversation? {
        let fileURL = conversationsDirectory.appendingPathComponent("\(id).json")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("ℹ️ Conversation not found: \(id)")
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let conversation = try decoder.decode(Conversation.self, from: data)
            return conversation
        } catch {
            print("❌ Failed to load conversation \(id): \(error)")
            return nil
        }
    }
    
    func deleteConversation(id: String) {
        let fileURL = conversationsDirectory.appendingPathComponent("\(id).json")
        do {
            try fileManager.removeItem(at: fileURL)
            saveConversationMetadata()
            print("✅ Deleted conversation: \(id)")
        } catch {
            print("❌ Failed to delete conversation \(id): \(error)")
        }
    }
    
    func createNewConversation(title: String = "New Chat") -> Conversation {
        let newConversation = Conversation(id: generateConversationId(), title: title)
        saveConversation(newConversation)
        print("✅ Created new conversation: \(title)")
        return newConversation
    }
    
    // MARK: - Metadata Management
    private func saveConversationMetadata() {
        var summaries: [ConversationSummary] = []
        do {
            let files = try fileManager.contentsOfDirectory(at: conversationsDirectory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                let data = try Data(contentsOf: file)
                let conversation = try decoder.decode(Conversation.self, from: data)
                summaries.append(ConversationSummary(conversation: conversation))
            }
        } catch {
            print("❌ Failed to load conversations for metadata: \(error)")
        }
        summaries.sort { $0.lastUpdated > $1.lastUpdated }
        do {
            let data = try encoder.encode(summaries)
            try data.write(to: metadataFileURL)
            DispatchQueue.main.async {
                self.allConversations = summaries
            }
            print("✅ Saved metadata for \(summaries.count) conversations")
        } catch {
            print("❌ Failed to save metadata: \(error)")
        }
    }
    
    func loadAllConversationsMetadata() {
        guard fileManager.fileExists(atPath: metadataFileURL.path) else {
            print("ℹ️ No metadata file found")
            return
        }
        do {
            let data = try Data(contentsOf: metadataFileURL)
            let summaries = try decoder.decode([ConversationSummary].self, from: data)
            DispatchQueue.main.async {
                self.allConversations = summaries
            }
            print("✅ Loaded metadata for \(summaries.count) conversations")
        } catch {
            print("❌ Failed to load metadata: \(error)")
        }
    }
    
    // MARK: - Helpers
    func getConversationHistory(for id: String) -> [StoredMessage] {
        return loadConversation(id: id)?.messages ?? []
    }
    
    func deleteAllData() {
        // Delete all conversation files
        do {
            let files = try fileManager.contentsOfDirectory(at: conversationsDirectory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                try fileManager.removeItem(at: file)
            }
            print("✅ Deleted all conversation files")
        } catch {
            print("❌ Failed to delete conversations: \(error)")
        }
        
        // Delete metadata
        try? fileManager.removeItem(at: metadataFileURL)
        
        // Delete user profile
        try? fileManager.removeItem(at: userProfileFileURL)
        
        // Clear in-memory data
        DispatchQueue.main.async {
            self.allConversations = []
        }
        
        print("✅ All data deleted")
    }
}
