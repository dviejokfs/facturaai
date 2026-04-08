import SwiftUI
import PhotosUI
import VisionKit

struct FirstUseView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ExpenseStore
    @AppStorage("hasCompletedFirstUse") private var hasCompletedFirstUse = false
    @State private var step: Step = .welcome
    @State private var showCamera = false
    @State private var showCameraUnavailable = false
    @State private var showPhotoPicker = false
    @State private var showDocPicker = false
    @State private var showSignIn = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var scanning = false
    @State private var scannedExpense: Expense?

    enum Step: Int, CaseIterable {
        case welcome = 0
        case upload = 1
        case review = 2
        case trial = 3
    }

    private let stepLabels = ["Welcome", "Upload", "Review", "Start"]

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
                StepIndicator(current: step.rawValue, labels: stepLabels)
                    .padding(.bottom, 16)
            }
        }
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

                Text("FacturaAI")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Your AI-powered expense manager\nfor autónomos")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 16) {
                // Three short value props
                HStack(spacing: 20) {
                    ValuePill(icon: "camera.fill", text: "Scan")
                    ValuePill(icon: "cpu", text: "Extract")
                    ValuePill(icon: "paperplane.fill", text: "Export")
                }

                Text("Let's see it in action — upload your first invoice.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.35)) { step = .upload }
            } label: {
                HStack {
                    Text("Let's try it").fontWeight(.bold)
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

            Text("No account needed. Takes 30 seconds.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
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

                    Text("Upload your first invoice")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("Pick any receipt or invoice — the AI will do the rest")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    ActionCard(
                        icon: "camera.fill",
                        title: "Scan a receipt",
                        subtitle: "Take a photo of any receipt or invoice",
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
                        title: "Pick from gallery",
                        subtitle: "Select a photo of an invoice",
                        color: .purple
                    ) {
                        showPhotoPicker = true
                    }

                    ActionCard(
                        icon: "doc.fill",
                        title: "Upload a PDF",
                        subtitle: "Import a PDF invoice from your files",
                        color: .blue
                    ) {
                        showDocPicker = true
                    }
                }
                .padding(.horizontal, 20)

                if scanning {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("AI is extracting data…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
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
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                guard let data = try? Data(contentsOf: url) else { return }
                let filename = url.lastPathComponent
                Task { await uploadData(data, filename: filename) }
            }
        }
        .alert("Camera not available", isPresented: $showCameraUnavailable) {
            Button("OK") {}
        } message: {
            Text("Document scanning is not available on this device. Try importing from your gallery or uploading a PDF instead.")
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

                Text("Expense extracted!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("Here's what the AI found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let expense = scannedExpense {
                    VStack(alignment: .leading, spacing: 14) {
                        resultRow("Vendor", expense.vendor)
                        resultRow("Total", Formatters.money(expense.total, currency: expense.currency))
                        resultRow("Subtotal", Formatters.money(expense.subtotal, currency: expense.currency))
                        resultRow("Tax (\(expense.ivaRate)%)", Formatters.money(expense.ivaAmount, currency: expense.currency))
                        resultRow("Category", expense.category.rawValue)
                        resultRow("Confidence", "\(Int(expense.confidence * 100))%")
                    }
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }

                Text("Imagine this for every invoice — automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                Button {
                    withAnimation(.easeInOut(duration: 0.35)) { step = .trial }
                } label: {
                    HStack {
                        Text("Continue").fontWeight(.semibold)
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
                    Text("Scan another")
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Step 4: Trial

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

                Text("Ready to manage\nyour expenses?")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Start your 14-day free trial to unlock everything.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    trialFeature("Gmail auto-sync — find all your invoices")
                    trialFeature("Unlimited AI receipt scanning")
                    trialFeature("Export CSV + Excel to your accountant")
                    trialFeature("Full Spanish tax categorization")
                    trialFeature("Sync across devices")
                }
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Button {
                        showSignIn = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Start free trial").fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text("No credit card required. Cancel anytime.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)

                Button {
                    withAnimation { hasCompletedFirstUse = true }
                } label: {
                    Text("Continue without account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInPrompt(
                title: "Create your account",
                subtitle: "Sign in to start your 14-day free trial. Full access to all features."
            )
        }
        .onChange(of: auth.isSignedIn) {
            if auth.isSignedIn {
                hasCompletedFirstUse = true
            }
        }
    }

    // MARK: - Helpers

    private func uploadData(_ data: Data, filename: String) async {
        scanning = true
        do {
            let expense = try await store.uploadReceipt(data: data, filename: filename)
            scannedExpense = expense
            scanning = false
            withAnimation(.easeInOut(duration: 0.35)) { step = .review }
        } catch {
            scanning = false
            store.lastError = error.localizedDescription
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
    let labels: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(labels.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(i <= current ? Color.indigo : Color(.systemGray4))
                            .frame(width: 26, height: 26)
                        if i < current {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        } else {
                            Text("\(i + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(i == current ? .white : .secondary)
                        }
                    }
                    if i < labels.count - 1 {
                        Text(labels[i])
                            .font(.caption)
                            .foregroundStyle(i <= current ? .primary : .secondary)
                    } else {
                        Text(labels[i])
                            .font(.caption)
                            .foregroundStyle(i <= current ? .primary : .secondary)
                    }
                }

                if i < labels.count - 1 {
                    Rectangle()
                        .fill(i < current ? Color.indigo : Color(.systemGray4))
                        .frame(height: 2)
                        .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
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
