import SwiftUI
import Combine

// MARK: - Models (shared, define once)

struct AdvisorResponse: Codable {
    let message: String
    let plan: SemesterPlan?
}
struct SemesterPlan: Codable {
    let semesters: [PlanSemester]
    let totalCredits: Int
    let totalSemesters: Int
    let degreeRequires: Int?
    enum CodingKeys: String, CodingKey {
        case semesters
        case totalCredits   = "total_credits"
        case totalSemesters = "total_semesters"
        case degreeRequires = "degree_requires"
    }
}
struct PlanSemester: Codable, Identifiable {
    var id: String { name }
    let name: String
    let courses: [PlanCourse]
    let semesterCredits: Int
    enum CodingKeys: String, CodingKey {
        case name, courses
        case semesterCredits = "semester_credits"
    }
}
struct PlanCourse: Codable, Identifiable {
    var id: String { code }
    let code: String
    let title: String
    let credits: Int
    let mandatory: Bool
    let category: String
    let description: String?
    let prerequisites: [String]?

    // Default mandatory=true if server omits it (backward compat)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code          = try c.decode(String.self, forKey: .code)
        title         = try c.decode(String.self, forKey: .title)
        credits       = try c.decode(Int.self, forKey: .credits)
        mandatory     = try c.decodeIfPresent(Bool.self, forKey: .mandatory) ?? true
        category      = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        description   = try c.decodeIfPresent(String.self, forKey: .description)
        prerequisites = try c.decodeIfPresent([String].self, forKey: .prerequisites)
    }

    enum CodingKeys: String, CodingKey {
        case code, title, credits, mandatory, category, description, prerequisites
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    var streamText: String = ""     // raw tokens while streaming
    var response: AdvisorResponse?  // set once complete
    let isUser: Bool
    let timestamp = Date()

    // convenience
    var displayText: String {
        response?.message ?? streamText
    }
}

// MARK: - Keyboard helper (unchanged)

class KeyboardPublisher: ObservableObject {
    static let shared = KeyboardPublisher()
    @Published var keyboardHeight: CGFloat = 0
    private var bag = Set<AnyCancellable>()
    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] h in self?.keyboardHeight = h }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.keyboardHeight = 0 }
            .store(in: &bag)
    }
}

// MARK: - ChatView

struct ChatView: View {
    @Binding var activeScreen: ActiveScreen

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var textHeight: CGFloat = 40
    @State private var showSidebar = false
    @State private var convId: String?
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var inputFocused: Bool
    @Environment(\.colorScheme) private var scheme

