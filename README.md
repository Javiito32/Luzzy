# Luzzy

Cliente nativo de iOS para [Firefly III](https://www.firefly-iii.org), con Liquid Glass (iOS 26), centrado en la privacidad.

- **iOS 17+**. En iOS 26 usa Liquid Glass de forma nativa; en 17/18, materiales translúcidos equivalentes.
- **SwiftUI + Swift 6** con concurrencia estricta.
- **Sin dependencias de terceros**, sin analítica y sin publicidad.
- **Freemium** con StoreKit 2: suscripción mensual, anual o compra de por vida.
- Español (idioma base) e inglés.

## Requisitos

- Xcode 26 (compila también con Xcode 16, pero sin Liquid Glass).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.

## Primeros pasos

```bash
xcodegen generate        # crea Luzzy.xcodeproj a partir de project.yml
open Luzzy.xcodeproj
```

1. En *Signing & Capabilities*, elige tu equipo (o rellena `DEVELOPMENT_TEAM` en `project.yml`).
2. Cambia el bundle ID `app.luzzy.ios` si hace falta.
3. Ejecuta en el simulador. El esquema ya usa `App/Resources/Luzzy.storekit` para probar las compras sin App Store Connect.
4. Sin servidor, pulsa **«Probar con datos de ejemplo»** para usar el modo demo.

### Tests

La lógica vive en el paquete `Packages/LuzzyKit` y se prueba con Swift Testing:

```bash
cd Packages/LuzzyKit
swift test
```

Incluye tests de: política de URL (HTTPS y red local), dinero y divisas, validación de borradores, mapeo de la API de Firefly contra fixtures de la especificación v6.7.6, renovación del token tras un 401, errores 422, detección de respuestas HTML, codificación del alta, protección frente a inyección de rutas, PKCE y verificación de `state` en OAuth.

## Conectar con Firefly III

- **Token personal**: en Firefly III › Opciones › Perfil › OAuth › *Personal Access Tokens*.
- **OAuth**: crea un cliente **no confidencial** con la redirección `luzzy://oauth/callback` y usa su *Client ID*. La app nunca guarda un *client secret*.
- **Certificados propios**: si el servidor usa un certificado autofirmado, Luzzy muestra su huella SHA-256 para que la confirmes y solo aceptará ese certificado exacto.
- **HTTP** solo se permite en la red local (IP privadas, `.local` o nombres sin dominio).

## Estructura

```
project.yml                 Definición del proyecto (XcodeGen)
App/                        Target de la app (UI y composición)
  Sources/Core/             AppModel (raíz de composición), sesión, ajustes
  Sources/Features/         Pantallas: Onboarding, Inicio, Cuentas, Movimientos,
                            Presupuestos, Facturas y huchas, Más, Premium
  Resources/                Assets, Localizable.xcstrings, PrivacyInfo, StoreKit
Packages/LuzzyKit/          Lógica modular y testeable
  LuzzyCore                 Dominio y capa de abstracción de datos
  LuzzySecurity             Llavero, PKCE, AES-GCM, Face ID, anclaje TLS
  FireflyAPI                Backend Firefly III (implementa FinanceDataSource)
  LuzzyPersistence          Caché local cifrada (SwiftData)
  LuzzyStore                Suscripciones (StoreKit 2)
  LuzzyUI                   Sistema de diseño (Liquid Glass y alternativa)
docs/                       Arquitectura, privacidad y monetización
```

Más detalle en:
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): capas, abstracción de datos y camino hacia iCloud.
- [`docs/PRIVACY.md`](docs/PRIVACY.md): modelo de amenazas y medidas.
- [`docs/MONETIZATION.md`](docs/MONETIZATION.md): productos, qué es gratis y qué es Premium.
