import SwiftUI

struct OnboardingView: View {
    
    @Binding var activeScreen: ActiveScreen
    @AppStorage("userId") var userId: String = ""
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("firstName") var firstName = ""
    @AppStorage("lastName") var lastName = ""
    @AppStorage("major") var major = ""
    @AppStorage("scheduleType") var scheduleType = "Full-time"
    @AppStorage("startSemester") var startSemester = "Fall"
    @AppStorage("startYear") var startYear = ""
    @AppStorage("gradSemester") var gradSemester = "Spring"
    @AppStorage("graduationYear") var graduationYear = ""
    @AppStorage("completedCourses") var completedCoursesData: String = "[]"

    @State private var startYearInput = ""
    @State private var graduationYearInput = ""
    @State private var majorInput = ""
    @State private var showSuggestions = false
    @State private var courseInput = ""
    @State private var completedCourses: [String] = []
    @FocusState private var focusedField: Field?
    
    enum Field {
        case firstName
        case lastName
        case major
        case startYear
        case graduationYear
        case courseInput
    }

    let majors = [
        "Computer Science",
        "Business Administration",
        "Mathematics",
        "Biology",
        "Psychology",
        "Nursing",
        "Engineering Science",
        "Accounting (A.A.S.)",
        "Accounting (Certificate)",
        "Accounting for Forensic Accounting (A.S.)",
        "Animation and Motion Graphics (A.S.)",
        "Art Foundations: Art History (A.A.)",
        "Art Foundations: Studio Art (A.S.)",
        "Bilingual Childhood Education (A.A.)",
        "Biotechnology Science (A.S.)",
        "Business Management (A.A.S.)",
        "Child Care / Early Childhood Education (A.S.)",
        "Childhood Education (A.A.)",
        "Children and Youth Studies (A.A.)",
        "Communication Studies (A.A.)",
        "Community Health Education (A.S.)",
        "Computer Information Systems (A.A.S.)",
        "Computer Network Technology (A.A.S.)",
        "Criminal Justice (A.A.)",
        "Critical Thinking and Justice (A.A.)",
        "Cybersecurity (Certificate)",
        "Data Science (A.S.)",
        "Digital Marketing (A.S.)",
        "Economics (A.A.)",
        "Ethnic Studies (A.A.)",
        "Financial Management (A.S.)",
        "Gender and Women's Studies (A.A.)",
        "Geographic Information Science (A.S.)",
        "Gerontology (A.S.)",
        "Health Informatics (Certificate)",
        "Health Information Technology (A.A.S.)",
        "History (A.A.)",
        "Human Services (A.S.)",
        "Liberal Arts (A.A.)",
        "Linguistics (A.A.)",
        "Literacy Studies (A.A.)",
        "Mathematics (A.S.)",
        "Modern Languages (A.A.)",
        "Multimedia Programming and Design (A.S.)",
        "Music (A.S.)",
        "Nursing (A.A.S.)",
        "Nursing / Dual Degree with CUNY School of Professional Studies (A.A.S.)",
        "Paramedic (A.A.S.)",
        "Philosophy (A.A.)",
        "Political Science (A.A.)",
        "Practical Nursing (Certificate)",
        "Psychology (A.A.)",
        "Public Health (A.S.)",
        "Public and Nonprofit Administration (A.S.)",
        "Respiratory Therapy (A.A.S.)",
        "School Health Education (A.S.)",
        "Science (A.S.)",
        "Science for Forensics (A.S.)",
        "Science for Health (A.S.)",
        "Secondary Education for Mathematics and Science (A.S.)",
        "Small Business / Entrepreneurship (A.A.S.)",
        "Social Studies for Secondary Education (A.A.)",
        "Sociology (A.A.)",
        "Spanish Translation for the Health, Legal and Business Professions (Certificate)",
        "Theatre (A.S.)",
        "Urban Studies (A.A.)",
        "Video Arts and Technology (A.S.)",
        "Writing and Literature (A.A.)"
    ]
    
    let commonCourses = [
        "ENG 101", "ENG 201", "MAT 100", "MAT 104", "MAT 150", "MAT 161.5", "MAT 206", "MAT 301",
        "CSC 101", "CSC 111", "CSC 211", "CSC 231", "CSC 232", "CIS 100", "CIS 165",
        "BIO 110", "BIO 210", "BIO 425", "BIO 426", "CHE 121", "CHE 201", "CHE 202",
        "PHY 110", "PHY 215", "PHY 225", "PSY 100", "PSY 200", "SOC 100", "HIS 101",
        "HIS 102", "POL 100", "ART 100", "MUS 100", "SPE 100", "ECO 201", "ECO 202"
    ]

    let scheduleOptions = ["Full-time", "Part-time"]
    let semesters = ["Fall", "Spring", "Summer"]
    
    var filteredCourses: [String] {
        if courseInput.isEmpty { return [] }
        return commonCourses.filter {
            $0.lowercased().contains(courseInput.lowercased())
        }.prefix(5).map { String($0) }
    }

    var filteredMajors: [String] {
        if majorInput.isEmpty { return [] }
        return majors.filter {
            $0.lowercased().contains(majorInput.lowercased())
        }
    }

    var bestMatch: String? {
        majors.first {
            $0.lowercased().hasPrefix(majorInput.lowercased())
        }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 20) {

                    Spacer()
                        .id("top")

                    Text("Hello Student!")
                        .font(.largeTitle.bold())

                    Text("To give you more accurate info, we need to know some details about you.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.gray)

                    Spacer()

                    // Name
                    TextField("First Name", text: $firstName)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .firstName)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .lastName
                        }

