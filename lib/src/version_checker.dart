import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:web/web.dart' as web;

/// Servicio singleton que detecta cuando el deploy en el server
/// tiene una versión más nueva que la cargada en el cliente.
class AppVersionChecker {
  AppVersionChecker._();
  static final instance = AppVersionChecker._();

  /// Cada cuánto re-chequear mientras la app está abierta.
  Duration checkInterval = const Duration(minutes: 5);

  /// Path al version.json en el server.
  String versionUrl = '/version.json';

  /// Notifica a la UI cuando hay update disponible.
  final updateAvailable = ValueNotifier<bool>(false);

  /// Versión local (la que se compiló en este bundle).
  String localVersion = '';

  /// Versión remota detectada.
  String remoteVersion = '';

  Timer? _timer;
  bool _started = false;

  Future<void> start() async {
    if (!kIsWeb || _started) return;
    _started = true;

    final info = await PackageInfo.fromPlatform();
    localVersion = '${info.version}+${info.buildNumber}';

    await _check();
    _timer = Timer.periodic(checkInterval, (_) => _check());

    // Re-chequea cuando el usuario vuelve a la pestaña.
    web.document.onVisibilityChange.listen((_) {
      if (web.document.visibilityState == 'visible') _check();
    });
  }

  Future<void> _check() async {
    try {
      final bust = DateTime.now().millisecondsSinceEpoch;
      final res = await http.get(
        Uri.parse('$versionUrl?t=$bust'),
        headers: {'Cache-Control': 'no-cache'},
      );
      if (res.statusCode != 200) return;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final v = '${json['version']}+${json['build_number']}';
      remoteVersion = v;

      if (v != localVersion && localVersion.isNotEmpty) {
        updateAvailable.value = true;
      }
    } catch (_) {
      // Silencioso, reintenta en el próximo ciclo.
    }
  }

  void reloadApp() {
    web.window.location.reload();
  }

  void dispose() {
    _timer?.cancel();
    _started = false;
  }
}
