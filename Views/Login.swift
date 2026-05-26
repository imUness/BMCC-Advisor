import SwiftUI

struct LoginView: View {
    @Binding var activeScreen: ActiveScreen
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("userId") var userId: String = ""  // Store user ID
    
    @FocusState private var focusedField: Field?
    
    
    enum Field {
        case loginUsername
        case loginPassword
        case createEmail
        case createPassword
        case createConfirm
    }

    enum Screen { case login, create }
    @State private var screen: Screen = .login
    @State private var loginUsername = ""
    @State private var loginPassword = ""
    @State private var createEmail = ""
    @State private var createPassword = ""
    @State private var createConfirm = ""
    @State private var errorMessage = ""

    // Replace with real auth later
    let mockUsers: [String: String] = ["admin": "1234"]

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Title
                    VStack(spacing: 4) {
                        Text("BMCC Advisor")
                            .font(.largeTitle.bold())
                        Text("Your AI Academic Assistant")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .padding(.bottom, 32)

                    // Tab switcher
                    HStack(spacing: 0) {
                        Button {
                            screen = .login
                            errorMessage = ""
                        } label: {
                            Text("Login")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(screen == .login ? Color.blue : Color.clear)
                                .foregroundColor(screen == .login ? .white : .secondary)
                        }

                        Button {
                            screen = .create
                            errorMessage = ""
                        } label: {
                            Text("Create Account")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(screen == .create ? Color.blue : Color.clear)
                                .foregroundColor(screen == .create ? .white : .secondary)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 24)

                    // Forms
                    VStack(spacing: 12) {
                        if screen == .login {
                            TextField("Username", text: $loginUsername)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .loginUsername)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .loginPassword
                                }

                            SecureField("Password", text: $loginPassword)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .focused($focusedField, equals: .loginPassword)
                                .submitLabel(.done)
                                .onSubmit {
                                    performLogin()
                                }

                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                performLogin()
                            } label: {
                                Text("Login")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .id("loginButton")

                        } else {
                            TextField("Email", text: $createEmail)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .createEmail)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .createPassword
                                }

                            SecureField("Password", text: $createPassword)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .focused($focusedField, equals: .createPassword)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .createConfirm
                                }

                            SecureField("Confirm Password", text: $createConfirm)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .focused($focusedField, equals: .createConfirm)
                                .submitLabel(.done)
                                .onSubmit {
                                    performCreateAccount()
                                }

                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                performCreateAccount()
                            } label: {
                                Text("Create Account")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .id("createButton")
                        }
                    }
                    .padding(.horizontal)

                    // Spacer to push content up when keyboard appears
                    Color.clear
                        .frame(height: 100)
                        .id("bottomSpacer")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedField) { _, newValue in
                if newValue != nil {
                    withAnimation {
                        scrollProxy.scrollTo("bottomSpacer", anchor: .bottom)
                    }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onTapGesture {
                focusedField = nil
            }
            
            // Footer - Outside ScrollView to keep it at bottom
            VStack(spacing: 12) {
                Button {
                    isLoggedIn = true
                    userId = UUID().uuidString
                    print("🆓 GUEST USER ID: \(userId)")
                    activeScreen = .chat
                } label: {
                    Text("Continue as Guest")
                }
                .padding(.horizontal)

                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .multilineTextAlignment(.center)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func performLogin() {
        let u = loginUsername.trimmingCharacters(in: .whitespaces).lowercased()
        let p = loginPassword.trimmingCharacters(in: .whitespaces)
        if mockUsers[u] == p {
            isLoggedIn = true
            userId = UUID().uuidString  // Generate and save user ID
            
            // Print user ID
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🆓 USER ID: \(userId)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            activeScreen = .onboard
        }
        else {
            errorMessage = "Invalid username or password."
        }
    }
    
    private func performCreateAccount() {
        if createEmail.isEmpty || createPassword.isEmpty {
            errorMessage = "All fields are required."
        } else if createPassword != createConfirm {
            errorMessage = "Passwords do not match."
        } else {
            activeScreen = .chat
        }
    }
}

#Preview {
    LoginView(activeScreen: .constant(.login))
}
