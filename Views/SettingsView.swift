import SwiftUI

struct SettingsView: View {
    @Binding var activeScreen: ActiveScreen
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("hasLoggedIn") var hasLoggedIn: Bool = false
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    @StateObject private var profileManager = UserProfileManager.shared

    // User Profile Settings
    @AppStorage("firstName") var firstName = ""
    @AppStorage("lastName") var lastName = ""
    @AppStorage("major") var major = ""
    @AppStorage("scheduleType") var scheduleType = "Full-time"
    @AppStorage("startSemester") var startSemester = "Fall"
    @AppStorage("startYear") var startYear = ""
    @AppStorage("gradSemester") var gradSemester = "Spring"
    @AppStorage("graduationYear") var graduationYear = ""
    @AppStorage("completedCoursesData") var completedCoursesData: String = "[]"
    @AppStorage("takesSummerClasses") var takesSummerClasses: Bool = false  // NEW

    @AppStorage("aiTone") private var aiTone: String = "Balanced"
    @AppStorage("saveChatHistory") private var saveChatHistory: Bool = true
    @AppStorage("notifications") private var notifications: Bool = true

    @State private var completedCourses: [String] = []
    @State private var showCompletedCoursesSheet = false

    let scheduleOptions = ["Full-time", "Part-time"]
    // CHANGED: removed "Summer" — Fall/Spring only in pickers
    let semesters = ["Fall", "Spring"]
    let graduationYears = Array(2025...2035).map { String($0) }

    let majorsList = [
        "Computer Science (A.S.)",
        "Business Administration (A.S.)",
        "Mathematics (A.S.)",
        "Biology (A.S.)",
        "Psychology (A.A.)",
        "Nursing (A.A.S.)",
        "Engineering Science (A.S.)",
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

    // MARK: - Profile Sync Functions
    private func syncProfileToManager() {
        let updatedProfile = UserProfile(
            userId: profileManager.currentProfile?.userId ?? UUID().uuidString,
            firstName: firstName,
            lastName: lastName,
            major: major,
            scheduleType: scheduleType,
            startSemester: startSemester,
            startYear: startYear,
            gradSemester: gradSemester,
            graduationYear: graduationYear,
            completedCourses: completedCourses,
            takesSummerClasses: takesSummerClasses  // NEW
        )
        profileManager.updateProfile(updatedProfile)
        print("✅ Settings updated - Profile: \(updatedProfile.fullName), Summer: \(takesSummerClasses), Courses: \(completedCourses.count)")
    }

    private func onSettingChange() {
        syncProfileToManager()
    }

    private func loadCompletedCourses() {
        if let jsonData = completedCoursesData.data(using: .utf8),
           let savedCourses = try? JSONDecoder().decode([String].self, from: jsonData) {
            completedCourses = savedCourses
        }
    }

    private func saveCompletedCourses() {
        if let jsonData = try? JSONEncoder().encode(completedCourses),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            completedCoursesData = jsonString
        }
        onSettingChange()
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Personal Information")) {
                    HStack {
                        Text("First Name").foregroundColor(.secondary)
                        Spacer()
                        Text(firstName).foregroundColor(.primary)
                    }

                    HStack {
                        Text("Last Name").foregroundColor(.secondary)
                        Spacer()
                        Text(lastName).foregroundColor(.primary)
                    }
                }

