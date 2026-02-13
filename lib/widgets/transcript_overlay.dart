import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/models/transcript_entry.dart';
import 'package:gov_agent/providers/transcript_provider.dart';

class TranscriptOverlay extends ConsumerWidget {
  const TranscriptOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(transcriptProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Transcript',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const Center(
                  child: Text(
                    'No transcript yet.\nStart speaking to see the conversation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[entries.length - 1 - index];
                    return _TranscriptBubble(entry: entry);
                  },
                ),
        ),
      ],
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  final TranscriptEntry entry;

  const _TranscriptBubble({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isUser = entry.speaker == Speaker.user;
    final isSystem = entry.speaker == Speaker.system;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSystem
                ? Colors.white.withValues(alpha: 0.1)
                : isUser
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF2A2A3E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    isSystem ? 'System' : 'GovAgent',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSystem ? Colors.amber : const Color(0xFF6C63FF),
                    ),
                  ),
                ),
              Text(
                entry.text,
                style: TextStyle(
                  color: isSystem ? Colors.white60 : Colors.white,
                  fontSize: 14,
                  fontStyle: isSystem ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
