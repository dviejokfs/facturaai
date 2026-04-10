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
                            Text(NSLocalizedString("onboarding.start_now", comment: "")).fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .foregroundStyle(.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Text(NSLocalizedString("onboarding.no_account", comment: ""))
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

            Text(NSLocalizedString("onboarding.welcome.app_name", comment: ""))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(NSLocalizedString("onboarding.hero.subtitle", comment: ""))
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))

            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(icon: "camera.fill", text: NSLocalizedString("onboarding.hero.feature.scan", comment: ""))
                FeatureRow(icon: "doc.fill", text: NSLocalizedString("onboarding.hero.feature.import", comment: ""))
                FeatureRow(icon: "envelope.fill", text: NSLocalizedString("onboarding.hero.feature.gmail", comment: ""))
                FeatureRow(icon: "cpu", text: NSLocalizedString("onboarding.hero.feature.ai", comment: ""))
                FeatureRow(icon: "square.and.arrow.up.fill", text: NSLocalizedString("onboarding.hero.feature.export", comment: ""))
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

            Text(NSLocalizedString("onboarding.how_it_works.title", comment: ""))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 20) {
                StepRow(number: "1", icon: "photo.on.rectangle.angled",
                        title: NSLocalizedString("onboarding.how_it_works.step1.title", comment: ""),
                        subtitle: NSLocalizedString("onboarding.how_it_works.step1.subtitle", comment: ""))

                StepRow(number: "2", icon: "sparkles",
                        title: NSLocalizedString("onboarding.how_it_works.step2.title", comment: ""),
                        subtitle: NSLocalizedString("onboarding.how_it_works.step2.subtitle", comment: ""))

                StepRow(number: "3", icon: "checkmark.circle.fill",
                        title: NSLocalizedString("onboarding.how_it_works.step3.title", comment: ""),
                        subtitle: NSLocalizedString("onboarding.how_it_works.step3.subtitle", comment: ""))

                StepRow(number: "4", icon: "paperplane.fill",
                        title: NSLocalizedString("onboarding.how_it_works.step4.title", comment: ""),
                        subtitle: NSLocalizedString("onboarding.how_it_works.step4.subtitle", comment: ""))
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