                Section(header: Text("Academic Information")) {
                    NavigationLink(destination: MajorPickerView(selectedMajor: $major, majorsList: majorsList)) {
                        HStack {
                            Text("Major").foregroundColor(.secondary)
                            Spacer()
                            Text(major.isEmpty ? "Not set" : major)
                                .foregroundColor(major.isEmpty ? .gray : .blue)
                                .lineLimit(1)
                        }
                    }

                    Menu {
                        ForEach(scheduleOptions, id: \.self) { option in
                            Button(action: {
                                scheduleType = option
                                onSettingChange()
                            }) {
                                HStack {
                                    Text(option)
                                    if scheduleType == option { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Schedule").foregroundColor(.secondary)
                            Spacer()
                            Text(scheduleType).foregroundColor(.blue)
                        }
                    }

                    // Start Semester — Fall / Spring only
                    Menu {
                        ForEach(semesters, id: \.self) { semester in
                            Button(action: {
                                startSemester = semester
                                onSettingChange()
                            }) {
                                HStack {
                                    Text(semester)
                                    if startSemester == semester { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Start Semester").foregroundColor(.secondary)
                            Spacer()
                            Text(startSemester).foregroundColor(.blue)
                        }
                    }

                    Menu {
                        ForEach(graduationYears, id: \.self) { year in
                            Button(action: {
                                startYear = year
                                onSettingChange()
                            }) {
                                HStack {
                                    Text(year)
                                    if startYear == year { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Start Year").foregroundColor(.secondary)
                            Spacer()
                            Text(startYear.isEmpty ? "Not set" : startYear)
                                .foregroundColor(startYear.isEmpty ? .gray : .blue)
                        }
                    }

                    // Graduation Semester — Fall / Spring only
                    Menu {
                        ForEach(semesters, id: \.self) { semester in
                            Button(action: {
                                gradSemester = semester
                                onSettingChange()
                            }) {
                                HStack {
                                    Text(semester)
                                    if gradSemester == semester { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Graduation Semester").foregroundColor(.secondary)
                            Spacer()
                            Text(gradSemester).foregroundColor(.blue)
                        }
                    }

                    Menu {
                        ForEach(graduationYears, id: \.self) { year in
                            Button(action: {
                                graduationYear = year
                                onSettingChange()
                            }) {
                                HStack {
                                    Text(year)
                                    if graduationYear == year { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Graduation Year").foregroundColor(.secondary)
                            Spacer()
                            Text(graduationYear.isEmpty ? "Not set" : graduationYear)
                                .foregroundColor(graduationYear.isEmpty ? .gray : .blue)
                        }
                    }
                }

                // MARK: - Summer Classes Toggle
                Section(header: Text("Schedule Preferences")) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(takesSummerClasses ? Color.orange.opacity(0.15) : Color(.systemGray5))
                                .frame(width: 36, height: 36)
                            Text("☀️")
                                .font(.body)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Summer Classes")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Include summer semesters in your plan")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $takesSummerClasses)
                            .labelsHidden()
                            .tint(.orange)
                            .onChange(of: takesSummerClasses) { _, _ in
                                onSettingChange()
                            }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Completed Courses Section
                Section(header: Text("Completed Courses")) {
                    if completedCourses.isEmpty {
                        Text("No completed courses added")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(completedCourses, id: \.self) { course in
                                HStack(spacing: 4) {
                                    Text(course)
                                        .font(.subheadline)
                                    Button(action: {
                                        completedCourses.removeAll { $0 == course }
                                        saveCompletedCourses()
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
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button(action: {
                        showCompletedCoursesSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                            Text("Add Completed Course")
                                .foregroundColor(.blue)
                        }
                    }
                }

                Section(header: Text("Academic Tools")) {
                    Link(destination: URL(string: "https://degreeworks.cuny.edu")!) {
                        HStack {
                            Image(systemName: "square.grid.2x2").foregroundColor(.blue)
                            Text("DegreeWorks")
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Link(destination: URL(string: "https://schedulebuilder.cuny.edu")!) {
                        HStack {
                            Image(systemName: "sparkles").foregroundColor(.blue)
                            Text("ScheduleBuilder")
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Account")) {
                    Button(action: {
                        // Reset all stored values
                        firstName = ""
                        lastName = ""
                        major = ""
                        scheduleType = "Full-time"
                        startSemester = "Fall"
                        startYear = ""
                        gradSemester = "Spring"
                        graduationYear = ""
                        completedCourses = []
                        completedCoursesData = "[]"
                        takesSummerClasses = false  // NEW: reset on sign-out
                        hasLoggedIn = false
                        hasOnboarded = false
                        isLoggedIn = false

                        let emptyProfile = UserProfile(
                            userId: profileManager.currentProfile?.userId ?? UUID().uuidString,
                            firstName: "",
                            lastName: "",
                            major: "",
                            scheduleType: "Full-time",
                            startSemester: "Fall",
                            startYear: "",
                            gradSemester: "Spring",
                            graduationYear: "",
                            completedCourses: [],
                            takesSummerClasses: false  // NEW
                        )
                        profileManager.updateProfile(emptyProfile)

                        activeScreen = .login
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle").foregroundColor(.red)
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("App Version").foregroundColor(.secondary)
                        Spacer()
                        Text("1.0.0").foregroundColor(.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { activeScreen = .chat }) {
                        Image(systemName: "chevron.left")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            loadCompletedCourses()
        }
        .onChange(of: firstName) { _, _ in onSettingChange() }
        .onChange(of: lastName) { _, _ in onSettingChange() }
        .onChange(of: major) { _, _ in onSettingChange() }
        .onChange(of: scheduleType) { _, _ in onSettingChange() }
        .onChange(of: startSemester) { _, _ in onSettingChange() }
        .onChange(of: startYear) { _, _ in onSettingChange() }
        .onChange(of: gradSemester) { _, _ in onSettingChange() }
        .onChange(of: graduationYear) { _, _ in onSettingChange() }
        // takesSummerClasses is handled inline via .onChange inside the Toggle
        .sheet(isPresented: $showCompletedCoursesSheet) {
            AddCourseSheet(completedCourses: $completedCourses, onSave: {
                saveCompletedCourses()
            })
        }
    }
}

// MARK: - Add Course Sheet
struct AddCourseSheet: View {
    @Binding var completedCourses: [String]
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var courseInput = ""

    let commonCourses = ["ACC 122", "ACC 222", "ACC 241", "ACC 250", "ACC 295", "ANI 100", "ANI 200", "ANT 100", "ART 100", "ART 105", "ART 200", "BIO 110", "BIO 210", "BIO 425", "BIO 426", "BUS 104", "BUS 110", "BUS 210", "BUS 311", "CHE 121", "CHE 201", "CHE 202", "CIS 100", "CIS 165", "CIS 272", "CIS 285", "CIS 316", "CIS 317", "CIS 345", "CIS 359", "CIS 362", "CIS 364", "CIS 385", "CIS 395", "COE 100", "COM 100", "COM 110", "CRJ 101", "CRJ 201", "CRJ 202", "CRJ 203", "CRJ 204", "CSC 101", "CSC 103", "CSC 111", "CSC 203", "CSC 211", "CSC 231", "CSC 232", "ECE 110", "ECE 210", "ECO 201", "ECO 202", "EDU 201", "EDU 202", "EDU 210", "ENG 101", "ENG 105", "ENG 201", "ENG 211", "ENG 212", "ETH 100", "FNB 100", "FNB 200", "FRN 100", "GER 100", "GIS 201", "HIS 101", "HIS 102", "HIS 121", "HIS 122", "HIT 100", "HIT 110", "HIT 220", "HIT 230", "HSC 110", "HSC 220", "HUS 101", "HUS 201", "HUS 210", "LIN 100", "MAR 100", "MAT 100", "MAT 104", "MAT 150", "MAT 161.5", "MAT 206", "MAT 301", "MAT 302", "MAT 303", "MAT 314", "MAT 315", "MMP 100", "MMP 200", "MMP 250", "MUS 100", "MUS 110", "NUR 112", "NUR 211", "NUR 313", "NUR 411", "NUR 415", "PHE 100", "PHI 100", "PHI 110", "PHI 200", "PHY 110", "PHY 215", "PHY 225", "PMC 100", "POL 100", "PSY 100", "PSY 200", "PSY 240", "PSY 260", "RES 200", "RES 210", "SOC 100", "SPE 100", "SPE 102", "SPN 100", "SPN 200", "THE 100", "THE 110", "URB 100", "VAT 100", "VAT 200", "WGS 100"
    ]

    var filteredCourses: [String] {
        if courseInput.isEmpty { return [] }
        return commonCourses.filter {
            $0.lowercased().contains(courseInput.lowercased())
        }.prefix(10).map { String($0) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Search for a course...", text: $courseInput)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .autocapitalization(.allCharacters)
                    .padding(.horizontal)

                if !filteredCourses.isEmpty {
                    List(filteredCourses, id: \.self) { course in
                        Button(action: {
                            if !completedCourses.contains(course) {
                                completedCourses.append(course)
                                onSave()
                                dismiss()
                            }
                        }) {
                            HStack {
                                Text(course)
                                Spacer()
                                if completedCourses.contains(course) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    Spacer()
                    Text("Type to search for courses")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Major Picker View
struct MajorPickerView: View {
    @Binding var selectedMajor: String
    let majorsList: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(majorsList, id: \.self) { major in
            Button(action: {
                selectedMajor = major
                dismiss()
            }) {
                HStack {
                    Text(major)
                        .foregroundColor(.primary)
                    Spacer()
                    if major == selectedMajor {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .foregroundColor(.primary)
        }
        .navigationTitle("Select Major")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    SettingsView(activeScreen: .constant(.settings))
}
