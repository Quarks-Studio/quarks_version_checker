import 'package:flutter/material.dart';
import 'version_checker.dart';

enum BannerPosition { top, bottom }

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.child,
    this.message = 'Hay una nueva versión disponible',
    this.actionLabel = 'Actualizar',
    this.backgroundColor,
    this.position = BannerPosition.top,
  });

  final Widget child;
  final String message;
  final String actionLabel;
  final Color? backgroundColor;
  final BannerPosition position;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppVersionChecker.instance.updateAvailable,
      builder: (context, hasUpdate, _) {
        return Stack(
          children: [
            child,
            if (hasUpdate)
              Positioned(
                top: position == BannerPosition.top ? 0 : null,
                bottom: position == BannerPosition.bottom ? 0 : null,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Material(
                    elevation: 4,
                    color: backgroundColor ??
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.system_update),
                          const SizedBox(width: 12),
                          Expanded(child: Text(message)),
                          FilledButton(
                            onPressed: AppVersionChecker.instance.reloadApp,
                            child: Text(actionLabel),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
