## 1.1.0

- Recarga automática al cambiar de foco de la pestaña (default: activado).
- Hook `onBeforeReload` para guardar estado o cancelar la recarga.
- Desregistrado automático del service worker antes del reload, para evitar servir el bundle viejo desde cache.
- Nuevos flags: `autoReload`, `reloadImmediately`, `unregisterServiceWorker`.
- El banner manual sigue funcionando seteando `autoReload = false`.

## 1.0.0

- Versión inicial.
- Detección automática de nuevas versiones en Flutter Web.
- Widget UpdateBanner reutilizable.
- Re-check al volver al foco de la pestaña.
