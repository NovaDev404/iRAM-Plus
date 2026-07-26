//
//  LoginViewModel.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import StosSign_API_NoCertificate
import StosSign_Auth

@MainActor
class LoginViewModel: ObservableObject {
    @Published var appleID = ""
    @Published var password = ""
    @Published var needVerificationCode = false
    @Published var verificationCode = ""
    @Published var loginModalShow = false
    @Published var teamSelectionShow = false
    @Published var isLoginInProgress = false
    @Published private(set) var isVerificationCodeSubmitting = false
    @Published var logs = ""
    @Published var availableTeams: [Team] = []
    
    var progressCallback: ((Double, String) -> Void)?
    
    private var verificationCodeHandler: ((String?) -> Void)?
    private var isAuthenticationCancellationRequested = false
    
    private func logToFile(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        if let fileURL = getDebugFileURL() {
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(logMessage.data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                // File doesn't exist yet, create it
                try? logMessage.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func getDebugFileURL() -> URL? {
        let fileManager = FileManager.default
        if let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsDirectory.appendingPathComponent("debug.txt")
        }
        return nil
    }
    
    private func clearDebugLog() {
        if let fileURL = getDebugFileURL() {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    func submitVerificationCode() {
        logToFile("submitVerificationCode() called with code: '\(verificationCode)'")
        guard !isVerificationCodeSubmitting,
              let verificationCodeHandler else {
            logToFile("submitVerificationCode: guard failed - isSubmitting: \(isVerificationCodeSubmitting), handler exists: \(verificationCodeHandler != nil)")
            return
        }

        logToFile("submitVerificationCode: clearing handler and calling it with code")
        self.verificationCodeHandler = nil
        isVerificationCodeSubmitting = true
        verificationCodeHandler(verificationCode)
    }

    func cancelAuthentication() {
        logToFile("cancelAuthentication() called")
        guard isLoginInProgress else { 
            logToFile("cancelAuthentication: login not in progress, returning")
            return
        }

        isAuthenticationCancellationRequested = true

        let verificationCodeHandler = verificationCodeHandler
        self.verificationCodeHandler = nil
        needVerificationCode = false
        verificationCode = ""
        isVerificationCodeSubmitting = false

        logToFile("cancelAuthentication: calling handler(nil)")
        verificationCodeHandler?(nil)
    }
    
    func authenticate() async throws -> Bool {
        if isLoginInProgress {
            logToFile("authenticate() called but login already in progress")
            return false
        }

        logToFile("authenticate() called for appleID: \(appleID)")
        logs = ""
        isLoginInProgress = true
        isAuthenticationCancellationRequested = false

        progressCallback?(0.0, "Starting...")

        func logging(text: String) {
            Task { @MainActor [weak self] in
                self?.logs.append("\(text)\n")
                self?.logToFile(text)
            }
        }

        AnisetteDataHelper.shared.loggingFunc = logging

        defer {
            // Only cleanup if we're not waiting for 2FA
            if !needVerificationCode {
                logToFile("authenticate() defer: cleaning up (2FA not needed)")
                verificationCodeHandler = nil
                appleID = ""
                password = ""
                verificationCode = ""
                isLoginInProgress = false
                isVerificationCodeSubmitting = false
                isAuthenticationCancellationRequested = false
            } else {
                logToFile("authenticate() defer: NOT cleaning up (2FA needed, handler preserved)")
            }
        }

        do {
            progressCallback?(0.1, "Trying to get client info")
            logToFile("Fetching anisette data...")
            let anisetteData = try await AnisetteDataHelper.shared.getAnisetteData()
            progressCallback?(0.3, "Client info received")
            logToFile("Anisette data received successfully")

            progressCallback?(0.4, "Authenticating with Apple")
            logToFile("Calling AppleAPI.authenticate...")
            let (account, session) = try await AppleAPI.shared.authenticate(appleID: appleID, password: password, anisetteData: anisetteData) { [weak self] completionHandler in
                guard let self else {
                    self?.logToFile("2FA handler: self is nil, calling completionHandler(nil)")
                    completionHandler(nil)
                    return
                }

                self.logToFile("2FA handler: AppleAPI requested 2FA code, calling prepareForVerification")
                self.prepareForVerification(using: completionHandler)
            }

            progressCallback?(0.65, "Authentication successful")
            logToFile("AppleAPI.authenticate completed successfully")

            guard !isAuthenticationCancellationRequested else {
                logToFile("Authentication cancelled by user")
                throw CancellationError()
            }

            logging(text: "Successfully signed in")
            progressCallback?(0.8, "Successfully signed in")

            DataManager.shared.model.account = account
            DataManager.shared.model.session = session
            Keychain.shared.appleIDEmailAddress = appleID
            Keychain.shared.appleIDPassword = password
            logToFile("Saved account and session to DataManager and Keychain")

            let teams = try await fetchTeams(for: account, session: session)
            logging(text: "Successfully fetched teams")
            availableTeams = teams
            progressCallback?(1.0, "Successfully fetched teams")
            logToFile("Fetched \(teams.count) teams")
            
            // Auto-select the first team for wizard flow
            if let firstTeam = teams.first {
                DataManager.shared.model.team = firstTeam
                logToFile("Auto-selected team: \(firstTeam.name)")
            }

            return true
        } catch {
            logToFile("authenticate() error: \(error.localizedDescription)")
            if isAuthenticationCancellationRequested {
                throw CancellationError()
            }
            throw error
        }
    }

    private func prepareForVerification(using handler: @escaping (String?) -> Void) {
        logToFile("prepareForVerification() called")
        guard !isAuthenticationCancellationRequested else {
            logToFile("prepareForVerification: authentication cancelled, calling handler(nil)")
            handler(nil)
            return
        }

        verificationCodeHandler = handler
        verificationCode = ""
        needVerificationCode = true
        isVerificationCodeSubmitting = false
        logToFile("prepareForVerification: set needVerificationCode=true, handler stored")
    }
    
    func fetchTeams(for account: Account, session: AppleAPISession) async throws -> [Team]
    {

        let fetchedTeams = try await AppleAPI.shared.fetchTeamsForAccount(account: account, session: session)
        guard !fetchedTeams.isEmpty else {
            throw "Unable to Fetch Team!"
        }

        return fetchedTeams
    }
    
    func login() async throws {
        _ = try await authenticate()
    }
    
    func verifyTwoFactorCode(_ code: String) async throws {
        logToFile("verifyTwoFactorCode() called with code: '\(code)'")
        verificationCode = code
        submitVerificationCode()
        
        // Wait for authentication to complete
        logToFile("verifyTwoFactorCode: waiting 3 seconds for authentication to complete...")
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Check if authentication succeeded
        let session = DataManager.shared.model.session
        logToFile("verifyTwoFactorCode: checking session - session is nil: \(session == nil)")
        if DataManager.shared.model.session == nil {
            logToFile("verifyTwoFactorCode: authentication FAILED - session is nil")
            throw "Failed to verify 2FA code"
        }
        
        logToFile("verifyTwoFactorCode: authentication SUCCESS - cleaning up")
        // Cleanup after successful 2FA
        verificationCodeHandler = nil
        appleID = ""
        password = ""
        needVerificationCode = false
        verificationCode = ""
        isLoginInProgress = false
        isVerificationCodeSubmitting = false
        isAuthenticationCancellationRequested = false
    }
}