    @StateObject private var llm     = LLMManager()
    @StateObject private var storage = ChatStorageManager.shared
    @StateObject private var profile = UserProfileManager.shared

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                messageList
                inputBar
            }
            .background(bg.ignoresSafeArea())
            .onTapGesture { inputFocused = false }
            .onReceive(KeyboardPublisher.shared.$keyboardHeight) { height in
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = height }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onAppear {
                profile.loadProfile()
                if convId == nil { newConversation() }
            }

            if showSidebar {
                ChatHistoryView(
                    activeScreen: $activeScreen,
                    showSidebar: $showSidebar,
                    currentConversationId: $convId,
                    onConversationSelected: loadConversation,
                    onNewConversation: newConversation
                )
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSidebar)
    }

    // ── Header ──────────────────────────────────────────────────────────────

    private var header: some View {
        HStack {
            Button { withAnimation { showSidebar.toggle() } } label: {
                Image(systemName: "line.3.horizontal").font(.title2).foregroundColor(.primary)
            }
            Spacer()
            Text("BMCC Advisor").font(.headline.bold()).foregroundStyle(.blue)
            Spacer()
            Button { activeScreen = .settings } label: {
                Image(systemName: "gearshape").font(.title2).foregroundColor(.primary)
            }
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(barColor)
        .overlay(Divider(), alignment: .bottom)
    }

    // ── Message list ─────────────────────────────────────────────────────────

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        BubbleView(msg: msg).id(msg.id)
                    }
                    if isLoading { TypingDots() }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom,
                    keyboardHeight > 0
                        ? keyboardHeight + textHeight + 24
                        : textHeight + 24
                )
                .onChange(of: messages.count) { _, _ in scroll(proxy) }
                .onChange(of: isLoading)      { _, _ in scroll(proxy) }
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    // ── Input bar ────────────────────────────────────────────────────────────

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 20).fill(fieldColor))
                        .frame(height: textHeight)

                    if inputText.isEmpty {
                        Text("Message Advisor…")
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $inputText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(height: textHeight)
                        .padding(.horizontal, 8)
                        .focused($inputFocused)
                        .onChange(of: inputText) { _, _ in
                            let lines = inputText.components(separatedBy: .newlines).count
                                      + max(0, inputText.count / 35)
                            textHeight = min(max(40, CGFloat(lines) * 22), 120)
                        }
                }

                Button {
                    if isLoading { llm.stop(); isLoading = false }
                    else { send() }
                } label: {
                    Image(systemName: isLoading ? "stop.fill" : "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(isLoading ? Color.red : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(!isLoading && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(barColor)
            .offset(y: -keyboardHeight)
        }
    }

    // ── Core ─────────────────────────────────────────────────────────────────

    private func newConversation() {
        let c = storage.createNewConversation(title: "New Chat")
        convId = c.id
        messages = []
    }

    private func loadConversation(_ id: String) {
        guard let c = storage.loadConversation(id: id) else { return }
        convId   = c.id
        messages = c.messages.map { s in
            var m = ChatMessage(isUser: s.isUser)
            m.streamText = s.text
            if !s.isUser, let d = s.text.data(using: .utf8) {
                m.response = try? JSONDecoder().decode(AdvisorResponse.self, from: d)
            }
            return m
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if convId == nil { newConversation() }

        // Always refresh profile right before sending
        profile.refreshFromUserDefaults()
        guard let p = profile.currentProfile else {
            print("⚠️ No profile found — check UserProfileManager")
            return
        }

        // User bubble
        var userMsg = ChatMessage(isUser: true)
        userMsg.streamText = text
        messages.append(userMsg)
        persist(StoredMessage(id: userMsg.id.uuidString, text: text,
                              isUser: true, timestamp: userMsg.timestamp))

        inputText  = ""; textHeight = 40; isLoading = true; inputFocused = false

        // Bot placeholder
        var botMsg = ChatMessage(isUser: false)
        messages.append(botMsg)
        let botIdx = messages.count - 1

        let history = storage.getConversationHistory(for: convId!)

        // Per-token: show partial message field while streaming
        llm.onToken = { token in
            messages[botIdx].streamText += token
        }

        // On complete: swap in parsed response
        llm.onComplete = { rawJSON in
            print("\n━━━━ BOT RESPONSE ━━━━")
            print(rawJSON)
            print("━━━━━━━━━━━━━━━━━━━━━━\n")

            if let data = rawJSON.data(using: .utf8),
               let parsed = try? JSONDecoder().decode(AdvisorResponse.self, from: data) {
                messages[botIdx].response  = parsed
                messages[botIdx].streamText = rawJSON
            } else {
                // Couldn't parse — show raw as plain text
                messages[botIdx].streamText = rawJSON
            }

            persist(StoredMessage(text: rawJSON, isUser: false, timestamp: Date()))
            isLoading = false
        }

        llm.send(
            userMessage: text,
            userProfile: p,
            conversationHistory: history,
            conversationId: convId!
        )
    }

    private func persist(_ msg: StoredMessage) {
        guard let id = convId,
              var conv = storage.loadConversation(id: id) else { return }
        conv.messages.append(msg)
        conv.lastUpdated = Date()
        if conv.messages.filter({ $0.isUser }).count == 1 && msg.isUser {
            conv.title = String(msg.text.prefix(30))
        }
        storage.saveConversation(conv)
        storage.loadAllConversationsMetadata()
    }

    // ── Colors ───────────────────────────────────────────────────────────────

    private var bg: Color       { scheme == .dark ? .black : Color(.systemBackground) }
    private var barColor: Color { scheme == .dark ? Color(red:0.1,green:0.1,blue:0.15) : Color(red:0.97,green:0.98,blue:1) }
    private var fieldColor: Color { scheme == .dark ? Color(red:0.12,green:0.12,blue:0.18) : .white }
}

// MARK: - Bubble

struct BubbleView: View {
    let msg: ChatMessage
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(alignment: .top) {
            if msg.isUser {
                Spacer()
                UserBubble(text: msg.streamText)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "graduationcap.fill").font(.caption).foregroundColor(.blue)
                        Text("BMCC Advisor").font(.caption).foregroundColor(.secondary)
                    }
                    BotContent(msg: msg)
                }
                .padding(.horizontal, 2)
                Spacer(minLength: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: msg.isUser ? .trailing : .leading)
    }
}

// MARK: - Bot Content

struct BotContent: View {
    let msg: ChatMessage

