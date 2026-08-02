//
//  WizardViewModel.swift
//  iRAM-Plus
//
//  Created by NovaDev404
//

import SwiftUI
import Combine

struct AnisetteServer: Codable, Identifiable, Equatable {
    let id = UUID()
    let name: String
    let address: String
    
    enum CodingKeys: String, CodingKey {
        case name, address
    }
    
    static let custom = AnisetteServer(name: "Custom", address: "")
}

struct AnisetteServerList: Codable {
    let servers: [AnisetteServer]
    let cache: String
}

enum WizardStep: Int, CaseIterable {
    case welcome = 0
    case login = 1
    case apps = 2
    case addCapability = 3
    case finish = 4
    case settings = 5
}

@MainActor
class WizardViewModel: ObservableObject {
    @Published var currentStep: WizardStep = .welcome
    @Published var anisetteServerURL: String = "https://ani.sidestore.io"
    @Published var loginProgress: Double = 0.0
    @Published var loginStatus: String = ""
    @Published var selectedApp: AppIDModel?
    @Published var serverResponse: String = ""
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var saveLoginToKeychain = UserDefaults.standard.bool(forKey: "saveLoginToKeychain") {
        didSet {
            UserDefaults.standard.set(saveLoginToKeychain, forKey: "saveLoginToKeychain")
        }
    }
    @Published var anisetteServers: [AnisetteServer] = []
    @Published var selectedAnisetteServer: AnisetteServer = AnisetteServer.custom {
        didSet {
            if selectedAnisetteServer != AnisetteServer.custom {
                anisetteServerURL = selectedAnisetteServer.address
                UserDefaults.standard.set(selectedAnisetteServer.name, forKey: "selectedAnisetteServerName")
                UserDefaults.standard.set(selectedAnisetteServer.address, forKey: "selectedAnisetteServerAddress")
            }
        }
    }
    @Published var customAnisetteURL: String = "" {
        didSet {
            if selectedAnisetteServer == AnisetteServer.custom {
                anisetteServerURL = customAnisetteURL
                UserDefaults.standard.set(customAnisetteURL, forKey: "customAnisetteURL")
            }
        }
    }
    
    let loginViewModel = LoginViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    func nextStep() {
        if let nextStep = WizardStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
    }
    
    func goToStep(_ step: WizardStep) {
        currentStep = step
    }
    
    
    func reset() {
        currentStep = .welcome
        loginProgress = 0.0
        loginStatus = ""
        selectedApp = nil
        serverResponse = ""
        errorMessage = ""
        showError = false
    }
    
    func updateLoginProgress(progress: Double, status: String) {
        withAnimation(.easeInOut(duration: 0.5)) {
            loginProgress = progress
            loginStatus = status
        }
    }
    
    func clearKeychain() {
        let sharedModel = DataManager.shared.model
        Keychain.shared.adiPb = nil
        Keychain.shared.identifier = nil
        Keychain.shared.appleIDPassword = nil
        Keychain.shared.appleIDEmailAddress = nil
        AnisetteDataHelper.shared.resetClientInfo()
        sharedModel.session = nil
        sharedModel.account = nil
        sharedModel.team = nil
        sharedModel.isLogin = false
        loginViewModel.availableTeams = []
        loginViewModel.teamSelectionShow = false
    }
    
    func resetLoginState() {
        loginViewModel.appleID = ""
        loginViewModel.password = ""
        loginViewModel.needVerificationCode = false
        loginViewModel.verificationCode = ""
        loginViewModel.isLoginInProgress = false
        loginViewModel.resetVerificationCodeState()
        loginViewModel.logs = ""
        loginProgress = 0.0
        loginStatus = ""
        errorMessage = ""
        showError = false
    }
    
    func fetchAnisetteServers() async {
        guard let url = URL(string: "https://servers.sidestore.io/servers.json") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let serverList = try JSONDecoder().decode(AnisetteServerList.self, from: data)
            await MainActor.run {
                anisetteServers = serverList.servers
                // Restore saved selection
                if let savedName = UserDefaults.standard.string(forKey: "selectedAnisetteServerName"),
                   let savedAddress = UserDefaults.standard.string(forKey: "selectedAnisetteServerAddress") {
                    if let savedServer = anisetteServers.first(where: { $0.name == savedName && $0.address == savedAddress }) {
                        selectedAnisetteServer = savedServer
                        anisetteServerURL = savedAddress
                    }
                }
            }
        } catch {
            print("Failed to fetch anisette servers: \(error)")
        }
    }
    
    init() {
        // Load custom URL if saved
        customAnisetteURL = UserDefaults.standard.string(forKey: "customAnisetteURL") ?? ""
        
        loginViewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

}
