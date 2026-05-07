import SwiftUI

struct ChatHistoryView: View {
    let messages: [ChatMessage]
    @Binding var showSidebar: Bool
    @Binding var activeScreen: ActiveScreen
    @Environment(\.colorScheme) private var colorScheme

    // Group messages into conversations by user messages
    private var conversations: [(id: UUID, preview: String, time: Date)] {
        messages
            .filter { $0.isUser }
            .map { (id: $0.id, preview: $0.text, time: $0.timestamp) }
    }

    var body: some View {
        ZStack(alignment: .leading) {

            // Dim backdrop — tap to close
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showSidebar = false }
                }

            // Panel
            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack {
                    Text("Chats")
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        withAnimation { showSidebar = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 56)
                .padding(.bottom, 12)

                Divider()

                // Conversation list
                if conversations.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No conversations yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(conversations, id: \.id) { convo in
                                Button {
                                    withAnimation { showSidebar = false }
                                } label: {
                                    HStack(spacing: 12) {
                                        // Icon
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.15))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "bubble.left.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.blue)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(convo.preview)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text(convo.time.formatted(.dateTime.month().day().hour().minute()))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                }

                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                }

                Divider()

                // Settings button at bottom
                Button {
                    withAnimation { showSidebar = false }
                    activeScreen = .settings
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 36, height: 36)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        Text("Settings")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 14)
                }
            }
            .frame(width: 300)
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
            ChatMessage(text: "What classes should I take next semester?", isUser: true),
            ChatMessage(text: "Based on your major...", isUser: false),
            ChatMessage(text: "How do I apply for financial aid?", isUser: true),
            ChatMessage(text: "You can apply at...", isUser: false),
        ],
        showSidebar: .constant(true),
        activeScreen: .constant(.chat)
    )
}
