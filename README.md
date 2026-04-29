# quarks_version_checker

Detector automático de nuevas versiones para Flutter Web. Cuando hacés un nuevo deploy, las pestañas abiertas se actualizan solas en un momento seguro — sin pop-ups, sin que el usuario tenga que hacer nada.

Hecho por [Quarks Studio](https://quarks-studio.com).

## Cómo funciona

1. La librería compara la versión local del bundle con un `version.json` que servís junto a tu app.
2. Si detecta una versión nueva, espera a un **momento seguro** — cuando el usuario cambia de pestaña — y recarga.
3. Antes de recargar, desregistra el service worker para garantizar que se baje el bundle nuevo (no la versión cacheada).
4. Opcionalmente podés ejecutar un hook (`onBeforeReload`) para guardar borradores o cancelar la recarga si el usuario tiene cambios sin guardar.

## Uso básico

```dart
import 'package:quarks_version_checker/quarks_version_checker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppVersionChecker.instance.start();
  runApp(const MyApp());
}
```

Listo. La app se actualiza sola cuando hay deploy nuevo.

## Generar `version.json` en cada build

El `version.json` tiene que reflejar lo que está en `pubspec.yaml`. Lo más simple es generarlo en tu script de deploy, después de `flutter build web`:

```bash
flutter build web --release

VERSION_LINE=$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d ' ')
VERSION="${VERSION_LINE%+*}"
BUILD="${VERSION_LINE#*+}"

cat > build/web/version.json <<EOF
{ "version": "$VERSION", "build_number": "$BUILD" }
EOF
```

## Hook `onBeforeReload`

Para guardar estado, confirmar con el usuario, o cancelar la recarga:

```dart
AppVersionChecker.instance.onBeforeReload = () async {
  // Guardar borradores, flushear caches, etc.
  await draftService.flush();

  // Si hay cambios sin guardar, preguntarle al usuario.
  if (formController.hasUnsavedChanges) {
    final confirm = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (_) => AlertDialog(
        title: const Text('Hay una nueva versión'),
        content: const Text('Tenés cambios sin guardar. ¿Actualizar igual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Después'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  return true; // procede con la recarga
};
```

Si devolvés `false` la recarga se cancela y se vuelve a intentar en el próximo cambio de pestaña.

## Banner manual (opcional)

Si preferís mostrar un cartel y dejar que el usuario decida cuándo actualizar, desactivá el auto-reload y usá el `UpdateBanner`:

```dart
AppVersionChecker.instance.autoReload = false;

MaterialApp(
  builder: (context, child) => UpdateBanner(child: child!),
  home: const HomeScreen(),
);
```

## Configuración

```dart
final checker = AppVersionChecker.instance;

checker.checkInterval = const Duration(minutes: 5);  // cada cuánto pollear
checker.versionUrl = '/version.json';                // path al endpoint
checker.autoReload = true;                           // reload en cambio de foco
checker.reloadImmediately = false;                   // reload sin esperar foco
checker.unregisterServiceWorker = true;              // desregistrar SW pre-reload
checker.onBeforeReload = () async => true;           // hook pre-reload
```

## Configuración requerida en el server

Para que el reload realmente traiga la versión nueva (y no la cacheada), estos archivos **no deben cachearse**. En Firebase Hosting:

```json
{
  "hosting": {
    "headers": [
      {
        "source": "/version.json",
        "headers": [
          { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }
        ]
      },
      {
        "source": "/index.html",
        "headers": [
          { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }
        ]
      },
      {
        "source": "/flutter_service_worker.js",
        "headers": [
          { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }
        ]
      },
      {
        "source": "/flutter_bootstrap.js",
        "headers": [
          { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }
        ]
      }
    ]
  }
}
```

Los assets con hash en el nombre (`main.dart.js`, fonts, imágenes del build) pueden cachearse normal — el service worker se encarga de invalidarlos cuando cambia `flutter_service_worker.js`.
