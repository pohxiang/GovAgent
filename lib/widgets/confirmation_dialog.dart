import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/providers/gemini_session_provider.dart';
import 'package:gov_agent/providers/tool_call_provider.dart';

class ConfirmationDialog extends ConsumerWidget {
  const ConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolCall = ref.watch(toolCallProvider);

    if (toolCall == null) {
      // Auto-dismiss if cleared
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: Colors.amber,
        size: 48,
      ),
      title: const Text(
        'Confirm Submission',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GovAgent wants to submit a form on your behalf.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action: ${toolCall.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (toolCall.arguments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...toolCall.arguments.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(geminiSessionProvider.notifier).rejectToolCall();
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(geminiSessionProvider.notifier).confirmToolCall(toolCall);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