                    TextField("Last Name", text: $lastName)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .lastName)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .major
                        }

                    // MARK: - Major
                    VStack(alignment: .leading, spacing: 5) {
                        ZStack(alignment: .leading) {
                            if let match = bestMatch,
                               !majorInput.isEmpty,
                               majorInput.lowercased() != match.lowercased() {
                                Text(match)
                                    .foregroundColor(.gray.opacity(0.4))
                                    .padding(.horizontal, 12)
                            }
                            TextField("Major", text: $majorInput)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .focused($focusedField, equals: .major)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .startYear
                                }
                                .onChange(of: majorInput) { _, newValue in
                                    showSuggestions = !newValue.isEmpty
                                }
                        }

                        if showSuggestions && !filteredMajors.isEmpty {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(filteredMajors, id: \.self) { item in
                                        Text(item)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                majorInput = item
                                                showSuggestions = false
                                                hideKeyboard()
                                            }
                                        Divider()
                                    }
                                }
                            }
                            .frame(maxHeight: 120)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 3)
                            .zIndex(999)
                        }
                    }
                    .id("majorField")

                    // Schedule
                    Picker("Schedule", selection: $scheduleType) {
                        ForEach(scheduleOptions, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Start Semester
                    Picker("Start Semester", selection: $startSemester) {
                        ForEach(semesters, id: \.self) { sem in
                            Text(sem)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Start Year
                    TextField("Start Year (e.g. 2024)", text: $startYearInput)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .startYear)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .graduationYear
                        }

                    // Graduation Semester
                    Picker("Graduation Semester", selection: $gradSemester) {
                        ForEach(semesters, id: \.self) { sem in
                            Text(sem)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Graduation Year
                    TextField("Graduation Year (e.g. 2027)", text: $graduationYearInput)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .graduationYear)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .courseInput
                        }

                    // MARK: - Completed Courses Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Completed Courses")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Add courses you've already completed (e.g., ENG 101, MAT 150)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Course input with autocomplete
                        VStack(alignment: .leading, spacing: 5) {
                            ZStack(alignment: .leading) {
                                TextField("Search for a course...", text: $courseInput)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .autocapitalization(.allCharacters)
                                    .focused($focusedField, equals: .courseInput)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        addCourse()
                                    }
                            }
                            
                            if !courseInput.isEmpty && !filteredCourses.isEmpty {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(filteredCourses, id: \.self) { course in
                                            Text(course)
                                                .padding()
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    courseInput = course
                                                    addCourse()
                                                }
                                            Divider()
                                        }
                                    }
                                }
                                .frame(maxHeight: 150)
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 3)
                                .zIndex(999)
                            }
                        }
                        .id("courseInputField")
                        
                        // Chips for completed courses
                        if !completedCourses.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(completedCourses, id: \.self) { course in
                                    HStack(spacing: 4) {
                                        Text(course)
                                            .font(.subheadline)
                                        Button(action: {
                                            removeCourse(course)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(15)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 0.5)
                                    )
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            Text("No courses added yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    .id("completedCoursesSection")

                    // Continue
                    Button("Continue") {
                        major = majorInput
                        startYear = startYearInput
                        graduationYear = graduationYearInput
                        
                        if let jsonData = try? JSONEncoder().encode(completedCourses),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            completedCoursesData = jsonString
                        }
                        
                        if userId.isEmpty {
                            userId = UUID().uuidString
                        }
                        
                        let profile = UserProfile(
                            userId: userId,
                            firstName: firstName,
                            lastName: lastName,
                            major: major,
                            scheduleType: scheduleType,
                            startSemester: startSemester,
                            startYear: startYear,
                            gradSemester: gradSemester,
                            graduationYear: graduationYear,
                            completedCourses: completedCourses
                        )
                        UserProfileManager.shared.updateProfile(profile)
                        
                        print("✅ Onboarding complete for user: \(userId)")
                        print("📅 Start: \(startSemester) \(startYear)")
                        print("📅 Graduation: \(gradSemester) \(graduationYear)")
                        print("📚 Completed Courses: \(completedCourses)")
                        
                        hasOnboarded = true
                        isLoggedIn = true
                        activeScreen = .chat
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Spacer()
                        .frame(height: 50)
                        .id("bottom")
                }
                .padding()
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue == .courseInput {
                    withAnimation {
                        scrollProxy.scrollTo("courseInputField", anchor: .center)
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onTapGesture {
            hideKeyboard()
            focusedField = nil
        }
        .onAppear {
            majorInput = major
            startYearInput = startYear
            graduationYearInput = graduationYear
            
            if let jsonData = completedCoursesData.data(using: .utf8),
               let savedCourses = try? JSONDecoder().decode([String].self, from: jsonData) {
                completedCourses = savedCourses
            }
        }
    }
    
    private func addCourse() {
        let trimmed = courseInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        
        let isValidCourse = commonCourses.contains(trimmed) ||
                            trimmed.range(of: "^[A-Z]{3,4}\\s\\d{3}[A-Z]?$", options: .regularExpression) != nil
        
        if isValidCourse && !completedCourses.contains(trimmed) {
            completedCourses.append(trimmed)
            courseInput = ""
        } else if completedCourses.contains(trimmed) {
            courseInput = ""
        }
    }
    
    private func removeCourse(_ course: String) {
        completedCourses.removeAll { $0 == course }
    }
}

// MARK: - Flow Layout for Chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: ProposedViewSize(result.sizes[index]))
        }
    }
    
    struct FlowResult {
        var sizes: [CGSize] = []
        var positions: [CGPoint] = []
        var height: CGFloat = 0
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                sizes.append(size)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                height = currentY + lineHeight
            }
        }
    }
}

// MARK: - Keyboard Helper
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
#endif

#Preview {
    OnboardingView(activeScreen: .constant(.onboard))
}
