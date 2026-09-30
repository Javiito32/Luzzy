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

La regla se aplica en la capa de app (`AccessScope`), por encima de la abstracción de datos, así que rige **igual con Firefly III que con el futuro modo iCloud**.

**Gratis: una cuenta**
- El usuario elige **una cuenta de activo** al empezar (se guarda con el perfil del servidor, en el Llavero). Puede cambiarla desde Cuentas o Más.
- Inicio con el saldo de esa cuenta, lo gastado y lo ingresado en el mes, y sus últimos movimientos.
- Movimientos de esa cuenta: consultar, buscar, filtrar, crear **gastos e ingresos** (con categoría, etiquetas y notas) y borrarlos.
- Toda la privacidad: bloqueo con Face ID, modo discreto y caché cifrada.

**Premium** (`PremiumFeature`)
- Todas las cuentas (activos, gastos, ingresos, pasivos) y el patrimonio neto.
- Transferencias entre cuentas.
- Presupuestos, facturas y huchas.
- Movimientos divididos.
- Gestión de categorías y etiquetas.
- Automatismos (próximamente): reglas y movimientos recurrentes.
- Próximamente: informes, widgets y varios servidores.

## Implementación

- `PurchaseManager` (`@MainActor @Observable`):
  - escucha `Transaction.updates` desde el arranque;
  - calcula el derecho con `Transaction.currentEntitlements`, que funciona sin conexión;
  - ignora las transacciones no verificadas o revocadas;
  - la compra de por vida tiene prioridad sobre las suscripciones.
- `PaywallView` usa `SubscriptionStoreView` (interfaz nativa de Apple, con precios localizados, restauración y enlaces legales) y un botón para la compra de por vida.
- Gestión de la suscripción: `manageSubscriptionsSheet` desde Más.
- La comprobación de funciones pasa por `purchases.isUnlocked(_:)`. El límite de una cuenta lo aplica `AppModel.accessScope` (`.full` o `.singleAccount(id)`): Inicio, Cuentas, Movimientos y el formulario de alta se adaptan a él.
- El arranque espera a que StoreKit resuelva el plan (es local) para no mostrar la vista equivocada ni un instante.

## Pasos en App Store Connect

1. Crear el grupo de suscripciones «Luzzy Premium» con los dos niveles (el anual en el nivel 1 para que se muestre como recomendado).
2. Crear el no consumible de por vida.
3. Activar la opción de compartir en familia si se desea (en el `.storekit` está activada).
4. Rellenar la etiqueta de privacidad: «Datos no recopilados».
5. Publicar `legal/privacy-policy.md` (rellenando nombre y email) y actualizar `AppConfiguration.privacyPolicyURL`. Los términos son el EULA estándar de Apple.
