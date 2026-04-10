import SwiftUI

struct GmailSyncView: View {
    @EnvironmentObject var store: ExpenseStore
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showSignIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.indigo.opacity(0.06), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header icon
                        headerIcon
                            .padding(.top, 20)

                        // Connection status
                        connectionCard

                        // Main content based on state
                        if !auth.gmailConnected {
                            connectPrompt
                        } else if store.isSyncing {
                            syncingView
                        } else if let progress = store.syncProgress, progress.status == "completed" {
                            completedView(progress)
                        } else if let progress = store.syncProgress, progress.status == "failed" {
                            failedView
                        } else {
                            idleView
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle(NSLocalizedString("gmailSync.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.close", comment: "")) { dismiss() }
                }
            }
            .sheet(isPresented: $showSignIn) {
                SignInPrompt(
                    title: NSLocalizedString("dashboard.sync.signIn.title", comment: ""),
                    subtitle: NSLocalizedString("dashboard.sync.signIn.subtitle", comment: "")
                )
            }
        }
    }

    // MARK: - Header

    private var headerIcon: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.1))
                .frame(width: 88, height: 88)
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
        }
    }

    // MARK: - Connection Card

    private var connectionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: auth.gmailConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(auth.gmailConnected ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Gmail")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if auth.gmailConnected {
                    Text(auth.userEmail ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(auth.gmailConnected
                 ? NSLocalizedString("gmailSync.connected", comment: "")
                 : NSLocalizedString("gmailSync.not_connected", comment: ""))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(auth.gmailConnected ? .green : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((auth.gmailConnected ? Color.green : Color.secondary).opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Not Connected

    private var connectPrompt: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("gmailSync.connect", comment: ""))
                .font(.title3)
                .fontWeight(.bold)

            Text(NSLocalizedString("gmailSync.connect.subtitle", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                if auth.isSignedIn {
                    Task {
                        await auth.signInWithGoogle()
                        await auth.refreshProfile()
                    }
                } else {
                    showSignIn = true
                }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text(NSLocalizedString("gmailSync.connect", comment: ""))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Idle (ready to sync)

    private var idleView: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("gmailSync.idle.title", comment: ""))
                .font(.title3)
                .fontWeight(.bold)

            Text(NSLocalizedString("gmailSync.idle.subtitle", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let d = store.lastSyncDate {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: NSLocalizedString("gmailSync.last_sync", comment: ""), Formatters.shortDate.string(from: d)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task { await store.syncGmail() }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(NSLocalizedString("gmailSync.start", comment: ""))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Syncing

    private var syncingView: some View {
        VStack(spacing: 20) {
            Text(NSLocalizedString("gmailSync.syncing", comment: ""))
                .font(.title3)
                .fontWeight(.bold)

            if let progress = store.syncProgress {
                // Phase indicator
                VStack(spacing: 16) {
                    if progress.totalMessages == 0 {
                        // Phase 1: scanning inbox
                        SyncPhaseRow(
                            icon: "magnifyingglass",
                            text: NSLocalizedString("gmailSync.scanning", comment: ""),
                            isActive: true
                        )
                    } else {
                        // Phase 1 done
                        SyncPhaseRow(
                            icon: "checkmark.circle.fill",
                            text: String(format: NSLocalizedString("gmailSync.found_emails", comment: ""), progress.totalMessages),
                            isActive: false,
                            isDone: true
                        )

                        // Phase 2: processing
                        SyncPhaseRow(
                            icon: "doc.text.magnifyingglass",
                            text: String(format: NSLocalizedString("gmailSync.processing", comment: ""), progress.messagesProcessed, progress.totalMessages),
                            isActive: true
                        )
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Progress bar
                if progress.totalMessages > 0 {
                    VStack(spacing: 10) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 10)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        LinearGradient(
                                            colors: [.indigo, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(10, geo.size.width * progress.fraction), height: 10)
                                    .animation(.easeInOut(duration: 0.3), value: progress.fraction)
                            }
                        }
                        .frame(height: 10)

                        HStack {
                            Text("\(Int(progress.fraction * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.indigo)
                            Spacer()
                            Text(String(format: NSLocalizedString("gmailSync.invoices_found", comment: ""), progress.invoicesFound))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Invoices found counter
                if progress.invoicesFound > 0 {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: NSLocalizedString("gmailSync.invoices_found", comment: ""), progress.invoicesFound))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Completed

    private func completedView(_ progress: ExpenseStore.GmailSyncProgress) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
            }

            Text(NSLocalizedString("gmailSync.completed.title", comment: ""))
                .font(.title3)
                .fontWeight(.bold)

            if progress.invoicesFound > 0 {
                Text(String(format: NSLocalizedString("gmailSync.completed.subtitle", comment: ""), progress.invoicesFound, progress.totalMessages))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(NSLocalizedString("gmailSync.no_invoices", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Stats row
            if progress.totalMessages > 0 {
                HStack(spacing: 24) {
                    StatBubble(
                        icon: "envelope.fill",
                        value: "\(progress.totalMessages)",
                        label: "Emails",
                        color: .blue
                    )
                    StatBubble(
                        icon: "doc.text.fill",
                        value: "\(progress.invoicesFound)",
                        label: NSLocalizedString("export.invoices", comment: ""),
                        color: .green
                    )
                }
            }

            Button {
                dismiss()
            } label: {
                Text(NSLocalizedString("gmailSync.done", comment: ""))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Failed

    private var failedView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
            }

            Text(NSLocalizedString("gmailSync.failed", comment: ""))
                .font(.title3)
                .fontWeight(.bold)

            if let err = store.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await store.syncGmail() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(NSLocalizedString("gmailSync.retry", comment: ""))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - Subviews

private struct SyncPhaseRow: View {
    let icon: String
    let text: String
    var isActive: Bool = false
    var isDone: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if isActive {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isDone ? .green : .secondary)
                    .frame(width: 24, height: 24)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(isActive ? .primary : (isDone ? .green : .secondary))
            Spacer()
        }
    }
}

private struct StatBubble: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
