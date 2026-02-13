import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/providers/gemini_session_provider.dart';

class WaveformIndicator extends ConsumerStatefulWidget {
  const WaveformIndicator({super.key});

  @override
  ConsumerState<WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends ConsumerState<WaveformIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<double> _bars = List.filled(20, 0.1);
  final _random = Random();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startAnimating() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      for (int i = 0; i < _bars.length; i++) {
        _bars[i] = 0.1 + _random.nextDouble() * 0.9;
      }
      if (mounted) setState(() {});
    });
  }

  void _stopAnimating() {
    _timer?.cancel();
    _timer = null;
    for (int i = 0; i < _bars.length; i++) {
      _bars[i] = 0.1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(geminiSessionProvider.notifier);
    final isListening = notifier.isListening;

    if (isListening) {
      if (_timer == null) _startAnimating();
    } else {
      if (_timer != null) _stopAnimating();
    }

    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_bars.length, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 3,
            height: 32 * _bars[index],
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: isListening
                  ? const Color(0xFF6C63FF)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
