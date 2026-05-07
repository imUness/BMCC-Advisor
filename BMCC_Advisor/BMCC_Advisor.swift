import SwiftUI
import Combine

// MARK: - Navigation

enum ActiveScreen: Equatable {
    case login
    case chat
    case settings
    case onboard
}

// MARK: - Model

struct ChatMessage: Identifiable {
    let id = UUID()
    var text: String
    let isUser: Bool
    let timestamp: Date = Date()
}

// MARK: - Root View

struct RootView: View {
    @State private var activeScreen: ActiveScreen = .login
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("hasLoggedIn") var hasLoggedIn: Bool = false

    var body: some View {
        ZStack {
            if activeScreen == .onboard {
                OnboardingView(activeScreen: $activeScreen)
            } else if activeScreen == .login {
                LoginView(activeScreen: $activeScreen)
            } else if activeScreen == .chat {
                ChatView(activeScreen: $activeScreen)
            } else if activeScreen == .settings {
                SettingsView(activeScreen: $activeScreen)
            }
        }
        .onAppear {
            determineInitialScreen()
        }
    }
    
    func determineInitialScreen() {
        // First time ever opening the app - start with Login
        if !hasOnboarded {
            activeScreen = .login
        }
        // User has completed onboarding but not logged in
        else if !hasLoggedIn {
            activeScreen = .login
        }
        // User has completed everything - go to chat
        else {
            activeScreen = .chat
        }
    }
}

// MARK: - Entry Point

@main
struct BMCC_Advisor: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
