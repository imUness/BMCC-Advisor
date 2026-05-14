//
//  UserProfileManager.swift
//  BMCC_Advisor
//
//  Created by Youness El Akri on 5/7/26.
//

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
        } else {
            // Create from UserDefaults (onboarding data)
            let profile = UserProfile(
                userId: UUID().uuidString,
                firstName: UserDefaults.standard.string(forKey: "firstName") ?? "",
                lastName: UserDefaults.standard.string(forKey: "lastName") ?? "",
                major: UserDefaults.standard.string(forKey: "major") ?? "",
                scheduleType: UserDefaults.standard.string(forKey: "scheduleType") ?? "Full-time",
                startSemester: UserDefaults.standard.string(forKey: "startSemester") ?? "Fall",
                startYear: UserDefaults.standard.string(forKey: "startYear") ?? "",
                graduationYear: UserDefaults.standard.string(forKey: "graduationYear") ?? ""
            )
            currentProfile = profile
            storage.saveUserProfile(profile)
        }
    }
    
    func updateProfile(_ profile: UserProfile) {
        currentProfile = profile
        storage.saveUserProfile(profile)
        
        // Sync with UserDefaults for backwards compatibility
        UserDefaults.standard.set(profile.firstName, forKey: "firstName")
        UserDefaults.standard.set(profile.lastName, forKey: "lastName")
        UserDefaults.standard.set(profile.major, forKey: "major")
        UserDefaults.standard.set(profile.scheduleType, forKey: "scheduleType")
        UserDefaults.standard.set(profile.startSemester, forKey: "startSemester")
        UserDefaults.standard.set(profile.startYear, forKey: "startYear")
        UserDefaults.standard.set(profile.graduationYear, forKey: "graduationYear")
    }
}
