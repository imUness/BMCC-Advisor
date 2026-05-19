import SwiftUI
import Combine

// MARK: - Navigation

enum ActiveScreen: Equatable {
    case login
    case chat
    case settings
    case onboard
}

// MARK: - Root View

struct RootView: View {
    @State private var activeScreen: ActiveScreen = .login
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false  // Just this one flag

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
        // User is logged in AND completed onboarding
        if isLoggedIn && hasOnboarded {
            activeScreen = .chat
        }
        // User is logged in but hasn't completed onboarding
        else if isLoggedIn && !hasOnboarded {
            activeScreen = .onboard
        }
        // User not logged in
        else {
            activeScreen = .login
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
