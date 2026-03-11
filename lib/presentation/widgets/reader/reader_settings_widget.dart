import 'package:flutter/material.dart';

enum ReadingTheme { light, dark, sepia, night }

class ReaderSettingsWidget extends StatefulWidget {
  final ReadingTheme currentTheme;
  final double fontSize;
  final String fontFamily;
  final double lineHeight;
  final Function(ReadingTheme)? onThemeChanged;
  final Function(double)? onFontSizeChanged;
  final Function(String)? onFontFamilyChanged;
  final Function(double)? onLineHeightChanged;

  const ReaderSettingsWidget({
    super.key,
    required this.currentTheme,
    required this.fontSize,
    required this.fontFamily,
    required this.lineHeight,
    this.onThemeChanged,
    this.onFontSizeChanged,
    this.onFontFamilyChanged,
    this.onLineHeightChanged,
  });

  @override
  State<ReaderSettingsWidget> createState() => _ReaderSettingsWidgetState();
}

class _ReaderSettingsWidgetState extends State<ReaderSettingsWidget> {
  late ReadingTheme _selectedTheme;
  late double _fontSize;
  late String _fontFamily;
  late double _lineHeight;

  final List<String> _fontFamilies = ['System Default', 'Serif', 'Sans-Serif'];

  @override
  void initState() {
    super.initState();
    _selectedTheme = widget.currentTheme;
    _fontSize = widget.fontSize;
    _fontFamily = widget.fontFamily;
    _lineHeight = widget.lineHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Reading Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildThemeOption(
                ReadingTheme.light,
                Colors.white,
                Colors.black87,
                'Light',
              ),
              _buildThemeOption(
                ReadingTheme.dark,
                Colors.grey[900]!,
                Colors.white,
                'Dark',
              ),
              _buildThemeOption(
                ReadingTheme.sepia,
                const Color(0xFFF5E6C8),
                Colors.brown,
                'Sepia',
              ),
              _buildThemeOption(
                ReadingTheme.night,
                Colors.grey[800]!,
                Colors.grey[300]!,
                'Night',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Font Size',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _fontSize,
            min: 12,
            max: 32,
            divisions: 10,
            label: '${_fontSize.toInt()}',
            onChanged: (value) {
              setState(() {
                _fontSize = value;
              });
              widget.onFontSizeChanged?.call(value);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Font Family',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: _fontFamilies
                .map((font) => ButtonSegment(value: font, label: Text(font)))
                .toList(),
            selected: {_fontFamily},
            onSelectionChanged: (selection) {
              setState(() {
                _fontFamily = selection.first;
              });
              widget.onFontFamilyChanged?.call(_fontFamily);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Line Spacing',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _lineHeight,
            min: 1.0,
            max: 2.5,
            divisions: 6,
            label: _lineHeight.toStringAsFixed(1),
            onChanged: (value) {
              setState(() {
                _lineHeight = value;
              });
              widget.onLineHeightChanged?.call(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    ReadingTheme theme,
    Color bgColor,
    Color textColor,
    String label,
  ) {
    final isSelected = _selectedTheme == theme;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTheme = theme;
        });
        widget.onThemeChanged?.call(theme);
      },
      child: Container(
        width: 60,
        height: 80,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: textColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
