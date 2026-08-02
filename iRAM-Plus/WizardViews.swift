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
import Combine

// MARK: - Keyboard Avoidance Modifier
struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                withAnimation {
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        // Use a smaller portion of keyboard height to avoid excessive movement
                        keyboardHeight = keyboardFrame.height * 0.2
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation {
                    keyboardHeight = 0
                }
            }
        .padding(.bottom, keyboardHeight)
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        self.modifier(KeyboardAdaptive())
    }
}

// MARK: - Welcome Slide
struct WelcomeSlide: View {
    @ObservedObject var viewModel: WizardViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Spacer()
                Button(action: {
                    viewModel.goToStep(.settings)
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
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
            
            Button(action: {
                DataManager.shared.model.anisetteServerURL = viewModel.anisetteServerURL
                viewModel.resetLoginState()
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
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .keyboardAdaptive()
    }
}

// MARK: - Settings Slide
struct SettingsSlide: View {
    @ObservedObject var viewModel: WizardViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: {
                    viewModel.goToStep(.welcome)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                }
                Spacer()
            }
            .padding(.horizontal)
            
            Spacer()
            
            Text("Settings")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Anisette Server")
                    .font(.headline)
                
                if viewModel.anisetteServers.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Picker(selection: $viewModel.selectedAnisetteServer) {
                        ForEach(viewModel.anisetteServers) { server in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.name)
                                    .font(.body)
                                Text(server.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(server)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom")
                                .font(.body)
                            Text("Enter custom URL")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(AnisetteServer.custom)
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if viewModel.selectedAnisetteServer == AnisetteServer.custom {
                    TextField("https://example.com", text: $viewModel.customAnisetteURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                
                Text("This server provides device authentication data for Apple Developer API access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(15)
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("Save login to keychain")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $viewModel.saveLoginToKeychain)
                        .labelsHidden()
                }
                
                Text("Automatically save your Apple ID and password for faster login.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(15)
            .padding(.horizontal)
            
            Button(action: {
                viewModel.clearKeychain()
                viewModel.errorMessage = "Saved logins cleared successfully."
                viewModel.showError = true
            }) {
                Text("Clear saved logins")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(15)
            }
            .padding(.horizontal)
            
            Button(action: {
                DataManager.shared.model.anisetteServerURL = viewModel.anisetteServerURL
                viewModel.goToStep(.welcome)
            }) {
                Text("Done")
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
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .keyboardAdaptive()
        .task {
            await viewModel.fetchAnisetteServers()
        }
    }
}

// MARK: - Login Slide
struct LoginSlide: View {
    @ObservedObject var viewModel: WizardViewModel
    @State private var appleID: String = ""
    @State private var password: String = ""
    @State private var isLoggingIn = false
    @State private var verificationCode: String = ""
    @FocusState private var verificationCodeFocused: Bool
    @State private var previousStep: WizardStep = .welcome
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: {
                    viewModel.goToStep(.welcome)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)
            Spacer()
            
            Text("Sign In")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Sign in with the Apple ID you used to sign your apps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Login Form
            VStack(spacing: 15) {
                TextField("Apple ID", text: $appleID)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disabled(isLoggingIn || viewModel.loginViewModel.isLoginInProgress)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoggingIn || viewModel.loginViewModel.isLoginInProgress)
                
                if viewModel.loginViewModel.needVerificationCode {
                    TextField("Verification Code", text: $verificationCode)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.numberPad)
                        .disabled(viewModel.loginViewModel.isVerificationCodeSubmitting)
                        .id("verificationCodeInput")
                        .focused($verificationCodeFocused)
                }
                
                if (isLoggingIn || viewModel.loginViewModel.isLoginInProgress) && !viewModel.loginViewModel.needVerificationCode {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.loginProgress)
                            .tint(.blue)
                        Text(viewModel.loginStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                Button(action: {
                    Task { await loginButtonClicked() }
                }) {
                    if viewModel.loginViewModel.needVerificationCode && viewModel.loginViewModel.isVerificationCodeSubmitting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text("Verifying...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient)
                        .cornerRadius(15)
                    } else {
                        Text(viewModel.loginViewModel.needVerificationCode ? "Verify" : "Sign In")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue.gradient)
                            .cornerRadius(15)
                    }
                }
                .disabled(viewModel.loginViewModel.isVerificationCodeSubmitting)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(15)
            .padding(.horizontal)
            
            Text("All authentication is done on-device. Your credentials are never sent to third-party services.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("Try Again", role: .cancel) {
                // Reset verification code state to allow re-entry
                viewModel.loginViewModel.resetVerificationCodeState()
                verificationCode = ""
            }
            Button("Clear Keychain") {
                viewModel.clearKeychain()
                viewModel.errorMessage = "Successfully cleared keychain. Restart the app and try logging in again."
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .keyboardAdaptive()
        .onChange(of: viewModel.loginViewModel.needVerificationCode) { newValue in
            if newValue {
                // Auto-focus the verification code field when it appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    verificationCodeFocused = true
                }
            }
        }
        .onChange(of: viewModel.currentStep) { newStep in
            // Reset local state when navigating to login slide
            if newStep == .login && previousStep != .login {
                if viewModel.saveLoginToKeychain {
                    // Auto-fill from keychain if enabled
                    if let savedEmail = Keychain.shared.appleIDEmailAddress {
                        appleID = savedEmail
                    }
                    if let savedPassword = Keychain.shared.appleIDPassword {
                        password = savedPassword
                    }
                } else {
                    appleID = ""
                    password = ""
                }
                verificationCode = ""
                isLoggingIn = false
                verificationCodeFocused = false
            }
            previousStep = newStep
        }
        .onAppear {
            // Also try to auto-fill on initial appearance
            if viewModel.currentStep == .login && viewModel.saveLoginToKeychain {
                if let savedEmail = Keychain.shared.appleIDEmailAddress, appleID.isEmpty {
                    appleID = savedEmail
                }
                if let savedPassword = Keychain.shared.appleIDPassword, password.isEmpty {
                    password = savedPassword
                }
            }
        }
    }
    
    func loginButtonClicked() async {
        if viewModel.loginViewModel.needVerificationCode {
            do {
                try await viewModel.loginViewModel.verifyTwoFactorCode(verificationCode)
                await MainActor.run {
                    isLoggingIn = false
                    viewModel.nextStep()
                }
            } catch {
                await MainActor.run {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                    isLoggingIn = false
                }
            }
            return
        }

        isLoggingIn = true
        viewModel.loginViewModel.appleID = appleID
        viewModel.loginViewModel.password = password
        
        // Connect progress callback
        viewModel.loginViewModel.progressCallback = { progress, status in
            Task { @MainActor in
                viewModel.updateLoginProgress(progress: progress, status: status)
            }
        }
        
        // Start authentication in background so UI doesn't freeze
        Task {
            do {
                let result = try await viewModel.loginViewModel.authenticate()
                
                await MainActor.run {
                    isLoggingIn = false
                    if result {
                        // Save to keychain only if toggle is enabled
                        if viewModel.saveLoginToKeychain {
                            Keychain.shared.appleIDEmailAddress = appleID
                            Keychain.shared.appleIDPassword = password
                        }
                        viewModel.nextStep()
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    isLoggingIn = false
                }
            } catch {
                await MainActor.run {
                    isLoggingIn = false
                    // If 2FA is needed, don't show error - the 2FA input will be shown
                    if !viewModel.loginViewModel.needVerificationCode {
                        viewModel.errorMessage = error.localizedDescription
                        viewModel.showError = true
                    }
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
                    try await viewModel.loginViewModel.login()
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
        } catch {
            viewModel.errorMessage = "Failed to import account: \(error.localizedDescription)"
            viewModel.showError = true
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
            HStack {
                Button(action: {
                    viewModel.goToStep(.login)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                }
                Spacer()
            }
            .padding(.horizontal)
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
                    .frame(maxWidth: .infinity)
            } else if appIDViewModel.appIDs.isEmpty {
                Text("No apps found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appIDViewModel.appIDs, id: \.self) { appID in
                            Button(action: {
                                viewModel.selectedApp = appID
                                viewModel.nextStep()
                            }) {
                                HStack(spacing: 12) {
                                    let iconName = getAppIconName(for: appID.bundleID)
                                    Image(iconName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
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
        .frame(maxWidth: .infinity)
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
            HStack {
                Button(action: {
                    viewModel.goToStep(.apps)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                }
                Spacer()
            }
            .padding(.horizontal)
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
        .frame(maxWidth: .infinity)
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
                    // Check if error is authentication/session expired
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("401") || errorDescription.contains("not_authorized") || errorDescription.contains("session has expired") {
                        // Navigate back to login page
                        viewModel.goToStep(.login)
                        viewModel.errorMessage = "Your session has expired. Please log in again."
                        viewModel.showError = true
                    } else {
                        viewModel.errorMessage = error.localizedDescription
                        viewModel.showError = true
                    }
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
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Main Wizard View
struct WizardView: View {
    @StateObject private var viewModel = WizardViewModel()
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            Group {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeSlide(viewModel: viewModel)
                case .login:
                    LoginSlide(viewModel: viewModel)
                case .apps:
                    AppsListSlide(viewModel: viewModel)
                case .addCapability:
                    AddCapabilitySlide(viewModel: viewModel)
                case .finish:
                    FinishSlide(viewModel: viewModel)
                case .settings:
                    SettingsSlide(viewModel: viewModel)
                }
            }
        }
        .environmentObject(DataManager.shared.model)
    }
}
