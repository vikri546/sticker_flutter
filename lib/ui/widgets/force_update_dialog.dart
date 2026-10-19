import 'package:flutter/material.dart';
import 'package:sticker_flutter/services/app_update_service.dart';

/// Modal dialog strictly enforcing an application update.
/// Designed to precisely match the clean iOS-style alert popup.
class ForceUpdateDialog extends StatelessWidget {
  final String title;
  final String message;
  final String updateUrl;
  final VoidCallback? onUpdatePressed;

  const ForceUpdateDialog({
    super.key,
    this.title = 'New version available',
    this.message = 'There are new features available,\nplease update your app',
    this.updateUrl = AppUpdateService.defaultStoreUrl,
    this.onUpdatePressed,
  });

  void _handleUpdate(BuildContext context) {
    if (onUpdatePressed != null) {
      onUpdatePressed!();
    } else {
      AppUpdateService.launchUpdateUrl(updateUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope prevents back button or swipe-to-dismiss
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        elevation: 0,
        child: Container(
          width: 270,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header & Text Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3C3C43),
                        height: 1.35,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Thin Divider
              const Divider(
                height: 1,
                thickness: 0.8,
                color: Color(0xFFD1D1D6),
              ),

              // Action Button ("Update")
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _handleUpdate(context),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007AFF),
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
