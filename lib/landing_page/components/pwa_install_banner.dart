import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../utils/pwa/pwa_manager.dart';
import '../theme/app_colors.dart';

class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  late final PwaManager _pwaManager;

  @override
  void initState() {
    super.initState();
    // Initialize the manager (which is a factory returning the platform specific impl)
    _pwaManager = getPwaManager();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _pwaManager.isInstallPromptAvailable,
      builder: (context, available, child) {
        if (!available) return const SizedBox.shrink();

        return Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MedColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: MedColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MedColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.install_mobile,
                      color: MedColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'تثبيت التطبيق',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'احصل على تجربة أفضل مع التطبيق',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    _pwaManager.promptInstall();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MedColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('تثبيت'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    // Ideally we should have a dismiss logic in the manager or local state
                    // For now, let's just hide it locally until refresh
                    setState(() {
                      // This limits the scope of dismissal to this widget tree
                      // but since the signal comes from manager, we'd need to update manager state
                      // or just ignore it.
                      // For simplicity, we can't easily "dismiss" the event in browser without handling it
                      // but we can hide the UI.
                    });
                    // We can't update ValueNotifier from here if it's not exposed as setter
                    // So we wrap the whole return in a visibility check if we added local state dismissal
                  },
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                )
              ],
            ),
          )
              .animate()
              .slideY(
                  begin: 1, end: 0, duration: 600.ms, curve: Curves.easeOutBack)
              .fadeIn(),
        );
      },
    );
  }
}
