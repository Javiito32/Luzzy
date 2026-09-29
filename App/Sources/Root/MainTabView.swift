import SwiftUI

/// Navegación principal. Con el SDK de iOS 26 la barra se dibuja
/// automáticamente como cápsula de Liquid Glass flotante.
struct MainTabView: View {
    let session: Session

    enum TabID: Hashable {
        case home, accounts, transactions, budgets, more
    }

    @State private var selection: TabID = .home

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(session: session, selection: $selection)
                .tabItem { Label("Inicio", systemImage: "house") }
                .tag(TabID.home)

            AccountsView(session: session)
                .tabItem { Label("Cuentas", systemImage: "creditcard") }
                .tag(TabID.accounts)

            TransactionsView(session: session)
                .tabItem { Label("Movimientos", systemImage: "arrow.up.arrow.down") }
                .tag(TabID.transactions)

            BudgetsView(session: session)
                .tabItem { Label("Presupuestos", systemImage: "chart.pie") }
                .tag(TabID.budgets)

            MoreView(session: session)
                .tabItem { Label("Más", systemImage: "ellipsis") }
                .tag(TabID.more)
        }
    }
}
