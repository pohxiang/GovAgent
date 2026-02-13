import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/models/session_state.dart';
import 'package:gov_agent/providers/browser_stream_provider.dart';
import 'package:gov_agent/providers/gemini_session_provider.dart';
import 'package:gov_agent/providers/tool_call_provider.dart';
import 'package:gov_agent/widgets/browser_viewer.dart';
import 'package:gov_agent/widgets/confirmation_dialog.dart';
import 'package:gov_agent/widgets/mic_button.dart';
import 'package:gov_agent/widgets/status_overlay.dart';
import 'package:gov_agent/widgets/transcript_overlay.dart';
import 'package:gov_agent/widgets/waveform_indicator.dart';

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(geminiSessionProvider);
    final pendingToolCall = ref.watch(toolCallProvider);
    final browserFrame = ref.watch(browserStreamProvider);

    // Show confirmation dialog when needed
    if (pendingToolCall != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ConfirmationDialog(),
        );
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _endSession(context, ref);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _endSession(context, ref),
                    ),
                    const Spacer(),
                    _ConnectionIndicator(sessionState: sessionState),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: const Color(0xFF1A1A2E),
                          builder: (_) => const FractionallySizedBox(
                            heightFactor: 0.6,
                            child: TranscriptOverlay(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Browser viewer
              Expanded(
                child: browserFrame != null
                    ? Stack(
                        children: [
                          const BrowserViewer(),
                          if (browserFrame.actionLabel != null)
                            Positioned(
                              top: 8,
                              left: 8,
                              right: 8,
                              child: StatusOverlay(label: browserFrame.actionLabel!),
                            ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.web,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Browser will appear here\nwhen navigating',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // Bottom controls
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D1A),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WaveformIndicator(),
                    SizedBox(height: 16),
                    MicButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _endSession(BuildContext context, WidgetRef ref) async {
    await ref.read(geminiSessionProvider.notifier).endSession();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _ConnectionIndicator extends StatelessWidget {
  final SessionState sessionState;

  const _ConnectionIndicator({required this.sessionState});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (sessionState) {
      SessionState.active => (Colors.greenAccent, 'Connected'),
      SessionState.connecting => (Colors.amber, 'Connecting...'),
      SessionState.error => (Colors.redAccent, 'Error'),
      SessionState.idle => (Colors.grey, 'Idle'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
