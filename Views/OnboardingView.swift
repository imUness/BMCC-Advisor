import SwiftUI

struct OnboardingView: View {
    
    @Binding var activeScreen: ActiveScreen
    
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("firstName") var firstName = ""
    @AppStorage("lastName") var lastName = ""
    @AppStorage("major") var major = ""
    @AppStorage("scheduleType") var scheduleType = "Full-time"
    @AppStorage("startSemester") var startSemester = "Fall"
    @AppStorage("startYear") var startYear = ""
    @AppStorage("graduationYear") var graduationYear = ""

    @State private var startYearInput = ""
    @State private var graduationYearInput = ""
    @State private var majorInput = ""
    @State private var showSuggestions = false

    let majors = [
        "Computer Science",
        "Business Administration",
        "Mathematics",
        "Biology",
        "Psychology",
        "Nursing",
        "Engineering Science"
    ]

    let scheduleOptions = ["Full-time", "Part-time"]
    let semesters = ["Fall", "Spring", "Summer"]

    // MARK: - Autocomplete Logic

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
        ScrollView {
            VStack(spacing: 20) {

                Spacer()

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

                TextField("Last Name", text: $lastName)
                    .textInputAutocapitalization(.words)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                // MARK: - Major (Autocomplete)
                VStack(alignment: .leading, spacing: 5) {

                    ZStack(alignment: .leading) {

                        // Inline suggestion
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
                            .onChange(of: majorInput) { _, newValue in
                                showSuggestions = !newValue.isEmpty
                            }
                    }

                    // Dropdown suggestions
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

                // Schedule
                Picker("Schedule", selection: $scheduleType) {
                    ForEach(scheduleOptions, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.segmented)

                // Semester
                Picker("Start Semester", selection: $startSemester) {
                    ForEach(semesters, id: \.self) { sem in
                        Text(sem)
                    }
                }
                .pickerStyle(.segmented)

                // Years
                TextField("Start Year (e.g. 2024)", text: $startYearInput)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                TextField("Graduation Year (e.g. 2027)", text: $graduationYearInput)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                // Continue
                Button("Continue") {
                    major = majorInput
                    startYear = startYearInput
                    graduationYear = graduationYearInput
                    hasOnboarded = true
                    activeScreen = .chat
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                Spacer()
            }
            .padding()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onTapGesture {
            hideKeyboard()
        }
        .onAppear {
            majorInput = major
            startYearInput = startYear
            graduationYearInput = graduationYear
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
