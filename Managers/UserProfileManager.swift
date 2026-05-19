import Foundation
import Combine

class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    @Published var currentProfile: UserProfile?
    private let storage = ChatStorageManager.shared
    
    init() {
        loadProfile()
    }
    
    func loadProfile() {
        if let saved = storage.loadUserProfile() {
            currentProfile = saved
            print("📱 Loaded from storage - Start Year: '\(saved.startYear)', Graduation: '\(saved.graduationYear)', Completed Courses: \(saved.completedCourses.count)")
        } else {
            createProfileFromUserDefaults()
        }
    }
    
    private func createProfileFromUserDefaults() {
        let startYearValue = UserDefaults.standard.string(forKey: "startYear") ?? ""
        let graduationYearValue = UserDefaults.standard.string(forKey: "graduationYear") ?? ""
        let gradSemesterValue = UserDefaults.standard.string(forKey: "gradSemester") ?? "Spring"
        
        // Load completed courses from UserDefaults
        var completedCourses: [String] = []
        if let coursesData = UserDefaults.standard.data(forKey: "completedCourses"),
           let decoded = try? JSONDecoder().decode([String].self, from: coursesData) {
            completedCourses = decoded
        }
        
        print("📱 Creating from UserDefaults - startYear: '\(startYearValue)', gradSemester: '\(gradSemesterValue)'")
        
        let profile = UserProfile(
            userId: UUID().uuidString,
            firstName: UserDefaults.standard.string(forKey: "firstName") ?? "",
            lastName: UserDefaults.standard.string(forKey: "lastName") ?? "",
            major: UserDefaults.standard.string(forKey: "major") ?? "",
            scheduleType: UserDefaults.standard.string(forKey: "scheduleType") ?? "Full-time",
            startSemester: UserDefaults.standard.string(forKey: "startSemester") ?? "Fall",
            startYear: startYearValue.isEmpty ? "2025" : startYearValue,
            gradSemester: gradSemesterValue,
            graduationYear: graduationYearValue.isEmpty ? "2027" : graduationYearValue,
            completedCourses: completedCourses
        )
        currentProfile = profile
        storage.saveUserProfile(profile)
    }
    
    func updateProfile(_ profile: UserProfile) {
        print("📱 UPDATE PROFILE - Start Year: '\(profile.startYear)', Graduation: '\(profile.graduationYear)', Completed Courses: \(profile.completedCourses.count)")
        
        // Make sure we have valid values
        var updatedProfile = profile
        if updatedProfile.startYear.isEmpty {
            updatedProfile.startYear = "2025"
        }
        if updatedProfile.graduationYear.isEmpty {
            updatedProfile.graduationYear = "2027"
        }
        if updatedProfile.gradSemester.isEmpty {
            updatedProfile.gradSemester = "Spring"
        }
        
        // Force save to storage (overwrites the old file)
        storage.saveUserProfile(updatedProfile)
        
        // Update the current profile
        DispatchQueue.main.async {
            self.currentProfile = updatedProfile
            
            // Update UserDefaults to match
            UserDefaults.standard.set(updatedProfile.firstName, forKey: "firstName")
            UserDefaults.standard.set(updatedProfile.lastName, forKey: "lastName")
            UserDefaults.standard.set(updatedProfile.major, forKey: "major")
            UserDefaults.standard.set(updatedProfile.scheduleType, forKey: "scheduleType")
            UserDefaults.standard.set(updatedProfile.startSemester, forKey: "startSemester")
            UserDefaults.standard.set(updatedProfile.startYear, forKey: "startYear")
            UserDefaults.standard.set(updatedProfile.gradSemester, forKey: "gradSemester")
            UserDefaults.standard.set(updatedProfile.graduationYear, forKey: "graduationYear")
            
            // Save completed courses as JSON
            if let coursesData = try? JSONEncoder().encode(updatedProfile.completedCourses) {
                UserDefaults.standard.set(coursesData, forKey: "completedCourses")
            }
            
            UserDefaults.standard.synchronize()
            
            // Verify the save
            let savedStartYear = UserDefaults.standard.string(forKey: "startYear") ?? "nil"
            print("📱 VERIFIED - UserDefaults startYear: '\(savedStartYear)'")
            
            self.objectWillChange.send()
        }
    }
    
    // Force refresh from UserDefaults (call this when app returns from background or settings change)
    func refreshFromUserDefaults() {
        let freshStartYear = UserDefaults.standard.string(forKey: "startYear") ?? ""
        let freshGraduationYear = UserDefaults.standard.string(forKey: "graduationYear") ?? ""
        let freshGradSemester = UserDefaults.standard.string(forKey: "gradSemester") ?? "Spring"
        
        // Load completed courses from UserDefaults
        var freshCompletedCourses: [String] = []
        if let coursesData = UserDefaults.standard.data(forKey: "completedCourses"),
           let decoded = try? JSONDecoder().decode([String].self, from: coursesData) {
            freshCompletedCourses = decoded
        }
        
        print("🔄 REFRESHING - startYear from UserDefaults: '\(freshStartYear)'")
        
        if let current = currentProfile {
            let updatedProfile = UserProfile(
                userId: current.userId,
                firstName: UserDefaults.standard.string(forKey: "firstName") ?? current.firstName,
                lastName: UserDefaults.standard.string(forKey: "lastName") ?? current.lastName,
                major: UserDefaults.standard.string(forKey: "major") ?? current.major,
                scheduleType: UserDefaults.standard.string(forKey: "scheduleType") ?? current.scheduleType,
                startSemester: UserDefaults.standard.string(forKey: "startSemester") ?? current.startSemester,
                startYear: freshStartYear.isEmpty ? current.startYear : freshStartYear,
                gradSemester: freshGradSemester,
                graduationYear: freshGraduationYear.isEmpty ? current.graduationYear : freshGraduationYear,
                completedCourses: freshCompletedCourses
            )
            currentProfile = updatedProfile
            storage.saveUserProfile(updatedProfile)
        }
    }
}
