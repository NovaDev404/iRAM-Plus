//
//  WizardViewModel.swift
//  iRAM-Plus
//
//  Created by NovaDev404
//

import SwiftUI

enum WizardStep: Int, CaseIterable {
    case welcome = 0
    case login = 1
    case apps = 2
    case addCapability = 3
    case finish = 4
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
    
    let loginViewModel = LoginViewModel()
    
    private var completedSteps: Set<WizardStep> = []
    
    func nextStep() {
        // Mark current step as completed before moving to next
        completedSteps.insert(currentStep)
        if let nextStep = WizardStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
    }
    
    func goToStep(_ step: WizardStep) {
        // Mark all steps after the target as incomplete when navigating backward
        if step.rawValue < currentStep.rawValue {
            for i in (step.rawValue + 1)...currentStep.rawValue {
                if let wizardStep = WizardStep(rawValue: i) {
                    completedSteps.remove(wizardStep)
                }
            }
        }
        currentStep = step
    }
    
    func canNavigateToStep(_ step: WizardStep) -> Bool {
        // Allow staying on current step
        if step == currentStep {
            return true
        }
        // Only allow backward navigation, never forward
        return step.rawValue < currentStep.rawValue
    }
    
    func reset() {
        currentStep = .welcome
        loginProgress = 0.0
        loginStatus = ""
        selectedApp = nil
        serverResponse = ""
        errorMessage = ""
        showError = false
        completedSteps = []
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
}
