import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var store: ExpenseStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Cuenta") {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title)
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading) {
                            Text(auth.userEmail ?? "—").fontWeight(.semibold)
                            Text("Plan Free").font(.caption).foregroundStyle(.secondary)
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
                        Label("Actualizar a Pro — €6,99/mes", systemImage: "sparkles")
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

struct PricingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PlanCard(name: "Free", price: "€0", features: [
                    "10 recibos/mes", "Sincronización Gmail manual", "Export CSV"
                ], highlighted: false)
                PlanCard(name: "Pro", price: "€6,99/mes", features: [
                    "Recibos ilimitados", "Sync automático diario",
                    "Export CSV + Excel + Email", "Categorización fiscal completa"
                ], highlighted: true)
                PlanCard(name: "Business", price: "€12,99/mes", features: [
                    "Todo Pro", "Sync cada hora", "Portal gestoría",
                    "Hasta 3 usuarios", "Conexión bancaria PSD2"
                ], highlighted: false)
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
    let features: [String]
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name).font(.title2).fontWeight(.bold)
                Spacer()
                Text(price).fontWeight(.semibold)
                    .foregroundStyle(highlighted ? .white : .indigo)
            }
            ForEach(features, id: \.self) { f in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(f).font(.subheadline)
                }
                .foregroundStyle(highlighted ? .white : .primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(highlighted ? Color.indigo : Color(.secondarySystemGroupedBackground))
        )
    }
}
