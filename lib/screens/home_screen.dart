import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/providers/gemini_session_provider.dart';
import 'package:gov_agent/screens/session_screen.dart';
import 'package:gov_agent/models/session_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(geminiSessionProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.support_agent,
                  size: 96,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(height: 24),
                Text(
                  'GovAgent',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your AI assistant for Malaysian\ngovernment services',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: sessionState == SessionState.connecting
                        ? null
                        : () => _startSession(context, ref),
                    icon: sessionState == SessionState.connecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.mic),
                    label: Text(
                      sessionState == SessionState.connecting
                          ? 'Connecting...'
                          : 'Start Session',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Speak naturally — GovAgent will navigate\ngovernment portals for you.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white38,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startSession(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(geminiSessionProvider.notifier);
    await notifier.startSession();

    if (!context.mounted) return;

    final state = ref.read(geminiSessionProvider);
    if (state == SessionState.active) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SessionScreen()),
      );
    } else if (state == SessionState.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not start session. Firebase may not be configured.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}
