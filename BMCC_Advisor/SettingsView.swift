import SwiftUI

struct SettingsView: View {
    @Binding var activeScreen: ActiveScreen
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("hasLoggedIn") var hasLoggedIn: Bool = false
    
    // User Profile Settings
    @AppStorage("firstName") var firstName = ""
    @AppStorage("lastName") var lastName = ""
    @AppStorage("major") var major = ""
    @AppStorage("scheduleType") var scheduleType = "Full-time"
    @AppStorage("startSemester") var startSemester = "Fall"
    @AppStorage("startYear") var startYear = ""
    @AppStorage("graduationYear") var graduationYear = ""
    
    @AppStorage("aiTone") private var aiTone: String = "Balanced"
    @AppStorage("saveChatHistory") private var saveChatHistory: Bool = true
    @AppStorage("notifications") private var notifications: Bool = true
    
    let scheduleOptions = ["Full-time", "Part-time"]
    let semesters = ["Fall", "Spring", "Summer"]
    let graduationYears = Array(2025...2035).map { String($0) }
    
    let majorsList = [
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
        "Engineering Science (A.S.)",
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
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Personal Information")) {
                    HStack {
                        Text("First Name").foregroundColor(.secondary)
                        Spacer()
                        Text(firstName).foregroundColor(.primary)
                        + Text(" ").foregroundColor(.primary)
                        + Text(lastName).foregroundColor(.primary)
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
                            Button(action: { scheduleType = option }) {
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
                    
                    Menu {
                        ForEach(semesters, id: \.self) { semester in
                            Button(action: { startSemester = semester }) {
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
                            Button(action: { startYear = year }) {
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
                    
                    Menu {
                        ForEach(graduationYears, id: \.self) { year in
                            Button(action: { graduationYear = year }) {
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
                        firstName = ""; lastName = ""; major = ""
                        scheduleType = "Full-time"; startSemester = "Fall"
                        startYear = ""; graduationYear = ""
                        hasLoggedIn = false; hasOnboarded = false
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
                    Text(major).foregroundColor(.primary)
                    Spacer()
                    if major == selectedMajor {
                        Image(systemName: "checkmark").foregroundColor(.blue)
                    }
                }
            }
            .foregroundColor(.primary)
        }
        .navigationTitle("Select Major")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    SettingsView(activeScreen: .constant(.settings))
}
