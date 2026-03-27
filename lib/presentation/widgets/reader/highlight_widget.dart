import 'package:flutter/material.dart';

class HighlightColors {
  static const List<Color> colors = [
    Color(0xFFFFEB3B),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
  ];

  static Color getColor(int index) {
    if (index < 0 || index >= colors.length) {
      return colors[0];
    }
    return colors[index];
  }
}

class HighlightWidget extends StatelessWidget {
  final String text;
  final int colorIndex;
  final String? note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const HighlightWidget({
    super.key,
    required this.text,
    required this.colorIndex,
    this.note,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: HighlightColors.getColor(colorIndex).withOpacity(0.4),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            if (note != null && note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.note,
                    size: 12,
                    color: const Color(0xFF009688),
                  ), // Teal for notes
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HighlightSelectionOverlay extends StatelessWidget {
  final String selectedText;
  final String? cfi;
  final Function(int colorIndex)? onHighlight;
  final Function()? onAddNote;
  final Function()? onCopy;
  final Function()? onShare;

  const HighlightSelectionOverlay({
    super.key,
    required this.selectedText,
    this.cfi,
    this.onHighlight,
    this.onAddNote,
    this.onCopy,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedText.length > 50
                ? '${selectedText.substring(0, 50)}...'
                : selectedText,
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          const Text(
            'Highlight Color',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              HighlightColors.colors.length,
              (index) => GestureDetector(
                onTap: () => onHighlight?.call(index),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: HighlightColors.colors[index],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.note_add,
                label: 'Note',
                onTap: onAddNote,
              ),
              _buildActionButton(
                icon: Icons.copy,
                label: 'Copy',
                onTap: onCopy,
              ),
              _buildActionButton(
                icon: Icons.share,
                label: 'Share',
                onTap: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
