# Privacidad y seguridad

Luzzy gestiona datos financieros de un servidor que el usuario controla. El objetivo es que **nada salga del eje iPhone ↔ servidor del usuario** y que un dispositivo perdido, una copia de seguridad o una red hostil no expongan datos.

## Principios

1. **Sin terceros.** Cero SDKs externos: sin analítica, sin informes de fallos de terceros, sin anuncios. Solo hay tráfico hacia el servidor del usuario y hacia Apple (StoreKit).
2. **Mínimo en disco.** Solo se guarda lo necesario para funcionar sin conexión, siempre cifrado.
3. **La privacidad no es de pago.** El bloqueo, el modo discreto y la protección de datos son gratuitos.

## Modelo de amenazas y medidas

| Amenaza | Medida | Dónde |
|---|---|---|
| Robo o pérdida del iPhone | Protección de datos `NSFileProtectionComplete` para toda la app (entitlement) y bloqueo con Face ID, Touch ID o código | `Luzzy.entitlements`, `AppLockAuthenticator` |
| Extracción del token | Llavero con `WhenUnlockedThisDeviceOnly`, sin sincronizar con iCloud y sin migrar a otros dispositivos | `KeychainStore` |
| Copias de seguridad (iCloud/Finder) | La caché queda excluida (`isExcludedFromBackup`) y su clave nunca sale del dispositivo | `ProtectedLocation`, `DataCipher` |
| Lectura de la base de datos de caché | Cada entrada cifrada con AES-256-GCM y una clave aleatoria guardada en el Llavero | `EncryptedSnapshotCache` |
| Captura del selector de apps | Pantalla de privacidad al pasar a inactiva o a segundo plano | `PrivacyShieldView` |
| Miradas indiscretas | Modo discreto que oculta todos los importes | `MoneyText`, `amountsHidden` |
| Red hostil (MITM) | HTTPS obligatorio (ATS). HTTP solo en red local. TLS ≥ 1.2. Anclaje opcional del certificado | `ServerURLPolicy`, `URLSessionTransport`, `ServerTrustDelegate` |
| Certificados autofirmados | Confianza explícita en la huella SHA-256 tras confirmarla el usuario (TOFU). Solo se acepta ese certificado y solo para ese host | `CertificateInspector`, `.pinnedOnly` |
| Rastro de red | Sesión efímera, sin caché HTTP, sin cookies, sin almacén de credenciales y con un User-Agent genérico | `URLSessionTransport` |
| Robo del código OAuth | PKCE S256, `state` aleatorio verificado, sesión web efímera sin cookies y sin *client secret* | `FireflyOAuthClient`, `WebAuthenticator` |
| Secuestro del esquema URL | No se registra `luzzy://` en Info.plist: solo lo recibe `ASWebAuthenticationSession` | `Info.plist` |
| Inyección de rutas | Los IDs se sanean antes de formar la URL | `FireflyRepository.pathSafe` |
| URLs con credenciales | Se rechazan las URL con `user:pass@` | `ServerURLPolicy` |
| Filtración en mensajes o registros | Los errores se normalizan y los mensajes no incluyen tokens, URLs ni importes. No se registra nada con `print` | `DataSourceError.userMessage` |

## Qué se guarda y dónde

| Dato | Ubicación | Protección |
|---|---|---|
| Token personal o tokens OAuth | Llavero | Solo en este dispositivo y solo con el iPhone desbloqueado |
| Perfil del servidor (URL, método de acceso, huella anclada) | Llavero | Igual que el anterior |
| Clave de la caché | Llavero | Igual que el anterior |
| Instantáneas (saldos, movimientos…) | Application Support/LuzzyCache | AES-GCM, protección completa y fuera de las copias |
| Preferencias (bloqueo, modo discreto) | UserDefaults | Sin datos personales |

## Borrado

- **Desconectar servidor**: elimina el token, el perfil, la caché y su clave.
- **Ajustes › Privacidad › Borrar todos los datos**: vacía el Llavero de la app, la caché y las preferencias.

## App Store

- `PrivacyInfo.xcprivacy`: sin rastreo, sin tipos de datos recogidos y con un único motivo de API requerida (UserDefaults, `CA92.1`).
- Etiqueta de privacidad de la ficha: **«Datos no recopilados»**.
- `ITSAppUsesNonExemptEncryption = false`: solo se usa la criptografía del sistema para proteger datos del usuario.

## Pendiente antes de publicar

- [ ] Publicar la política de privacidad y actualizar `AppConfiguration.privacyPolicyURL`.
- [ ] Revisión externa de seguridad (auditoría del flujo OAuth y del anclaje TLS).
- [ ] Probar el bloqueo con los tiempos «tras X minutos» en un dispositivo real.
