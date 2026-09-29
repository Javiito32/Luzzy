// swift-tools-version: 6.0
import PackageDescription

// LuzzyKit agrupa toda la lógica de la app en módulos independientes de la UI.
//
// Dependencias (de abajo arriba):
//   LuzzyCore  ← dominio puro + abstracción de datos (sin dependencias)
//   LuzzySecurity ← Llavero, PKCE, cifrado, bloqueo, pinning TLS
//   FireflyAPI ← backend Firefly III (implementa FinanceDataSource)
//   LuzzyPersistence ← caché local cifrada (SwiftData)
//   LuzzyStore ← suscripciones con StoreKit 2
//   LuzzyUI ← sistema de diseño (Liquid Glass con alternativa para iOS 17)
//
// Sin dependencias de terceros: es una decisión de privacidad, no de comodidad.
let package = Package(
    name: "LuzzyKit",
    defaultLocalization: "es",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LuzzyCore", targets: ["LuzzyCore"]),
        .library(name: "LuzzySecurity", targets: ["LuzzySecurity"]),
        .library(name: "FireflyAPI", targets: ["FireflyAPI"]),
        .library(name: "LuzzyPersistence", targets: ["LuzzyPersistence"]),
        .library(name: "LuzzyStore", targets: ["LuzzyStore"]),
        .library(name: "LuzzyUI", targets: ["LuzzyUI"]),
    ],
    targets: [
        .target(name: "LuzzyCore"),
        .target(name: "LuzzySecurity", dependencies: ["LuzzyCore"]),
        .target(name: "FireflyAPI", dependencies: ["LuzzyCore", "LuzzySecurity"]),
        .target(name: "LuzzyPersistence", dependencies: ["LuzzyCore", "LuzzySecurity"]),
        .target(name: "LuzzyStore", dependencies: ["LuzzyCore"]),
        .target(name: "LuzzyUI", dependencies: ["LuzzyCore"]),
        .testTarget(name: "LuzzyCoreTests", dependencies: ["LuzzyCore"]),
        .testTarget(
            name: "FireflyAPITests",
            dependencies: ["FireflyAPI", "LuzzyCore", "LuzzySecurity"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
