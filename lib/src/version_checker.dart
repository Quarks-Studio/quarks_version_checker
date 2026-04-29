import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:web/web.dart' as web;

/// Callback que se ejecuta justo antes de recargar la app.
///
/// - Devolver `true` permite que la recarga proceda.
/// - Devolver `false` cancela la recarga (ej: el usuario tiene cambios
///   sin guardar y prefiere quedarse en la versión actual).
typedef BeforeReloadCallback = Future<bool> Function();

/// Servicio singleton que detecta cuando el deploy tiene una versión
/// más nueva que la cargada en el cliente y recarga la app automáticamente
/// en un momento seguro (cambio de foco de la pestaña).
class AppVersionChecker {
  AppVersionChecker._();
  static final instance = AppVersionChecker._();

  /// Cada cuánto re-chequear mientras la app está abierta.
  Duration checkInterval = const Duration(minutes: 5);

  /// Path al version.json en el server.
  String versionUrl = '/version.json';

  /// Si true, recarga automáticamente cuando se detecta una versión nueva.
  /// La recarga ocurre cuando la pestaña cambia de visibilidad
  /// (el usuario se va o vuelve), así no se interrumpe lo que esté haciendo.
  bool autoReload = true;

  /// Si true, recarga apenas detecta el update sin esperar al cambio
  /// de visibilidad. Útil para updates críticos, pero puede interrumpir.
  bool reloadImmediately = false;

  /// Si true, desregistra el service worker antes de recargar para
  /// garantizar que la próxima carga traiga el bundle nuevo.
  /// Setealo en false si tu app no usa service worker.
  bool unregisterServiceWorker = true;

  /// Hook opcional que se ejecuta antes de cada recarga.
  /// Si devuelve `false`, la recarga se cancela y se vuelve a intentar
  /// en el próximo cambio de visibilidad. Útil para guardar borradores,
  /// confirmar con el usuario, o flushear caches locales.
  BeforeReloadCallback? onBeforeReload;

  /// Notifica a la UI cuando hay update disponible.
  /// Útil si querés mostrar un banner además de —o en lugar de—
  /// la recarga automática.
  final updateAvailable = ValueNotifier<bool>(false);

  /// Versión local (la que se compiló en este bundle).
  String localVersion = '';

  /// Versión remota detectada.
  String remoteVersion = '';

  Timer? _timer;
  bool _started = false;
  bool _reloading = false;

  Future<void> start() async {
    if (!kIsWeb || _started) return;
    _started = true;

    final info = await PackageInfo.fromPlatform();
    localVersion = '${info.version}+${info.buildNumber}';

    await _check();
    _timer = Timer.periodic(checkInterval, (_) => _check());

    // En cada cambio de visibilidad: si hay update, recargamos.
    // Cuando vuelve al foco además re-chequeamos por las dudas.
    web.document.onVisibilityChange.listen((_) async {
      if (web.document.visibilityState == 'visible') {
        await _check();
      }
      await _maybeReload();
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
        if (reloadImmediately) await reloadApp();
      }
    } catch (_) {
      // Silencioso, reintenta en el próximo ciclo.
    }
  }

  Future<void> _maybeReload() async {
    if (updateAvailable.value && autoReload) await reloadApp();
  }

  /// Recarga la app después de:
  /// 1. Ejecutar `onBeforeReload` (si está seteado y no cancela).
  /// 2. Desregistrar el service worker (si `unregisterServiceWorker` es true).
  /// 3. Llamar a `window.location.reload()`.
  Future<void> reloadApp() async {
    if (_reloading) return;
    _reloading = true;

    try {
      final cb = onBeforeReload;
      if (cb != null) {
        final proceed = await cb();
        if (!proceed) {
          _reloading = false;
          return;
        }
      }

      if (unregisterServiceWorker) {
        await _unregisterServiceWorkers();
      }

      web.window.location.reload();
    } catch (_) {
      // Si algo falla en el pre-reload, igual recargamos.
      web.window.location.reload();
    }
  }

  Future<void> _unregisterServiceWorkers() async {
    try {
      final regs =
          await web.window.navigator.serviceWorker.getRegistrations().toDart;
      for (final reg in regs.toDart) {
        await reg.unregister().toDart;
      }
    } catch (_) {
      // Si el navegador no soporta SW o falla, seguimos con el reload.
    }
  }

  void dispose() {
    _timer?.cancel();
    _started = false;
  }
}
