import SwiftUI
import PhotosUI
import VisionKit
import AuthenticationServices

#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct FirstUseView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ExpenseStore
    @AppStorage("hasCompletedFirstUse") private var hasCompletedFirstUse = false
    @State private var step: Step = .welcome
    @State private var showCamera = false
    @State private var showCameraUnavailable = false
    @State private var showPhotoPicker = false
    @State private var showDocPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var scanning = false
    @State private var scannedExpense: Expense?
    @State private var errorMessage: String?

    @State private var companyNameInput: String = ""
    @State private var taxIdInput: String = ""
    @State private var selectedCountry: TaxCountry = .spain
    @State private var showCountryPicker = false

    enum Step: Int, CaseIterable {
        case welcome = 0
        case companyName = 1
        case upload = 2
        case review = 3
        case trial = 4
    }

    var body: some View {
        ZStack {
            // Unified background
            LinearGradient(
                colors: [Color.indigo.opacity(0.08), Color.purple.opacity(0.04), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                Group {
                    switch step {
                    case .welcome:
                        welcomeStep
                    case .companyName:
                        companyNameStep
                    case .upload:
                        uploadStep
                    case .review:
                        reviewStep
                    case .trial:
                        trialStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                // Unified step indicator
                StepIndicator(current: step.rawValue, total: Step.allCases.count)
                    .padding(.bottom, 16)
            }

            // Blocking extraction overlay
            if scanning {
                ExtractionOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: scanning)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.indigo)
                }

                Text(NSLocalizedString("onboarding.welcome.app_name", comment: ""))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("onboarding.welcome.tagline", comment: ""))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 16) {
                // Three short value props
                HStack(spacing: 20) {
                    ValuePill(icon: "camera.fill", text: NSLocalizedString("onboarding.welcome.pill.scan", comment: ""))
                    ValuePill(icon: "cpu", text: NSLocalizedString("onboarding.welcome.pill.extract", comment: ""))
                    ValuePill(icon: "paperplane.fill", text: NSLocalizedString("onboarding.welcome.pill.export", comment: ""))
                }

                Text(NSLocalizedString("onboarding.welcome.cta_hint", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.35)) { step = .companyName }
            } label: {
                HStack {
                    Text(NSLocalizedString("onboarding.welcome.cta", comment: "")).fontWeight(.bold)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Text(NSLocalizedString("onboarding.welcome.footer", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Step 2: Company Name + Tax ID

    private var isCompanyStepValid: Bool {
        !companyNameInput.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var companyNameStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.indigo.opacity(0.12))
                            .frame(width: 88, height: 88)
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.indigo)
                    }

                    Text(NSLocalizedString("onboarding.company.title", comment: ""))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("onboarding.company.subtitle", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 32)

                // Company name field
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("onboarding.company.name_label", comment: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    TextField(NSLocalizedString("onboarding.company.placeholder", comment: ""), text: $companyNameInput)
                        .textInputAutocapitalization(.words)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)

                // Country picker
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("onboarding.company.country_label", comment: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    Button {
                        showCountryPicker = true
                    } label: {
                        HStack {
                            Text(selectedCountry.flag)
                                .font(.title3)
                            Text(selectedCountry.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(selectedCountry.taxIdLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)

                // Tax ID field
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedCountry.taxIdLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)

                    TextField(selectedCountry.taxIdPlaceholder, text: $taxIdInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)

                Text(NSLocalizedString("onboarding.company.hint", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer(minLength: 20)

                Button {
                    let trimmed = companyNameInput.trimmingCharacters(in: .whitespaces)
                    let taxTrimmed = taxIdInput.trimmingCharacters(in: .whitespaces)
                    auth.companyName = trimmed
                    auth.taxId = taxTrimmed.isEmpty ? nil : taxTrimmed
                    if auth.isSignedIn {
                        Task {
                            var fields: [String: Any] = ["company_name": trimmed, "tax_id_type": selectedCountry.taxIdType]
                            if !taxTrimmed.isEmpty { fields["tax_id"] = taxTrimmed }
                            try? await APIClient.shared.updateProfile(fields)
                        }
                    }
                    withAnimation(.easeInOut(duration: 0.35)) { step = .upload }
                } label: {
                    HStack {
                        Text(NSLocalizedString("onboarding.company.cta", comment: "")).fontWeight(.bold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isCompanyStepValid ? Color.indigo : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isCompanyStepValid)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selected: $selectedCountry)
        }
    }

    // MARK: - Step 2: Upload

    private var uploadStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.indigo.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "doc.viewfinder.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.indigo)
                    }

                    Text(NSLocalizedString("onboarding.upload.title", comment: ""))
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text(NSLocalizedString("onboarding.upload.subtitle", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    ActionCard(
                        icon: "camera.fill",
                        title: NSLocalizedString("onboarding.upload.scan", comment: ""),
                        subtitle: NSLocalizedString("onboarding.upload.scan.sub", comment: ""),
                        color: .indigo
                    ) {
                        if VNDocumentCameraViewController.isSupported {
                            showCamera = true
                        } else {
                            showCameraUnavailable = true
                        }
                    }

                    ActionCard(
                        icon: "photo.on.rectangle",
                        title: NSLocalizedString("onboarding.upload.gallery", comment: ""),
                        subtitle: NSLocalizedString("onboarding.upload.gallery.sub", comment: ""),
                        color: .purple
                    ) {
                        showPhotoPicker = true
                    }

                    ActionCard(
                        icon: "doc.fill",
                        title: NSLocalizedString("onboarding.upload.pdf", comment: ""),
                        subtitle: NSLocalizedString("onboarding.upload.pdf.sub", comment: ""),
                        color: .blue
                    ) {
                        showDocPicker = true
                    }
                }
                .padding(.horizontal, 20)

                if let errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button { self.errorMessage = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            DocumentScanner { image in
                guard let image, let data = image.jpegData(compressionQuality: 0.85) else { return }
                Task { await uploadData(data, filename: "scan_\(UUID().uuidString).jpg") }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) {
            guard let item = selectedPhotoItem else { return }
            selectedPhotoItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                await uploadData(data, filename: "photo_\(UUID().uuidString).jpg")
            }
        }
        .sheet(isPresented: $showDocPicker) {
            DocumentPicker { url in
                guard let url else { return }
                scanning = true
                guard url.startAccessingSecurityScopedResource() else { scanning = false; return }
                let filename = url.lastPathComponent
                Task {
                    await uploadFile(url, filename: filename)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
        .alert(NSLocalizedString("scan.camera_unavailable.title", comment: ""), isPresented: $showCameraUnavailable) {
            Button(NSLocalizedString("common.ok", comment: "")) {}
        } message: {
            Text(NSLocalizedString("scan.camera_unavailable.message", comment: ""))
        }
    }

    // MARK: - Step 3: Review

    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                }
                .padding(.top, 32)

                Text(NSLocalizedString(
                    scannedExpense?.type == .income
                        ? "onboarding.review.title.income"
                        : "onboarding.review.title",
                    comment: ""))
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                if scannedExpense?.type == .income {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(NSLocalizedString("transaction.income", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                }

                Text(NSLocalizedString("onboarding.review.subtitle", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let expense = scannedExpense {
                    VStack(alignment: .leading, spacing: 14) {
                        resultRow(NSLocalizedString("onboarding.review.field.vendor", comment: ""), expense.vendor)
                        resultRow(NSLocalizedString("onboarding.review.field.total", comment: ""), Formatters.money(expense.total, currency: expense.currency))
                        resultRow(NSLocalizedString("onboarding.review.field.subtotal", comment: ""), Formatters.money(expense.subtotal, currency: expense.currency))
                        resultRow(String(format: NSLocalizedString("onboarding.review.field.tax", comment: ""), "\(expense.ivaRate)"), Formatters.money(expense.ivaAmount, currency: expense.currency))
                        resultRow(NSLocalizedString("onboarding.review.field.category", comment: ""), expense.category.localizedName)
                        resultRow(NSLocalizedString("onboarding.review.field.confidence", comment: ""), "\(Int(expense.confidence * 100))%")
                    }
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }

                Text(NSLocalizedString("onboarding.review.tagline", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                Button {
                    withAnimation(.easeInOut(duration: 0.35)) { step = .trial }
                } label: {
                    HStack {
                        Text(NSLocalizedString("onboarding.review.continue", comment: "")).fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)

                Button {
                    withAnimation(.easeInOut(duration: 0.35)) { step = .upload }
                } label: {
                    Text(NSLocalizedString("onboarding.review.scan_another", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Step 4: Trial

    @State private var signingIn = false
    @State private var signInError: String?
    @State private var showPaywall = false
    @State private var showSetupChecklist = false
    @State private var showGmailSync = false
    @State private var showAccountantSetup = false
    @State private var restoringPurchases = false
    @State private var showRestoreResult = false
    @State private var restoreSuccess = false
    @StateObject private var revenueCat = RevenueCatService.shared

    private var trialStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 24)

                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.yellow)
                }

                if auth.isSignedIn && showSetupChecklist {
                    // Phase 2a: Setup checklist after sign-in
                    Text(NSLocalizedString("onboarding.checklist.title", comment: ""))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("onboarding.checklist.subtitle", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        SetupChecklistRow(
                            icon: "envelope.fill",
                            title: NSLocalizedString("onboarding.checklist.gmail", comment: ""),
                            subtitle: NSLocalizedString("onboarding.checklist.gmail.sub", comment: ""),
                            done: auth.gmailConnected,
                            color: .red
                        ) {
                            showGmailSync = true
                        }

                        SetupChecklistRow(
                            icon: "person.text.rectangle.fill",
                            title: NSLocalizedString("onboarding.checklist.accountant", comment: ""),
                            subtitle: NSLocalizedString("onboarding.checklist.accountant.sub", comment: ""),
                            done: auth.accountantEmail != nil && !(auth.accountantEmail?.isEmpty ?? true),
                            color: .teal
                        ) {
                            showAccountantSetup = true
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 20)

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSetupChecklist = false
                        }
                    } label: {
                        HStack {
                            Text(NSLocalizedString("onboarding.checklist.done", comment: "")).fontWeight(.bold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSetupChecklist = false
                        }
                    } label: {
                        Text(NSLocalizedString("onboarding.checklist.skip", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                } else if auth.isSignedIn {
                    // Phase 2b: Already signed in → show subscription prompt
                    Text(NSLocalizedString("onboarding.trial.title", comment: ""))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("onboarding.trial.subtitle", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        trialFeature(NSLocalizedString("onboarding.trial.feature.gmail", comment: ""))
                        trialFeature(NSLocalizedString("onboarding.trial.feature.scan", comment: ""))
                        trialFeature(NSLocalizedString("onboarding.trial.feature.export", comment: ""))
                        trialFeature(NSLocalizedString("onboarding.trial.feature.tax", comment: ""))
                        trialFeature(NSLocalizedString("onboarding.trial.feature.sync", comment: ""))
                    }
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text(NSLocalizedString("onboarding.trial.cta", comment: "")).fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)

                    Button {
                        Task {
                            restoringPurchases = true
                            restoreSuccess = await RevenueCatService.shared.restorePurchases()
                            restoringPurchases = false
                            showRestoreResult = true
                        }
                    } label: {
                        if restoringPurchases {
                            ProgressView()
                                .tint(.indigo)
                        } else {
                            Text(NSLocalizedString("onboarding.trial.restore", comment: ""))
                                .font(.subheadline)
                                .foregroundStyle(.indigo)
                        }
                    }
                    .disabled(restoringPurchases)

                    HStack(spacing: 16) {
                        Link(NSLocalizedString("onboarding.trial.terms", comment: ""), destination: URL(string: "https://invoscanai.com/terms")!)
                            .font(.caption2).foregroundStyle(.secondary)
                        Link(NSLocalizedString("onboarding.trial.privacy", comment: ""), destination: URL(string: "https://invoscanai.com/privacy")!)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)

                } else {
                    // Phase 1: Not signed in → sign in first
                    Text(NSLocalizedString("onboarding.trial.account.title", comment: ""))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("onboarding.trial.account.subtitle", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    VStack(alignment: .leading, spacing: 12) {
                        trialFeature(NSLocalizedString("onboarding.trial.feature.gmail", comment: ""))
                        trialFeature(NSLocalizedString("onboarding.trial.feature.scan", comment: ""))
                        trialFeature(NSLocalizedString("onboarding.trial.feature.export", comment: ""))
                        trialFeature(NSLocalizedString("onboarding.trial.feature.tax", comment: ""))
                        trialFeature(NSLocalizedString("onboarding.trial.feature.sync", comment: ""))
                    }
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    // Sign in buttons
                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.email, .fullName]
                        } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    Task {
                                        signingIn = true
                                        signInError = nil
                                        await auth.signInWithApple(credential: credential)
                                        await persistCompanyName()
                                        signingIn = false
                                        if auth.isSignedIn { showSetupChecklist = true }
                                    }
                                }
                            case .failure(let error):
                                let nsError = error as NSError
                                if nsError.code != ASAuthorizationError.canceled.rawValue {
                                    signInError = "Apple Sign In error: \(nsError.localizedDescription)"
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(signingIn)

                        Button {
                            Task {
                                signingIn = true
                                signInError = nil
                                await auth.signInWithGoogle()
                                await persistCompanyName()
                                signingIn = false
                                if auth.isSignedIn { showSetupChecklist = true }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text(NSLocalizedString("signIn.google", comment: "")).fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemGray6))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(signingIn)
                    }
                    .padding(.horizontal, 20)

                    if let signInError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(signInError)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 20)
                    }

                    if signingIn {
                        VStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.indigo)
                            Text(NSLocalizedString("onboarding.trial.signing_in", comment: ""))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                    }
                }

            }
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showPaywall) {
            OnboardingPaywallSheet {
                hasCompletedFirstUse = true
            }
        }
        .sheet(isPresented: $showGmailSync) {
            GmailSyncView()
        }
        .sheet(isPresented: $showAccountantSetup) {
            NavigationStack {
                AccountantSettingsView()
            }
        }
        .alert(
            restoreSuccess
                ? NSLocalizedString("restore.success.title", comment: "")
                : NSLocalizedString("restore.empty.title", comment: ""),
            isPresented: $showRestoreResult
        ) {
            Button(NSLocalizedString("common.ok", comment: "")) {}
        } message: {
            Text(restoreSuccess
                 ? NSLocalizedString("restore.success.message", comment: "")
                 : NSLocalizedString("restore.empty.message", comment: ""))
        }
        .onChange(of: revenueCat.isPro) {
            if revenueCat.isPro {
                hasCompletedFirstUse = true
            }
        }
    }

    // MARK: - Helpers

    private func persistCompanyName() async {
        let name = companyNameInput.trimmingCharacters(in: .whitespaces)
        let taxId = taxIdInput.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, auth.isSignedIn else { return }
        var fields: [String: Any] = [
            "company_name": name,
            "tax_id_type": selectedCountry.taxIdType,
        ]
        if !taxId.isEmpty { fields["tax_id"] = taxId }
        try? await APIClient.shared.updateProfile(fields)

        // Anonymous user expenses are automatically merged on sign-in.
        // Just reload from server to pick them up.
        if scannedExpense != nil {
            await store.reload()
        }
    }

    private func uploadData(_ data: Data, filename: String) async {
        scanning = true
        errorMessage = nil
        let company = companyNameInput.trimmingCharacters(in: .whitespaces)
        do {
            let expense = try await store.extractReceipt(data: data, filename: filename, forceAnonymous: true, companyName: company.isEmpty ? nil : company)
            scannedExpense = expense
            scanning = false
            withAnimation(.easeInOut(duration: 0.35)) { step = .review }
        } catch {
            scanning = false
            withAnimation { errorMessage = error.localizedDescription }
        }
    }

    /// File-based upload — streams the file to avoid loading large PDFs into memory.
    private func uploadFile(_ fileURL: URL, filename: String) async {
        scanning = true
        errorMessage = nil
        let company = companyNameInput.trimmingCharacters(in: .whitespaces)
        do {
            let expense = try await store.extractReceiptFromFile(fileURL: fileURL, filename: filename, forceAnonymous: true, companyName: company.isEmpty ? nil : company)
            scannedExpense = expense
            scanning = false
            withAnimation(.easeInOut(duration: 0.35)) { step = .review }
        } catch {
            scanning = false
            withAnimation { errorMessage = error.localizedDescription }
        }
    }

    @ViewBuilder
    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    @ViewBuilder
    private func trialFeature(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Value Pill

private struct ValuePill: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 44, height: 44)
                .background(Color.indigo.opacity(0.1))
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Step Indicator

private struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.indigo : Color(.systemGray4))
                    .frame(width: i == current ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: current)
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Extraction Overlay

private struct ExtractionOverlay: View {
    @State private var phase = 0
    @State private var iconScale: CGFloat = 1.0

    private let steps: [(icon: String, text: String)] = [
        ("doc.text.magnifyingglass", NSLocalizedString("scan.extract.reading", comment: "")),
        ("cpu", NSLocalizedString("scan.extract.analyzing", comment: "")),
        ("text.viewfinder", NSLocalizedString("scan.extract.amounts", comment: "")),
        ("building.columns", NSLocalizedString("scan.extract.vendor", comment: "")),
        ("checkmark.seal", NSLocalizedString("scan.extract.verifying", comment: "")),
        ("sparkles", NSLocalizedString("scan.extract.almost", comment: "")),
    ]

    private var current: (icon: String, text: String) {
        steps[phase % steps.count]
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Card
            VStack(spacing: 28) {
                ZStack {
                    // Pulsing ring
                    Circle()
                        .stroke(Color.indigo.opacity(0.3), lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(iconScale)

                    Circle()
                        .fill(Color.indigo.opacity(0.1))
                        .frame(width: 88, height: 88)

                    Image(systemName: current.icon)
                        .font(.system(size: 36))
                        .foregroundStyle(.indigo)
                        .contentTransition(.symbolEffect(.replace))
                        .id(current.icon)
                }

                VStack(spacing: 8) {
                    Text(current.text)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.4), value: phase)
                        .id(current.text)

                    BouncingDots()
                }

                // Progress steps
                HStack(spacing: 4) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Capsule()
                            .fill(i <= phase % steps.count ? Color.indigo : Color(.systemGray4))
                            .frame(width: i == phase % steps.count ? 20 : 8, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: phase)
                    }
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 40)
        }
        .onAppear {
            // Pulse ring
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                iconScale = 1.15
            }
            // Cycle messages
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    phase += 1
                }
            }
        }
    }

}

// Animated bouncing dots view
private struct BouncingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.indigo)
                    .frame(width: 6, height: 6)
                    .offset(y: animating ? -6 : 0)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onPick(nil)
        } 
    }
}

// MARK: - Onboarding Paywall Sheet

private struct OnboardingPaywallSheet: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if canImport(RevenueCatUI)
        RevenueCatUI.PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { _ in
                Task { await RevenueCatService.shared.refresh() }
                onComplete()
                dismiss()
            }
            .onRestoreCompleted { _ in
                Task { await RevenueCatService.shared.refresh() }
                onComplete()
                dismiss()
            }
        #else
        // Fallback when RevenueCat SDK is not installed yet
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.indigo)
                Text(NSLocalizedString("paywall.fallback.title", comment: ""))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(NSLocalizedString("paywall.fallback.subtitle", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                Button {
                    onComplete()
                    dismiss()
                } label: {
                    Text(NSLocalizedString("paywall.fallback.continue", comment: ""))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        #endif
    }
}

// MARK: - Action Card

private struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.semibold).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Setup Checklist Row

private struct SetupChecklistRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let done: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.circle.fill" : icon)
                    .font(.title2)
                    .foregroundStyle(done ? .green : .white)
                    .frame(width: 48, height: 48)
                    .background(done ? Color.green.opacity(0.15) : color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundStyle(done ? .secondary : .primary)
                        .strikethrough(done)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !done {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(done)
    }
}