    var body: some View {
        if let response = msg.response {
            // ── Full parsed response ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 14) {
                if !response.message.isEmpty {
                    Text(response.message)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let plan = response.plan {
                    PlanView(plan: plan)
                }
            }
        } else {
            // ── Streaming: extract message field while tokens arrive ───────
            Text(partialMessage(from: msg.streamText))
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Extracts the partial value of "message": "..." from incomplete JSON
    private func partialMessage(from raw: String) -> String {
        guard let keyRange = raw.range(of: #""message"\s*:\s*""#,
                                       options: .regularExpression) else {
            return raw.isEmpty ? "…" : "…"
        }
        let after = String(raw[keyRange.upperBound...])
        var result = ""
        var escaped = false
        for ch in after {
            if escaped { result.append(ch); escaped = false; continue }
            if ch == "\\" { escaped = true; continue }
            if ch == "\"" { break }
            result.append(ch)
        }
        return result.isEmpty ? "…" : result
    }
}

// MARK: - Plan View

struct PlanView: View {
    let plan: SemesterPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary badges
            HStack(spacing: 12) {
                StatBadge(value: "\(plan.totalCredits)", label: "Total Credits")
                StatBadge(value: "\(plan.totalSemesters)", label: "Semesters")
            }
            // Semester cards
            ForEach(plan.semesters) { sem in
                SemesterCard(semester: sem)
            }
            // Footer
            HStack(spacing: 4) {
                Image(systemName: "info.circle").font(.caption2)
                Text("Always verify with your advisor and DegreeWorks.")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Semester Card (collapsible)

struct SemesterCard: View {
    let semester: PlanSemester
    @State private var open = true
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header tap to collapse
            Button { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } } label: {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption).foregroundColor(.blue)
                    Text(semester.name)
                        .font(.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                    Spacer()
                    Text("\(semester.semesterCredits) cr")
                        .font(.caption).foregroundColor(.secondary)
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(headerBg)
            }
            .buttonStyle(.plain)

            if open {
                VStack(spacing: 0) {
                    ForEach(Array(semester.courses.enumerated()), id: \.element.id) { idx, course in
                        CourseRow(course: course)
                        if idx < semester.courses.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(rowBg)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.18), lineWidth: 1))
    }

    private var headerBg: Color {
        scheme == .dark
            ? Color(red: 0.1, green: 0.14, blue: 0.24)
            : Color(red: 0.92, green: 0.96, blue: 1.0)
    }
    private var rowBg: Color {
        scheme == .dark
            ? Color(red: 0.08, green: 0.1, blue: 0.16)
            : Color(.systemBackground)
    }
}

// MARK: - Course Row (expandable detail)

struct CourseRow: View {
    let course: PlanCourse
    @State private var detail = false
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation { detail.toggle() } } label: {
                HStack(alignment: .center, spacing: 10) {
                    // Colour strip
                    Capsule()
                        .fill(course.mandatory ? Color.blue : Color.orange)
                        .frame(width: 4, height: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(course.code)
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Spacer()
                            Text("\(course.credits) cr")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Text(course.title)
                            .font(.subheadline).foregroundColor(.primary)
                            .lineLimit(1)
                        // Badges
                        HStack(spacing: 5) {
                            Badge(text: course.mandatory ? "Required" : "Elective",
                                  fg: course.mandatory ? .blue : .orange,
                                  bg: course.mandatory
                                      ? Color.blue.opacity(0.1)
                                      : Color.orange.opacity(0.1))
                            if !course.category.isEmpty {
                                Badge(text: prettyCat(course.category),
                                      fg: .secondary,
                                      bg: Color.gray.opacity(0.1))
                            }
                        }
                    }

                    Image(systemName: detail ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(.vertical, 10).padding(.horizontal, 14)
            }
            .buttonStyle(.plain)

            if detail {
                VStack(alignment: .leading, spacing: 6) {
                    if let desc = course.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption).foregroundColor(.secondary)
                    }
                    if let pre = course.prerequisites, !pre.isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "link").font(.caption2).foregroundColor(.orange)
                            Text("Prereqs: \(pre.joined(separator: ", "))")
                                .font(.caption).foregroundColor(.orange)
                        }
                    }
                }
                .padding(.horizontal, 32).padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Turn "major_required" into "Major Required" for display
    private func prettyCat(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Small reusable views

struct Badge: View {
    let text: String; let fg: Color; let bg: Color
    var body: some View {
        Text(text)
            .font(.caption2).foregroundColor(fg)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(bg).clipShape(Capsule())
    }
}

struct StatBadge: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2).fontWeight(.bold).foregroundColor(.blue)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.08))
        .cornerRadius(10)
    }
}

struct UserBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.body).foregroundColor(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(18)
            .cornerRadius(4, corners: .bottomRight)
            .textSelection(.enabled)
    }
}

struct TypingDots: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary.opacity(phase == i ? 1 : 0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// MARK: - Corner radius helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                          cornerRadii: .init(width: radius, height: radius)).cgPath)
    }
}

#Preview { ChatView(activeScreen: .constant(.chat)) }
