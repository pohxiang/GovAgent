import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/providers/browser_stream_provider.dart';

class BrowserViewer extends ConsumerWidget {
  const BrowserViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frame = ref.watch(browserStreamProvider);

    if (frame == null) {
      return const Center(
        child: Text(
          'Waiting for browser...',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Image.memory(
        frame.imageBytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );
  }
}
