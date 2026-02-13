import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/models/session_state.dart';
import 'package:gov_agent/models/tool_call.dart';
import 'package:gov_agent/models/transcript_entry.dart';
import 'package:gov_agent/providers/browser_stream_provider.dart';
import 'package:gov_agent/providers/tool_call_provider.dart';
import 'package:gov_agent/providers/transcript_provider.dart';
import 'package:gov_agent/services/audio_capture_service.dart';
import 'package:gov_agent/services/audio_playback_service.dart';
import 'package:gov_agent/services/backend_websocket_service.dart';
import 'package:gov_agent/services/gemini_live_service.dart';
import 'package:gov_agent/services/permission_service.dart';

class GeminiSessionNotifier extends Notifier<SessionState> {
  late final GeminiLiveService _geminiService;
  late final AudioCaptureService _audioCaptureService;
  late final AudioPlaybackService _audioPlaybackService;
  late final BackendWebSocketService _backendService;
  late final PermissionService _permissionService;

  final List<StreamSubscription> _subscriptions = [];
  Uint8List _audioBuffer = Uint8List(0);
  bool _isListening = false;

  bool get isListening => _isListening;

  @override
  SessionState build() {
    _geminiService = GeminiLiveService();
    _audioCaptureService = AudioCaptureService();
    _audioPlaybackService = AudioPlaybackService();
    _backendService = BackendWebSocketService();
    _permissionService = PermissionService();

    ref.onDispose(_dispose);

    return SessionState.idle;
  }

  Future<void> startSession() async {
    if (state == SessionState.connecting || state == SessionState.active) return;

    state = SessionState.connecting;

    try {
      // Request mic permission
      final granted = await _permissionService.requestMicrophonePermission();
      if (!granted) {
        ref.read(transcriptProvider.notifier).addEntry(TranscriptEntry(
          speaker: Speaker.system,
          text: 'Microphone permission is required for voice interaction.',
          timestamp: DateTime.now(),
        ));
        state = SessionState.error;
        return;
      }

      // Initialize audio playback
      await _audioPlaybackService.initialize();

      // Connect to Gemini
      await _geminiService.connect();

      // Connect to backend
      try {
        await _backendService.connect();
      } catch (e) {
        // Backend is optional — session can work without it for voice-only mode
        ref.read(transcriptProvider.notifier).addEntry(TranscriptEntry(
          speaker: Speaker.system,
          text: 'Backend not available. Voice-only mode.',
          timestamp: DateTime.now(),
        ));
      }

      // Wire up streams
      _wireStreams();

      state = SessionState.active;

      ref.read(transcriptProvider.notifier).addEntry(TranscriptEntry(
        speaker: Speaker.system,
        text: 'Session started. Tap the mic to speak.',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      ref.read(transcriptProvider.notifier).addEntry(TranscriptEntry(
        speaker: Speaker.system,
        text: 'Failed to connect: $e',
        timestamp: DateTime.now(),
      ));
      state = SessionState.error;
    }
  }

  void _wireStreams() {
    // Gemini audio → playback
    _subscriptions.add(
      _geminiService.audioStream.listen((audioData) {
        // Accumulate audio data then play
        final newBuffer = Uint8List(_audioBuffer.length + audioData.length);
        newBuffer.setRange(0, _audioBuffer.length, _audioBuffer);
        newBuffer.setRange(_audioBuffer.length, newBuffer.length, audioData);
        _audioBuffer = newBuffer;

        // Play when we have enough data (~100ms at 24kHz 16-bit mono = 4800 bytes)
        if (_audioBuffer.length >= 4800) {
          _audioPlaybackService.playPcmData(_audioBuffer);
          _audioBuffer = Uint8List(0);
        }
      }),
    );

    // Gemini transcripts → provider
    _subscriptions.add(
      _geminiService.transcriptStream.listen((entry) {
        ref.read(transcriptProvider.notifier).addEntry(entry);
      }),
    );

    // Gemini tool calls → forward to backend + maybe show confirmation
    _subscriptions.add(
      _geminiService.toolCallStream.listen((toolCall) {
        if (toolCall.requiresConfirmation) {
          ref.read(toolCallProvider.notifier).setPendingConfirmation(toolCall);
        } else {
          // Forward directly to backend
          _backendService.sendToolCall(toolCall);
        }
      }),
    );

    // Backend screenshots → browser stream provider
    _subscriptions.add(
      _backendService.frameStream.listen((frame) {
        ref.read(browserStreamProvider.notifier).updateFrame(frame);
      }),
    );

    // Backend tool results → forward back to Gemini
    _subscriptions.add(
      _backendService.toolResultStream.listen((result) {
        final name = result['name'] as String? ?? '';
        final id = result['id'] as String?;
        _geminiService.sendToolResult(name, id, result);
      }),
    );

    // Gemini interruptions → clear playback
    _subscriptions.add(
      _geminiService.interruptionStream.listen((_) {
        _audioPlaybackService.clearPlayback();
        _audioBuffer = Uint8List(0);
      }),
    );
  }

  void toggleMic() {
    if (_isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  void startListening() {
    if (_isListening || state != SessionState.active) return;
    _isListening = true;

    // Clear playback when user starts speaking
    _audioPlaybackService.clearPlayback();
    _audioBuffer = Uint8List(0);

    final micStream = _audioCaptureService.startCapture();
    _subscriptions.add(
      micStream.listen((audioData) {
        _geminiService.sendAudio(audioData);
      }),
    );
    // Force notify listeners about mic state change
    state = state;
  }

  void stopListening() {
    if (!_isListening) return;
    _isListening = false;
    _audioCaptureService.stopCapture();
    // Force notify listeners about mic state change
    state = state;
  }

  void confirmToolCall(ToolCall toolCall) {
    _backendService.sendToolCall(toolCall);
    ref.read(toolCallProvider.notifier).clearPending();
  }

  void rejectToolCall() {
    ref.read(toolCallProvider.notifier).clearPending();
    _geminiService.sendToolResult('rejected', null, {'error': 'User rejected the action'});
  }

  Future<void> endSession() async {
    stopListening();
    await _geminiService.disconnect();
    await _backendService.disconnect();
    _audioPlaybackService.clearPlayback();
    _audioBuffer = Uint8List(0);

    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    ref.read(transcriptProvider.notifier).clear();
    ref.read(browserStreamProvider.notifier).clear();
    ref.read(toolCallProvider.notifier).clearPending();

    state = SessionState.idle;
  }

  void _dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _geminiService.dispose();
    _audioCaptureService.dispose();
    _audioPlaybackService.dispose();
    _backendService.dispose();
  }
}

final geminiSessionProvider =
    NotifierProvider<GeminiSessionNotifier, SessionState>(
  GeminiSessionNotifier.new,
);
