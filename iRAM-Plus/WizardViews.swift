//
//  WizardViews.swift
//  iRAM-Plus
//
//  Created by NovaDev404
//

import SwiftUI
import UniformTypeIdentifiers
import StosSign_API_NoCertificate
import StosSign_Auth

// MARK: - Welcome Slide
struct WelcomeSlide: View {
    @ObservedObject var viewModel: WizardViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon
            Image(systemName: "memorychip.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 10) {
                Text("iRAM+")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Enable Increased Memory Limit for your sideloaded apps")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Anisette Server URL")
                    .font(.headline)
                
                TextField("https://ani.sidestore.io", text: $viewModel.anisetteServerURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                
                Text("This server provides device authentication data for Apple Developer API access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            Button(action: {
                DataManager.shared.model.anisetteServerURL = viewModel.anisetteServerURL
                viewModel.nextStep()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.gradient)
                    .cornerRadius(15)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Login Slide
struct LoginSlide: View {
    @ObservedObject var viewModel: WizardViewModel
    @State private var appleID: String = ""
    @State private var password: String = ""
    @State private var showFilePicker = false
    @State private var isLoggingIn = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Sign In")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Sign in with the Apple ID you used to sign your apps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if isLoggingIn {
                // Progress Section
                VStack(spacing: 15) {
                    ProgressView(value: viewModel.loginProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(y: 2)
                    
                    Text(viewModel.loginStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(15)
                .padding(.horizontal)
            } else {
                // Login Options
                VStack(spacing: 20) {
                    // SideStore Import
                    Button(action: {
                        showFilePicker = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Import SideStore Account")
                                    .font(.headline)
                                Text("Import your SideStore account JSON file")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(15)
                    }
                    
                    // Manual Login
                    VStack(spacing: 15) {
                        TextField("Apple ID", text: $appleID)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: {
                            performLogin()
                        }) {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue.gradient)
                                .cornerRadius(15)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(15)
                }
                .padding(.horizontal)
                
                Text("All authentication is done on-device. Your credentials are never sent to third-party services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                handleSideStoreImport(url: url)
            case .failure(let error):
                viewModel.errorMessage = "Failed to import file: \(error.localizedDescription)"
                viewModel.showError = true
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("Try Again", role: .cancel) { }
            Button("Clear Keychain") {
                viewModel.clearKeychain()
                viewModel.errorMessage = "Successfully cleared keychain. Restart the app and try logging in again."
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func performLogin() {
        isLoggingIn = true
        viewModel.loginViewModel.appleID = appleID
        viewModel.loginViewModel.password = password
        
        // Connect progress callback
        viewModel.loginViewModel.progressCallback = { progress, status in
            Task { @MainActor in
                viewModel.updateLoginProgress(progress: progress, status: status)
            }
        }
        
        Task {
            do {
                // Start authentication - this will pause if 2FA is needed
                let result = try await viewModel.loginViewModel.authenticate()
                
                await MainActor.run {
                    isLoggingIn = false
                    if result {
                        // Authentication completed successfully without 2FA
                        viewModel.nextStep()
                    } else {
                        // Authentication paused for 2FA
                        viewModel.goToStep(.twoFactor)
                    }
                }
            } catch {
                await MainActor.run {
                    // Actual error
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                    isLoggingIn = false
                }
            }
        }
    }
    
    private func handleSideStoreImport(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            viewModel.errorMessage = "Could not access the file"
            viewModel.showError = true
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let account = try SideStoreAccountImporter.importAccount(from: data)
            
            viewModel.loginViewModel.appleID = account.email
            viewModel.loginViewModel.password = account.password
            
            // Connect progress callback
            viewModel.loginViewModel.progressCallback = { progress, status in
                Task { @MainActor in
                    viewModel.updateLoginProgress(progress: progress, status: status)
                }
            }
            
            Task {
                do {
                    // Start authentication - this will pause if 2FA is needed
                    let result = try await viewModel.loginViewModel.authenticate()
                    
                    await MainActor.run {
                        if result {
                            // Authentication completed successfully without 2FA
                            viewModel.nextStep()
                        } else {
                            // Authentication paused for 2FA
                            viewModel.goToStep(.twoFactor)
                        }
                    }
                } catch {
                    await MainActor.run {
                        // Actual error
                        viewModel.errorMessage = error.localizedDescription
                        viewModel.showError = true
                    }
                }
            }
        } catch {
            viewModel.errorMessage = "Failed to import account: \(error.localizedDescription)"
            viewModel.showError = true
        }
    }
}

// MARK: - 2FA Slide
struct TwoFactorSlide: View {
    @ObservedObject var viewModel: WizardViewModel
    @State private var twoFactorCode: String = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "lock.shield.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 10) {
                Text("Enter 2FA Code")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Enter the verification code sent to your trusted devices")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            TextField("6-digit code", text: $twoFactorCode)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .padding(.horizontal, 40)
            
            Button(action: {
                submitTwoFactorCode()
            }) {
                Text("Verify")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.gradient)
                    .cornerRadius(15)
            }
            .padding(.horizontal, 40)
            .disabled(twoFactorCode.count != 6)
            
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func submitTwoFactorCode() {
        Task {
            do {
                try await viewModel.loginViewModel.verifyTwoFactorCode(twoFactorCode)
                await MainActor.run {
                    viewModel.nextStep()
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                }
            }
        }
    }
}

// MARK: - Apps List Slide
struct AppsListSlide: View {
    @ObservedObject var viewModel: WizardViewModel
    @StateObject private var appIDViewModel = AppIDViewModel()
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Choose an App")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Select an app to add the Increased Memory Limit entitlement")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else if appIDViewModel.appIDs.isEmpty {
                Text("No apps found")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appIDViewModel.appIDs, id: \.self) { appID in
                            Button(action: {
                                viewModel.selectedApp = appID
                                viewModel.nextStep()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(appID.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(appID.bundleID)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .task {
            do {
                try await appIDViewModel.fetchAppIDs()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                    isLoading = false
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Add Capability Slide
struct AddCapabilitySlide: View {
    @ObservedObject var viewModel: WizardViewModel
    @State private var isAdding = false
    @State private var showServerResponse = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if let app = viewModel.selectedApp {
                VStack(spacing: 10) {
                    Text(app.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text(app.bundleID)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            if isAdding {
                ProgressView("Adding Increased Memory Limit...")
                    .scaleEffect(1.2)
            } else {
                Button(action: {
                    addCapability()
                }) {
                    Text("Add Increased Memory Limit")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 40)
                
                if showServerResponse {
                    ScrollView {
                        Text(viewModel.serverResponse)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                    }
                    .frame(maxHeight: 200)
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func addCapability() {
        guard let app = viewModel.selectedApp else { return }
        
        isAdding = true
        
        Task {
            do {
                try await app.addIncreasedMemory()
                await MainActor.run {
                    viewModel.serverResponse = app.result
                    viewModel.nextStep()
                    isAdding = false
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                    isAdding = false
                }
            }
        }
    }
}

// MARK: - Finish Slide
struct FinishSlide: View {
    @ObservedObject var viewModel: WizardViewModel
    @State private var showServerResponse = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundStyle(.green.gradient)
            
            VStack(spacing: 10) {
                Text("Success!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                
                if let app = viewModel.selectedApp {
                    Text("Successfully added Increased Memory Limit to \(app.name)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Next Steps:")
                    .font(.headline)
                
                HStack(alignment: .top, spacing: 10) {
                    Text("1.")
                        .foregroundStyle(.blue)
                        .fontWeight(.bold)
                    Text("Reinstall the app from SideStore/AltStore (IMPORTANT)")
                        .foregroundStyle(.primary)
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Text("2.")
                        .foregroundStyle(.blue)
                        .fontWeight(.bold)
                    Text("The app should now have increased memory available")
                        .foregroundStyle(.primary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(15)
            .padding(.horizontal)
            
            Button(action: {
                showServerResponse.toggle()
            }) {
                Text(showServerResponse ? "Hide Server Response" : "Show Server Response")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            
            if showServerResponse {
                ScrollView {
                    Text(viewModel.serverResponse)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                }
                .frame(maxHeight: 150)
                .padding(.horizontal)
            }
            
            Spacer()
            
            HStack(spacing: 15) {
                Button(action: {
                    viewModel.goToStep(.apps)
                }) {
                    Text("Add to Another App")
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(15)
                }
                
                Button(action: {
                    viewModel.reset()
                }) {
                    Text("Finish")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient)
                        .cornerRadius(15)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Main Wizard View
struct WizardView: View {
    @StateObject private var viewModel = WizardViewModel()
    
    var body: some View {
        TabView(selection: $viewModel.currentStep) {
            WelcomeSlide(viewModel: viewModel)
                .tag(WizardStep.welcome)
            
            LoginSlide(viewModel: viewModel)
                .tag(WizardStep.login)
            
            TwoFactorSlide(viewModel: viewModel)
                .tag(WizardStep.twoFactor)
            
            AppsListSlide(viewModel: viewModel)
                .tag(WizardStep.apps)
            
            AddCapabilitySlide(viewModel: viewModel)
                .tag(WizardStep.addCapability)
            
            FinishSlide(viewModel: viewModel)
                .tag(WizardStep.finish)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .environmentObject(DataManager.shared.model)
    }
}
