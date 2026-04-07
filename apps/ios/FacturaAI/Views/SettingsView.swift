import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ExpenseStore

    var planLabel: String {
        switch auth.plan {
        case "trial": return "Prueba · \(auth.trialDaysLeft)d restantes"
        case "pro": return "Pro — €6,99/mes"
        case "business": return "Business — €12,99/mes"
        case "expired": return "Prueba expirada"
        default: return auth.plan
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if auth.plan == "trial" && auth.trialDaysLeft <= 5 {
                    Section {
                        TrialBanner(daysLeft: auth.trialDaysLeft)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                Section("Cuenta") {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title)
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading) {
                            Text(auth.userEmail ?? "—").fontWeight(.semibold)
                            Text(planLabel).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Integraciones") {
                    HStack {
                        Image(systemName: "envelope.fill").foregroundStyle(.red)
                        Text("Gmail")
                        Spacer()
                        Text(auth.gmailConnected ? "Conectado" : "Desconectado")
                            .font(.caption)
                            .foregroundStyle(auth.gmailConnected ? .green : .secondary)
                    }
                    HStack {
                        Image(systemName: "icloud.fill").foregroundStyle(.blue)
                        Text("Google Drive")
                        Spacer()
                        Text("Próximamente").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Image(systemName: "building.columns.fill").foregroundStyle(.teal)
                        Text("Banco (PSD2)")
                        Spacer()
                        Text("Próximamente").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Plan") {
                    NavigationLink {
                        PricingView()
                    } label: {
                        Label(auth.plan == "pro" || auth.plan == "business"
                              ? "Cambiar plan"
                              : "Ver planes Pro y Business",
                              systemImage: "sparkles")
                    }
                }

                Section("Datos") {
                    Text("\(store.expenses.count) gastos almacenados")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        Text("Cerrar sesión")
                    }
                }

                Section {
                    Text("FacturaAI v1.0 · Kung Fu Software SL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}

private struct TrialBanner: View {
    let daysLeft: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.fill")
                Text("Tu prueba termina en \(daysLeft) día\(daysLeft == 1 ? "" : "s")")
                    .fontWeight(.semibold)
            }
            Text("Suscríbete para seguir usando FacturaAI sin interrupciones.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            NavigationLink {
                PricingView()
            } label: {
                Text("Ver planes")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.white)
                    .foregroundStyle(.indigo)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

struct PricingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Elige tu plan")
                    .font(.largeTitle).fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Sin tarjeta durante la prueba de 14 días.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PlanCard(
                    name: "Pro",
                    price: "€6,99/mes",
                    annual: "o €59/año (30% descuento)",
                    features: [
                        "Recibos ilimitados",
                        "Sync Gmail automático diario",
                        "Escaneo IA de tickets ilimitado",
                        "Export CSV + Excel + Email",
                        "Categorización fiscal española completa",
                    ],
                    highlighted: true,
                    badge: "Más popular"
                )
                PlanCard(
                    name: "Business",
                    price: "€12,99/mes",
                    annual: "o €109/año",
                    features: [
                        "Todo lo de Pro",
                        "Sync Gmail cada hora",
                        "Portal gestoría (solo lectura)",
                        "Hasta 3 usuarios",
                        "Conexión bancaria PSD2 (próximamente)",
                    ],
                    highlighted: false,
                    badge: nil
                )
            }
            .padding()
        }
        .navigationTitle("Planes")
        .background(Color(.systemGroupedBackground))
    }
}

private struct PlanCard: View {
    let name: String
    let price: String
    let annual: String
    let features: [String]
    let highlighted: Bool
    let badge: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name).font(.title2).fontWeight(.bold)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.yellow)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            }
            Text(price)
                .font(.title).fontWeight(.bold)
                .foregroundStyle(highlighted ? .white : .indigo)
            Text(annual)
                .font(.caption)
                .foregroundStyle(highlighted ? .white.opacity(0.85) : .secondary)
            Divider().background(highlighted ? .white.opacity(0.3) : .gray.opacity(0.3))
            ForEach(features, id: \.self) { f in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(f).font(.subheadline)
                }
                .foregroundStyle(highlighted ? .white : .primary)
            }
            Button {
                // TODO: wire StoreKit subscription flow
            } label: {
                Text("Suscribirme")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(highlighted ? .white : Color.indigo)
                    .foregroundStyle(highlighted ? .indigo : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(highlighted
                      ? AnyShapeStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
        )
    }
}
