//
//  LoginViewModel.swift
//  GetMoreRam
//
//  Created by s s on 2025/3/15.
//
import SwiftUI
import StosSign_API_NoCertificate
import StosSign_Auth

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
    
    func submitVerificationCode() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard !self.isVerificationCodeSubmitting,
                  let verificationCodeHandler = self.verificationCodeHandler else { return }

            self.verificationCodeHandler = nil
            self.isVerificationCodeSubmitting = true
            verificationCodeHandler(self.verificationCode)
        }
    }

    func cancelAuthentication() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard self.isLoginInProgress else { return }

            self.isAuthenticationCancellationRequested = true

            let verificationCodeHandler = self.verificationCodeHandler
            self.verificationCodeHandler = nil
            self.needVerificationCode = false
            self.verificationCode = ""
            self.isVerificationCodeSubmitting = false

            verificationCodeHandler?(nil)
        }
    }
    
    func authenticate() async throws -> Bool {
        let shouldReturn = await MainActor.run {
            if isLoginInProgress {
                return true
            }
            return false
        }
        
        if shouldReturn {
            return false
        }

        await MainActor.run {
            logs = ""
            isLoginInProgress = true
            isAuthenticationCancellationRequested = false
        }

        await MainActor.run {
            progressCallback?(0.0, "Starting...")
        }

        func logging(text: String) {
            Task { @MainActor [weak self] in
                self?.logs.append("\(text)\n")
            }
        }

        AnisetteDataHelper.shared.loggingFunc = logging

        defer {
            // Only cleanup if we're not waiting for 2FA
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.needVerificationCode {
                    self.verificationCodeHandler = nil
                    self.appleID = ""
                    self.password = ""
                    self.verificationCode = ""
                    self.isLoginInProgress = false
                    self.isVerificationCodeSubmitting = false
                    self.isAuthenticationCancellationRequested = false
                }
            }
        }

        do {
            await MainActor.run {
                progressCallback?(0.1, "Trying to get client info")
            }
            let anisetteData = try await AnisetteDataHelper.shared.getAnisetteData()
            await MainActor.run {
                progressCallback?(0.3, "Client info received")
            }

            await MainActor.run {
                progressCallback?(0.4, "Authenticating with Apple")
            }
            let (account, session) = try await AppleAPI.shared.authenticate(appleID: appleID, password: password, anisetteData: anisetteData) { [weak self] completionHandler in
                guard let self else {
                    completionHandler(nil)
                    return
                }

                self.prepareForVerification(using: completionHandler)
            }

            await MainActor.run {
                progressCallback?(0.65, "Authentication successful")
            }

            await MainActor.run {
                guard !isAuthenticationCancellationRequested else {
                    return
                }
            }

            if await MainActor.run { isAuthenticationCancellationRequested } {
                throw CancellationError()
            }

            logging(text: "Successfully signed in")
            await MainActor.run {
                progressCallback?(0.8, "Successfully signed in")
            }

            await MainActor.run {
                DataManager.shared.model.account = account
                DataManager.shared.model.session = session
                Keychain.shared.appleIDEmailAddress = appleID
                Keychain.shared.appleIDPassword = password
            }

            let teams = try await fetchTeams(for: account, session: session)
            logging(text: "Successfully fetched teams")
            await MainActor.run {
                availableTeams = teams
                progressCallback?(1.0, "Successfully fetched teams")
            }
            
            // Auto-select the first team for wizard flow
            await MainActor.run {
                if let firstTeam = teams.first {
                    DataManager.shared.model.team = firstTeam
                }
            }

            return true
        } catch {
            if await MainActor.run { isAuthenticationCancellationRequested } {
                throw CancellationError()
            }
            throw error
        }
    }

    private func prepareForVerification(using handler: @escaping (String?) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else {
                handler(nil)
                return
            }
            
            guard !self.isAuthenticationCancellationRequested else {
                handler(nil)
                return
            }

            self.verificationCodeHandler = handler
            self.verificationCode = ""
            self.needVerificationCode = true
            self.isVerificationCodeSubmitting = false
        }
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
        await MainActor.run {
            verificationCode = code
        }
        submitVerificationCode()
        
        // Wait for authentication to complete
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Check if authentication succeeded
        if await MainActor.run { DataManager.shared.model.session == nil } {
            throw "Failed to verify 2FA code"
        }
        
        // Cleanup after successful 2FA
        await MainActor.run {
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
}
