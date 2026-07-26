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
    
    func submitVerificationCode() {
        guard !isVerificationCodeSubmitting,
              let verificationCodeHandler else { return }

        isVerificationCodeSubmitting = true
        verificationCodeHandler(verificationCode)
        self.verificationCodeHandler = nil
    }

    func cancelAuthentication() {
        guard isLoginInProgress else { return }

        isAuthenticationCancellationRequested = true

        let verificationCodeHandler = verificationCodeHandler
        self.verificationCodeHandler = nil
        needVerificationCode = false
        verificationCode = ""
        isVerificationCodeSubmitting = false

        verificationCodeHandler?(nil)
    }
    
    func authenticate() async throws -> Bool {
        if isLoginInProgress {
            return false
        }
        
        logs = ""
        isLoginInProgress = true
        isAuthenticationCancellationRequested = false
        
        progressCallback?(0.0, "Starting...")
        
        func logging(text: String) {
            Task { @MainActor [weak self] in
                self?.logs.append("\(text)\n")
            }
        }
        
        AnisetteDataHelper.shared.loggingFunc = logging

        do {
            progressCallback?(0.1, "Trying to get client info")
            let anisetteData = try await AnisetteDataHelper.shared.getAnisetteData()
            progressCallback?(0.3, "Client info received")

            progressCallback?(0.4, "Authenticating with Apple")
            logging(text: "Starting Apple authentication")
            
            let (account, session) = try await AppleAPI.shared.authenticate(appleID: appleID, password: password, anisetteData: anisetteData) { [weak self] completionHandler in
                guard let self else {
                    completionHandler(nil)
                    return
                }

                logging(text: "AppleAPI requested 2FA code")
                self.prepareForVerification(using: completionHandler)
            }
            
            progressCallback?(0.65, "Authentication successful")
            logging(text: "Apple authentication completed successfully")

            guard !isAuthenticationCancellationRequested else {
                cleanup()
                throw CancellationError()
            }

            logging(text: "Successfully signed in")
            progressCallback?(0.8, "Successfully signed in")

            DataManager.shared.model.account = account
            DataManager.shared.model.session = session
            Keychain.shared.appleIDEmailAddress = appleID
            Keychain.shared.appleIDPassword = password

            let teams = try await fetchTeams(for: account, session: session)
            logging(text: "Successfully fetched teams")
            availableTeams = teams
            progressCallback?(1.0, "Successfully fetched teams")

            cleanup()
            return true
        } catch {
            logging(text: "Authentication error: \(error.localizedDescription)")
            
            // If 2FA is needed, don't cleanup - keep the handler for later use
            if needVerificationCode {
                logging(text: "Authentication paused for 2FA")
                isLoginInProgress = false
                return false
            }
            
            cleanup()
            
            if isAuthenticationCancellationRequested {
                throw CancellationError()
            }
            throw error
        }
    }
    
    private func cleanup() {
        verificationCodeHandler = nil
        appleID = ""
        password = ""
        needVerificationCode = false
        verificationCode = ""
        isLoginInProgress = false
        isVerificationCodeSubmitting = false
        isAuthenticationCancellationRequested = false
    }

    private func prepareForVerification(using handler: @escaping (String?) -> Void) {
        guard !isAuthenticationCancellationRequested else {
            handler(nil)
            return
        }

        verificationCodeHandler = handler
        verificationCode = ""
        needVerificationCode = true
        isVerificationCodeSubmitting = false
        
        // Log when 2FA is requested
        logging(text: "2FA code requested by Apple")
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
        try await authenticate()
    }
    
    func verifyTwoFactorCode(_ code: String) async throws {
        verificationCode = code
        submitVerificationCode()
    }
}
