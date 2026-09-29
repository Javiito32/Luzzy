# Monetización

Modelo **freemium** con StoreKit 2 puro: sin servidores propios y sin terceros (ni RevenueCat ni similares). La verificación de compras se hace en el dispositivo con la firma JWS de Apple.

## Productos

| Producto | ID | Tipo | Precio provisional |
|---|---|---|---|
| Premium mensual | `luzzy.premium.monthly` | Suscripción autorrenovable (grupo «Luzzy Premium») | 2,99 € |
| Premium anual | `luzzy.premium.yearly` | Suscripción autorrenovable, 2 semanas de prueba | 24,99 € |
| Premium de por vida | `luzzy.premium.lifetime` | No consumible | 59,99 € |

Los precios son provisionales: se fijan en App Store Connect. Los IDs están en `AppConfiguration.store` y en `App/Resources/Luzzy.storekit`, y deben coincidir.

## Gratis y Premium

**Gratis**
- Conexión (token u OAuth) y demo.
- Inicio, cuentas y detalle de cuenta.
- Movimientos: consultar, buscar, filtrar, crear y borrar movimientos simples.
- Bloqueo con Face ID, modo discreto, caché cifrada y todo lo relativo a privacidad.

**Premium** (`PremiumFeature`)
- Presupuestos (pantalla y asignación al crear movimientos).
- Facturas y huchas.
- Movimientos divididos.
- Categorías y etiquetas (pantallas de gestión).
- Próximamente: reglas, informes, widgets, varios servidores y modo sin servidor con iCloud.

## Implementación

- `PurchaseManager` (`@MainActor @Observable`):
  - escucha `Transaction.updates` desde el arranque;
  - calcula el derecho con `Transaction.currentEntitlements`, que funciona sin conexión;
  - ignora las transacciones no verificadas o revocadas;
  - la compra de por vida tiene prioridad sobre las suscripciones.
- `PaywallView` usa `SubscriptionStoreView` (interfaz nativa de Apple, con precios localizados, restauración y enlaces legales) y un botón para la compra de por vida.
- Gestión de la suscripción: `manageSubscriptionsSheet` desde Más.
- La comprobación siempre pasa por `purchases.isUnlocked(_:)`, así que se puede afinar por función sin tocar las pantallas.

## Pasos en App Store Connect

1. Crear el grupo de suscripciones «Luzzy Premium» con los dos niveles (el anual en el nivel 1 para que se muestre como recomendado).
2. Crear el no consumible de por vida.
3. Activar la opción de compartir en familia si se desea (en el `.storekit` está activada).
4. Rellenar la etiqueta de privacidad: «Datos no recopilados».
5. Publicar la política de privacidad y los términos, y actualizar `AppConfiguration`.
