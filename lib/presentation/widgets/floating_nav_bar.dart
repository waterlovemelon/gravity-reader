import 'dart:ui';
import 'package:flutter/material.dart';

class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildNavItem(
              icon: Icons.auto_stories_outlined,
              selectedIcon: Icons.auto_stories_rounded,
              label: '阅读',
              index: 0,
            ),
            _buildNavItem(
              icon: Icons.collections_bookmark_outlined,
              selectedIcon: Icons.collections_bookmark_rounded,
              label: '书架',
              index: 1,
            ),
            _buildNavItem(
              icon: Icons.people_outline_rounded,
              selectedIcon: Icons.people_rounded,
              label: '书友',
              index: 2,
            ),
            _buildNavItem(
              icon: Icons.sentiment_satisfied_alt_outlined,
              selectedIcon: Icons.sentiment_satisfied_alt_rounded,
              label: '我的',
              index: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onIndexChanged(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 18 : 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.black.withOpacity(0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 22,
                color: isSelected
                    ? const Color(0xFF007AFF)
                    : const Color(0xFF8E8E93),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                sizeCurve: Curves.easeOut,
                crossFadeState: isSelected
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF007AFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
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
