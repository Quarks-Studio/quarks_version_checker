# quarks_version_checker

Detector automático de nuevas versiones para Flutter Web.
Hecho por [Quarks Studio](https://quarks-studio.com).

## Uso

```dart
import 'package:quarks_version_checker/quarks_version_checker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppVersionChecker.instance.start();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => UpdateBanner(child: child!),
      home: HomeScreen(),
    );
  }
}
```

## Configuración requerida en el server

Asegurate de que `/version.json` no se cachee. Para Firebase Hosting,
agregá en `firebase.json`:

```json
{
  "hosting": {
    "headers": [
      {
        "source": "/version.json",
        "headers": [
          { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }
        ]
      }
    ]
  }
}
```