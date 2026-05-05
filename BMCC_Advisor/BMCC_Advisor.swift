import SwiftUI

// MARK: - Navigation

enum ActiveScreen {
    case chat
    case settings
}

// MARK: - Model

struct ChatMessage: Identifiable {
    let id = UUID()
    var text: String
    let isUser: Bool
    let timestamp: Date = Date()
}

// MARK: - Entry Point

@main
struct BMCC_Advisor: App {
    var body: some Scene {
        WindowGroup {
            ChatView()
        }
    }
}
