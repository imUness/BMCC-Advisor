import SwiftUI

struct ChatHistoryView: View {
    let messages: [ChatMessage]
    @Binding var showSidebar: Bool
    @Binding var activeScreen: ActiveScreen
    @Environment(\.colorScheme) private var colorScheme

    // Group user messages as conversation starters
    private var userMessages: [ChatMessage] {
        messages.filter { $0.isUser }
    }

    var body: some View {
        ZStack(alignment: .leading) {

            // Dim background — tap to close
            Color.black.opacity(colorScheme == .dark ? 0.6 : 0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showSidebar = false }
                }

            // Sidebar panel
            VStack(alignment: .leading, spacing: 0) {

                // Title
                Text("History")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                Divider()

                // Message list
                if userMessages.isEmpty {
                    Spacer()
                    Text("No messages yet")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(userMessages) { msg in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(msg.text)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                        .foregroundColor(.primary)

                                    Text(msg.timestamp.formatted(.dateTime.hour().minute()))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)

                                Divider()
                                    .padding(.leading)
                            }
                        }
                    }
                }

                Divider()

                // Settings button at bottom
                Button {
                    withAnimation {
                        showSidebar = false
                        activeScreen = .settings
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .frame(width: 280)
            .frame(maxHeight: .infinity)
            .background(panelColor)
        }
    }

    private var panelColor: Color {
        colorScheme == .dark
            ? Color(red: 0.1, green: 0.1, blue: 0.15)
            : Color(.systemBackground)
    }
}

#Preview {
    ChatHistoryView(
        messages: [
            ChatMessage(text: "Hello, how are you?", isUser: true),
            ChatMessage(text: "I am doing well!", isUser: false),
            ChatMessage(text: "What can you help me with?", isUser: true)
        ],
        showSidebar: .constant(true),
        activeScreen: .constant(.chat)
    )
}
