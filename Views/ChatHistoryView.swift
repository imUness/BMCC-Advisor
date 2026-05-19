import SwiftUI

struct ChatHistoryView: View {
    @Binding var activeScreen: ActiveScreen
    @Binding var showSidebar: Bool
    @Binding var currentConversationId: String?
    @StateObject private var storageManager = ChatStorageManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    let onConversationSelected: (String) -> Void
    let onNewConversation: () -> Void
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Dim backdrop
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showSidebar = false }
                }
            
            // Sidebar Panel
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Chats")
                        .font(.title2.bold())
                    Spacer()
                    
                    // New Chat Button
                    Button {
                        onNewConversation()
                        withAnimation { showSidebar = false }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    
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
                
                // Conversation List
                if storageManager.allConversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No conversations yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Tap the pencil icon to start")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(storageManager.allConversations) { conversation in
                                ConversationRow(
                                    conversation: conversation,
                                    isSelected: currentConversationId == conversation.id
                                ) {
                                    onConversationSelected(conversation.id)
                                    withAnimation { showSidebar = false }
                                }
                                .onLongPressGesture {
                                    // Delete conversation
                                    storageManager.deleteConversation(id: conversation.id)
                                    if currentConversationId == conversation.id {
                                        onNewConversation()
                                    }
                                    storageManager.loadAllConversationsMetadata()
                                }
                                
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Settings Button
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
        .onAppear {
            storageManager.loadAllConversationsMetadata()
        }
    }
    
    private var panelColor: Color {
        colorScheme == .dark
            ? Color(red: 0.1, green: 0.1, blue: 0.15)
            : Color(.systemBackground)
    }
}

// MARK: - Conversation Row
struct ConversationRow: View {
    let conversation: ConversationSummary
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Icon with selection indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .white : .blue)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .blue : .primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text("\(conversation.messageCount) messages")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 3, height: 3)
                        
                        Text(formattedDate(conversation.lastUpdated))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ChatHistoryView(
        activeScreen: .constant(.chat),
        showSidebar: .constant(true),
        currentConversationId: .constant("conv_123"),
        onConversationSelected: { _ in },
        onNewConversation: {}
    )
}
