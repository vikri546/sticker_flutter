import 'package:flutter/material.dart';

/// Floating capsule/pill-shaped bottom navigation bar.
///
/// Faithfully reproduces the pill navbar design:
/// - Light theme: Pure white capsule container with subtle shadow.
/// - Selected tab: Warm golden-amber pill capsule with rich dark-brown text and icon.
/// - Unselected tab: Transparent background with dark-brown text and icon.
class FloatingPillNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingPillNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const Color activeCapsuleColor = Color(0xFFF09A06);
  static const Color activeTextColor = Color(0xFF3B1E00);
  static const Color inactiveTextColor = Color(0xFF3B1E00);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2B32) : Colors.transparent,
        borderRadius: BorderRadius.circular(40),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillTabItem(
            icon: Icons.grid_view_rounded,
            label: 'Explore',
            isSelected: selectedIndex == 0,
            isDark: isDark,
            onTap: () => onTabSelected(0),
          ),
          const SizedBox(width: 4),
          _PillTabItem(
            icon: Icons.account_circle_outlined,
            label: 'Account',
            isSelected: selectedIndex == 1,
            isDark: isDark,
            onTap: () => onTabSelected(1),
          ),
        ],
      ),
    );
  }
}

class _PillTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PillTabItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? FloatingPillNavBar.activeTextColor
        : (isDark ? Colors.grey[300]! : FloatingPillNavBar.inactiveTextColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        splashColor: FloatingPillNavBar.activeCapsuleColor.withAlpha(40),
        highlightColor: FloatingPillNavBar.activeCapsuleColor.withAlpha(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? FloatingPillNavBar.activeCapsuleColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(32),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: FloatingPillNavBar.activeCapsuleColor.withAlpha(60),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: textColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
