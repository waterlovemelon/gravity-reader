import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BrightnessControlWidget extends StatefulWidget {
  final double initialBrightness;
  final Function(double)? onBrightnessChanged;

  const BrightnessControlWidget({
    super.key,
    this.initialBrightness = 0.5,
    this.onBrightnessChanged,
  });

  @override
  State<BrightnessControlWidget> createState() =>
      _BrightnessControlWidgetState();
}

class _BrightnessControlWidgetState extends State<BrightnessControlWidget> {
  late double _brightness;

  @override
  void initState() {
    super.initState();
    _brightness = widget.initialBrightness;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSystemBrightness(_brightness);
  }

  void _updateSystemBrightness(double value) {
    final isLight = value > 0.5;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Brightness',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.brightness_low),
              Expanded(
                child: Slider(
                  value: _brightness,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) {
                    setState(() {
                      _brightness = value;
                    });
                    _updateSystemBrightness(value);
                    widget.onBrightnessChanged?.call(value);
                  },
                ),
              ),
              const Icon(Icons.brightness_high),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${(_brightness * 100).toInt()}%',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
