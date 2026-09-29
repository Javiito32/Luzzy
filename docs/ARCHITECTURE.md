# Arquitectura

## Capas

```
┌──────────────────────────── App (SwiftUI) ────────────────────────────┐
│  Features/*View  ──►  modelos @Observable  ──►  Session               │
│                                                  │                    │
│  AppModel (raíz de composición: sesión, bloqueo, compras, perfiles)   │
└──────────────────────────────────────────────────┼────────────────────┘
                                                   ▼
                              LuzzyCore: FinanceDataSource (protocolos)
                        ┌──────────────┬───────────┴──────────┬──────────────────┐
                        ▼              ▼                      ▼                  ▼
                FireflyDataSource  DemoDataSource   (futuro) CloudDataSource  SnapshotCache
                 (API REST v1)     (en memoria)     SwiftData + CloudKit     (LuzzyPersistence)
```

- **LuzzyCore** no depende de nada: modelos de dominio (`Account`, `TransactionGroup`, `Budget`, `Bill`, `PiggyBank`…), `Money` con `Decimal` (nunca `Double`), errores normalizados (`DataSourceError`) y los protocolos de acceso a datos.
- **La UI solo conoce `FinanceDataSource`**, nunca `FireflyClient` ni los DTO. Todas las pantallas funcionan igual con `DemoDataSource`, y así se demuestra que la abstracción es real.
- Los **DTO de Firefly** son privados del módulo `FireflyAPI`. Toda la tolerancia a versiones (campos `pc_*`, `subscriptions` frente a `bills`, `spent` como lista o como texto…) está en `FireflyMapping`.

## La abstracción de datos

```swift
public protocol FinanceDataSource: Sendable {
    var kind: DataSourceKind { get }              // .firefly, .demo, .iCloud
    var capabilities: DataSourceCapabilities { get }
    var accounts: any AccountRepository { get }
    var transactions: any TransactionRepository { get }
    var budgets: any BudgetRepository { get }
    var categories: any CategoryRepository { get }
    var bills: any BillRepository { get }
    var piggyBanks: any PiggyBankRepository { get }
    var tags: any TagRepository { get }
    var summary: any SummaryRepository { get }
    func info() async throws -> DataSourceInfo
}
```

- Las escrituras usan `TransactionDraft`, un borrador independiente del backend y con validación local (`validate()`).
- `DataSourceCapabilities` indica qué funciones existen en cada backend. Por ejemplo, las reglas y los webhooks son propios de Firefly: las futuras pantallas de reglas se mostrarán solo si el backend declara `.rules`.

### Camino hacia la versión sin servidor (iCloud)

1. Crear el módulo `LuzzyCloud` con modelos SwiftData persistentes (distintos de la caché) y `ModelConfiguration(cloudKitDatabase: .private("iCloud.<bundle>"))`.
2. Implementar `CloudDataSource: FinanceDataSource`. El resumen, los presupuestos y las facturas se calculan en local (el `DemoStore` sirve de referencia).
3. Añadir `DataSourceKind.iCloud` como opción en el onboarding (Premium: `PremiumFeature.iCloudSync`).
4. Opcional: importar desde Firefly usando el `FireflyDataSource` existente como origen.

No hace falta tocar ninguna pantalla: `Session` recibe otro `FinanceDataSource`.

## Caché y funcionamiento sin conexión

`CachedFetcher` aplica la estrategia «muestra lo guardado y actualiza»: primero muestra la instantánea cifrada (si existe) y después la sustituye por la respuesta del servidor. Si el servidor falla, la pantalla conserva los datos guardados y muestra un aviso con «Reintentar» (`Loadable.failed(_, previous:)`).

La caché es por perfil y está en `LuzzyPersistence/EncryptedSnapshotCache` (detalles en PRIVACY.md).

## Diseño (Liquid Glass)

- `luzzyGlass(in:tint:)` usa `glassEffect` en iOS 26 (`#if compiler(>=6.2)` y `#available`) y un material translúcido con brillo de borde en iOS 17 y 18.
- El cristal se usa **solo para la capa de controles**: barra de pestañas, botones de la barra superior, avisos flotantes y pastillas sobre la tarjeta de patrimonio. El contenido va en tarjetas sólidas (`luzzyCard`), como recomienda Apple.
- `TabView`, las barras de navegación y las hojas adoptan Liquid Glass automáticamente al compilar con el SDK de iOS 26.

## Concurrencia

- Swift 6 con `SWIFT_STRICT_CONCURRENCY = complete`.
- Los modelos de UI son `@MainActor @Observable`. Los repositorios son `Sendable`: structs inmutables o actores (`DemoStore`, `KeychainFireflyAuthorizer`, `EncryptedSnapshotCache`).
- La renovación de tokens OAuth se agrupa en una única tarea compartida (*single-flight*).

## Hoja de ruta

- [ ] Edición de movimientos existentes (el repositorio ya soporta `update`).
- [ ] Informes con Swift Charts (`/v1/insight/*`).
- [ ] Reglas y transacciones recurrentes (solo Firefly).
- [ ] Widgets e intents de Atajos (los datos se comparten con la extensión por App Group, cifrados).
- [ ] Varios servidores (`ServerProfileStore` ya guarda una lista).
- [ ] Modo sin servidor con iCloud.
- [ ] Tests de UI y de snapshot.
