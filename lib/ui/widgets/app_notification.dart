import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Interactive notification icon button that toggles between collapsed (icon only)
/// and expanded (full information message) states.
///
/// As requested:
/// - Check icon (✓) replaces green color (success execution).
/// - Silang / cross icon (✕) replaces red color (error/failure execution).
/// - Initially hidden/collapsed showing only the icon button.
/// - When clicked, smoothly shows the notification message.
/// - Clicking again hides/collapses the message back to the icon button.
class NotificationIconButton extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final VoidCallback? onClose;
  final bool initialExpanded;

  const NotificationIconButton({
    super.key,
    required this.message,
    required this.isSuccess,
    this.onClose,
    this.initialExpanded = false,
  });

  @override
  State<NotificationIconButton> createState() => _NotificationIconButtonState();
}

class _NotificationIconButtonState extends State<NotificationIconButton> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = widget.isSuccess ? const Color(0xFF25D366) : Colors.redAccent;
    final iconData = widget.isSuccess ? Icons.check_rounded : Icons.close_rounded;

    return Semantics(
      button: true,
      label: _isExpanded
          ? widget.message
          : (widget.isSuccess
              ? 'Notifikasi berhasil. Ketuk untuk melihat pesan.'
              : 'Notifikasi gagal. Ketuk untuk melihat pesan.'),
      child: Tooltip(
        message: _isExpanded ? 'Ketuk untuk sembunyikan' : 'Ketuk untuk lihat informasi',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(24),
            splashColor: accentColor.withAlpha(30),
            highlightColor: accentColor.withAlpha(15),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: _isExpanded ? 14 : 9,
                    vertical: 9,
                  ),
                  constraints: BoxConstraints(
                    minHeight: 44,
                    maxWidth: MediaQuery.of(context).size.width * 0.88,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF131E24).withAlpha(235)
                        : Colors.white.withAlpha(240),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: accentColor.withAlpha(isDark ? 110 : 160),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withAlpha(isDark ? 45 : 30),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 90 : 35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // The Check / Silang Icon Button
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withAlpha(isDark ? 40 : 25),
                        ),
                        child: Icon(
                          iconData,
                          color: accentColor,
                          size: 17,
                        ),
                      ),

                      // When expanded, show the information text
                      if (_isExpanded) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.unfold_less_rounded,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Global controller to display the interactive show/hide icon button notification
/// floating at the top of the current screen or modal overlay.
class AppNotification {
  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;

  /// Shows the interactive notification icon button.
  ///
  /// - [isSuccess]: true shows check icon (replacing green), false shows silang icon (replacing red).
  /// - Starts in "hide" (collapsed) state. Tap to show message, tap again to hide.
  static void show(
    BuildContext context, {
    required String message,
    required bool isSuccess,
    Duration autoDismissDuration = const Duration(seconds: 5),
  }) {
    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlay == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _FloatingNotificationHost(
        message: message,
        isSuccess: isSuccess,
        onDismiss: () {
          if (_activeEntry == entry) {
            dismiss();
          }
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    _activeTimer = Timer(autoDismissDuration, () {
      if (_activeEntry == entry) {
        dismiss();
      }
    });
  }

  /// Immediately dismisses any active notification.
  static void dismiss() {
    _activeTimer?.cancel();
    _activeTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

class _FloatingNotificationHost extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final VoidCallback onDismiss;

  const _FloatingNotificationHost({
    required this.message,
    required this.isSuccess,
    required this.onDismiss,
  });

  @override
  State<_FloatingNotificationHost> createState() => _FloatingNotificationHostState();
}

class _FloatingNotificationHostState extends State<_FloatingNotificationHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  Future<void> _animateAndDismiss() async {
    if (mounted) {
      await _animController.reverse();
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 14,
      left: 20,
      right: 20,
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: NotificationIconButton(
                message: widget.message,
                isSuccess: widget.isSuccess,
                onClose: _animateAndDismiss,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
