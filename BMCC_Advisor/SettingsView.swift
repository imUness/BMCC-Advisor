import SwiftUI

struct SettingsView: View {
    @Binding var activeScreen: ActiveScreen
    @Environment(\.colorScheme) var colorScheme

    // Add your real settings here
    @AppStorage("serverURL") private var serverURL = "Computer Science"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Button {
                    withAnimation { activeScreen = .chat }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(barColor)
            .overlay(Divider(), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    Text("Settings")
                        .font(.largeTitle.bold())
                        .padding(.top, 8)

                    // Server section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SERVER")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        VStack(spacing: 0) {
                            HStack {
                                Text("Major selected")
                                Spacer()
                                TextField("Computer Science", text: $serverURL)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                            .padding()

                            Divider().padding(.leading)

                           
                        }
                        .background(sectionBackground)
                        .cornerRadius(12)
                    }

                    // About section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ABOUT")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)

                        VStack(spacing: 0) {
                            HStack {
                                Text("Name")
                                Spacer()
                                Text("Youness E.")
                                    .foregroundColor(.secondary)
                            }
                            .padding()

                            Divider().padding(.leading)

                            HStack {
                                Text("Excpected Graduation")
                                Spacer()
                                Text("2027")
                                    .foregroundColor(.secondary)
                            }
                            .padding()

                            Divider().padding(.leading)
                            
                            HStack {
                                Text("Schedule type")
                                Spacer()
                                Text("Full-time")
                                    .foregroundColor(.secondary)
                            }
                            .padding()

                            Divider().padding(.leading)
                            HStack {
                                Text("Version")
                                Spacer()
                                Text("1.0.0")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        .background(sectionBackground)
                        .cornerRadius(12)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .background(appBackground.ignoresSafeArea())
    }

    private var appBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemGroupedBackground)
    }

    private var barColor: Color {
        colorScheme == .dark
            ? Color(red: 0.1, green: 0.1, blue: 0.15)
            : Color(red: 0.97, green: 0.98, blue: 1.0)
    }

    private var sectionBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.15, blue: 0.2)
            : Color(.systemBackground)
    }
}

#Preview {
    SettingsView(activeScreen: .constant(.settings))
}
