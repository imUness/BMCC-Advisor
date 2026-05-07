import SwiftUI
import Combine

// MARK: - LLM Manager

class LLMManager: NSObject, ObservableObject {
    var onComplete: ((String) -> Void)?

    func send(prompt: String) {
        guard let url = URL(string: "https://mipilar.com/chat") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["user_input": prompt])
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data, let raw = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.onComplete?("Error: no response") }
                return
            }
            DispatchQueue.main.async { self.onComplete?(Self.stripThink(from: raw)) }
        }.resume()
    }

    static func stripThink(from text: String) -> String {
        var result = text
        while let start = result.range(of: "<think>"),
              let end = result.range(of: "</think>", range: start.upperBound..<result.endIndex) {
            result.removeSubrange(start.lowerBound...end.upperBound)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Keyboard Publisher

class KeyboardPublisher: ObservableObject {
    static let shared = KeyboardPublisher()
    @Published var keyboardHeight: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.keyboardHeight = $0 }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.keyboardHeight = 0 }
            .store(in: &cancellables)
    }
}

// MARK: - Chat View

struct ChatView: View {
    @Binding var activeScreen: ActiveScreen
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var textViewHeight: CGFloat = 40
    @State private var keyboardHeight: CGFloat = 0
    @State private var showSidebar = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var llm = LLMManager()

    var body: some View {
        ZStack {
            // Main chat
            VStack(spacing: 0) {
                headerView
                messagesView
                inputBarView
            }
            .background(appBackground.ignoresSafeArea())
            .onTapGesture { isInputFocused = false }
            .onReceive(KeyboardPublisher.shared.$keyboardHeight) { h in
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = h }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)

            // Sidebar overlay
            if showSidebar {
                ChatHistoryView(
                    messages: messages,
                    showSidebar: $showSidebar,
                    activeScreen: $activeScreen
                )
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSidebar)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button {
                withAnimation { showSidebar.toggle() }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundColor(.primary)
            }

            Spacer()

            Text("BMCC Advisor")
                .font(.headline.bold())
                .foregroundStyle(.blue)

            Spacer()

            Button {
                activeScreen = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(barColor)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Messages

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg).id(msg.id)
                    }
                    if isLoading { TypingIndicator() }
                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, keyboardHeight > 0
                    ? keyboardHeight + textViewHeight + 24
                    : textViewHeight + 24)
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: keyboardHeight) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBarView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 20).fill(inputFieldColor))
                        .frame(height: textViewHeight)

                    if inputText.isEmpty {
                        Text("Message Advisor…")
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $inputText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(height: textViewHeight)
                        .padding(.horizontal, 8)
                        .focused($isInputFocused)
                        .keyboardType(.asciiCapable)
                        .onChange(of: inputText) { _, _ in
                            let lines = inputText.components(separatedBy: .newlines).count
                                + max(0, inputText.count / 35)
                            textViewHeight = min(max(40, CGFloat(lines) * 22), 120)
                        }
                }

                Button { send() } label: {
                    Image(systemName: isLoading ? "stop.fill" : "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(isLoading ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(barColor)
            .offset(y: -keyboardHeight)
        }
    }

    // MARK: - Send

    private func send() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        messages.append(ChatMessage(text: prompt, isUser: true))
        inputText = ""
        textViewHeight = 40
        isLoading = true
        isInputFocused = false
        messages.append(ChatMessage(text: "", isUser: false))
        let botIndex = messages.count - 1
        llm.onComplete = { reply in
            self.messages[botIndex].text = reply
            self.isLoading = false
        }
        llm.send(prompt: prompt)
    }

    // MARK: - Colors

    private var appBackground: Color {
        colorScheme == .dark ? Color.black : Color(.systemBackground)
    }
    private var barColor: Color {
        colorScheme == .dark
            ? Color(red: 0.1, green: 0.1, blue: 0.15)
            : Color(red: 0.97, green: 0.98, blue: 1.0)
    }
    private var inputFieldColor: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.18) : Color.white
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }
            Text(message.text)
                .font(.system(size: 16))
                .foregroundColor(message.isUser ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(message.isUser ? Color.blue : botColor)
                .cornerRadius(18)
                .cornerRadius(4, corners: message.isUser ? .bottomRight : .bottomLeft)
                .multilineTextAlignment(message.isUser ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if !message.isUser { Spacer(minLength: 60) }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }

    private var botColor: Color {
        colorScheme == .dark
            ? Color(red: 0.15, green: 0.15, blue: 0.2)
            : Color(red: 0.92, green: 0.93, blue: 0.95)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dotScale: [CGFloat] = [0.5, 0.7, 0.5]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotScale[i])
                    .foregroundColor(.gray)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2)) {
                            dotScale[i] = 1.2
                        }
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(colorScheme == .dark
            ? Color(red: 0.15, green: 0.15, blue: 0.2)
            : Color(red: 0.92, green: 0.93, blue: 0.95))
        .cornerRadius(18)
        .cornerRadius(4, corners: .bottomLeft)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}

#Preview {
    ChatView(activeScreen: .constant(.chat))
}
