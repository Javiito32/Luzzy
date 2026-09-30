import LuzzyStore
import LuzzyUI
import StoreKit
import SwiftUI

extension PremiumFeature {
    var title: LocalizedStringKey {
        switch self {
        case .multipleAccounts: "Todas tus cuentas"
        case .transfers: "Transferencias entre cuentas"
        case .budgets: "Presupuestos"
        case .billsAndPiggyBanks: "Facturas y huchas"
        case .splitTransactions: "Movimientos divididos"
        case .categoriesAndTags: "Categorías y etiquetas"
        case .rules: "Reglas automáticas"
        case .recurringTransactions: "Movimientos recurrentes"
        case .reports: "Informes"
        case .widgets: "Widgets"
        case .multipleServers: "Varios servidores"
        }
    }

    var systemImage: String {
        switch self {
        case .multipleAccounts: "creditcard.and.123"
        case .transfers: "arrow.left.arrow.right"
        case .budgets: "chart.pie"
        case .billsAndPiggyBanks: "calendar"
        case .splitTransactions: "arrow.triangle.branch"
        case .categoriesAndTags: "folder"
        case .rules: "bolt"
        case .recurringTransactions: "repeat"
        case .reports: "chart.bar"
        case .widgets: "square.grid.2x2"
        case .multipleServers: "server.rack"
        }
    }

    /// Funciones que aún no están disponibles (se muestran como "Próximamente").
    var isComingSoon: Bool {
        switch self {
        case .rules, .recurringTransactions, .reports, .widgets, .multipleServers: true
        default: false
        }
    }
}

/// Pantalla de suscripción con la interfaz nativa de StoreKit.
struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SubscriptionStoreView(productIDs: purchases.configuration.subscriptionIDs) {
                marketing
            }
            .storeButton(.visible, for: .restorePurchases)
            .subscriptionStorePolicyDestination(url: AppConfiguration.privacyPolicyURL, for: .privacyPolicy)
            .subscriptionStorePolicyDestination(url: AppConfiguration.termsURL, for: .termsOfService)
            .onInAppPurchaseCompletion { _, _ in
                await purchases.refreshEntitlement()
                if purchases.isPremium { dismiss() }
            }
            .safeAreaInset(edge: .bottom) { lifetime }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var marketing: some View {
        VStack(spacing: 16) {
            LuzzyMark(size: 64)
            Text("Luzzy Premium")
                .font(.system(.title, design: .rounded, weight: .bold))
            Text("La versión gratuita incluye una cuenta con sus gastos e ingresos. Premium desbloquea todas tus cuentas y la planificación. La privacidad y la seguridad siempre son gratis.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(PremiumFeature.allCases) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.systemImage)
                            .frame(width: 24)
                            .foregroundStyle(LuzzyTheme.accent)
                        Text(feature.title)
                        if feature.isComingSoon {
                            StatusBadge(Text("Próximamente"), tint: .secondary)
                        }
                    }
                    .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var lifetime: some View {
        if let product = purchases.lifetimeProduct, purchases.entitlement != .lifetime {
            Button {
                Task {
                    if await purchases.purchase(product) { dismiss() }
                }
            } label: {
                Text("Compra única de por vida: \(product.displayPrice)")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
            .background(.bar)
        }
    }
}

/// Tarjeta que invita a Premium en lugar de una función bloqueada.
struct PremiumTeaser: View {
    let feature: PremiumFeature
    @State private var showingPaywall = false

    var body: some View {
        Button { showingPaywall = true } label: {
            HStack(spacing: 14) {
                Image(systemName: feature.systemImage)
                    .font(.title3)
                    .foregroundStyle(LuzzyTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(LuzzyTheme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title).font(.headline)
                    Text("Disponible con Luzzy Premium").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(16)
            .luzzyCard()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPaywall) { PaywallView() }
    }
}

/// Pantalla completa para secciones Premium.
struct PremiumLockedView: View {
    let feature: PremiumFeature
    @State private var showingPaywall = false

    var body: some View {
        ContentUnavailableView {
            Label { Text(feature.title) } icon: { Image(systemName: feature.systemImage) }
        } description: {
            Text("Esta sección forma parte de Luzzy Premium.")
        } actions: {
            Button("Ver Luzzy Premium") { showingPaywall = true }
                .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showingPaywall) { PaywallView() }
    }
}
