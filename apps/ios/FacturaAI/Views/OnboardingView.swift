import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var page = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .purple.opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    HeroPage().tag(0)
                    HowItWorksPage().tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Start now button — always visible
                VStack(spacing: 12) {
                    Button {
                        withAnimation {
                            hasSeenOnboarding = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Start now").fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .foregroundStyle(.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Text("No account required. Try it free.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }
}

// MARK: - Page 1: Hero

private struct HeroPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white)

            Text("FacturaAI")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Your AI-powered expense manager")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))

            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(icon: "camera.fill", text: "Scan receipts with your camera")
                FeatureRow(icon: "doc.fill", text: "Import invoices from photos or PDFs")
                FeatureRow(icon: "envelope.fill", text: "Auto-sync invoices from Gmail")
                FeatureRow(icon: "cpu", text: "AI extracts amounts, tax & categories")
                FeatureRow(icon: "square.and.arrow.up.fill", text: "Export to your accountant in one tap")
            }
            .padding(20)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 2: How it works

private struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("How it works")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 20) {
                StepRow(number: "1", icon: "photo.on.rectangle.angled",
                        title: "Add your expenses",
                        subtitle: "Snap a photo, pick from gallery, or import a PDF")

                StepRow(number: "2", icon: "sparkles",
                        title: "AI does the work",
                        subtitle: "Vendor, amounts, tax rate and category — extracted instantly")

                StepRow(number: "3", icon: "checkmark.circle.fill",
                        title: "Review & confirm",
                        subtitle: "Quick review, then your expenses are organized")

                StepRow(number: "4", icon: "paperplane.fill",
                        title: "Send to your accountant",
                        subtitle: "Export ZIP with CSV, Excel and original invoices")
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Components

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.white)
            Text(text)
                .foregroundStyle(.white)
            Spacer()
        }
    }
}

private struct StepRow: View {
    let number: String
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
        }
    }
}
