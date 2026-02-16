import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:gov_agent/config/app_config.dart';
import 'package:gov_agent/models/tool_call.dart' as model;
import 'package:gov_agent/main.dart' show firebaseInitialized;
import 'package:gov_agent/models/transcript_entry.dart';

class GeminiLiveService {
  LiveSession? _session;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  final _audioController = StreamController<Uint8List>.broadcast();
  final _transcriptController = StreamController<TranscriptEntry>.broadcast();
  final _toolCallController = StreamController<model.ToolCall>.broadcast();
  final _interruptionController = StreamController<void>.broadcast();

  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<TranscriptEntry> get transcriptStream => _transcriptController.stream;
  Stream<model.ToolCall> get toolCallStream => _toolCallController.stream;
  Stream<void> get interruptionStream => _interruptionController.stream;

  static final List<Tool> _tools = [
    Tool.functionDeclarations([
      FunctionDeclaration(
        'open_page',
        'Navigate the browser to a specific government portal URL',
        parameters: {
          'url': Schema.string(description: 'The URL to navigate to'),
        },
      ),
      FunctionDeclaration(
        'fill_field',
        'Fill in a form field on the current page',
        parameters: {
          'selector': Schema.string(description: 'CSS selector for the field'),
          'value': Schema.string(description: 'Value to fill in'),
        },
      ),
      FunctionDeclaration(
        'click_element',
        'Click on an element on the current page',
        parameters: {
          'selector': Schema.string(description: 'CSS selector for the element to click'),
        },
      ),
      FunctionDeclaration(
        'submit_form',
        'Submit the current form. Requires user confirmation.',
        parameters: {
          'selector': Schema.string(description: 'CSS selector for the form or submit button'),
        },
      ),
      FunctionDeclaration(
        'read_page',
        'Read and extract text content from the current page',
        parameters: {
          'selector': Schema.string(
            description: 'Optional CSS selector to read specific section',
            nullable: true,
          ),
        },
      ),
    ]),
  ];

  Future<void> connect() async {
    if (!firebaseInitialized) {
      throw Exception(
        'Firebase is not configured. To use Gemini voice features, '
        'set up a Firebase project and add google-services.json.',
      );
    }

    final liveModel = FirebaseAI.googleAI().liveGenerativeModel(
      model: AppConfig.geminiModel,
      liveGenerationConfig: LiveGenerationConfig(
        responseModalities: [ResponseModalities.audio, ResponseModalities.text],
        speechConfig: SpeechConfig(voiceName: 'Aoede'),
      ),
      tools: _tools,
      systemInstruction: Content.system(
        'You are GovAgent, a helpful AI assistant that helps Malaysian citizens '
        'navigate government portals. You control a browser on the backend. '
        'When the user asks for help with a government service, use the provided '
        'tools to navigate, fill forms, and complete tasks. Always confirm before '
        'submitting any form. Speak in a friendly, clear manner. You can respond '
        'in English or Bahasa Malaysia based on the user\'s preference.',
      ),
    );

    _session = await liveModel.connect();
    _isConnected = true;

    _listenToResponses();
  }

  void _listenToResponses() async {
    try {
      await for (final response in _session!.receive()) {
        final message = response.message;

        if (message is LiveServerContent) {
          // Handle interruptions
          if (message.interrupted == true) {
            _interruptionController.add(null);
            continue;
          }

          // Handle transcription
          if (message.outputTranscription?.text != null) {
            _transcriptController.add(TranscriptEntry(
              speaker: Speaker.agent,
              text: message.outputTranscription!.text!,
              timestamp: DateTime.now(),
            ));
          }

          // Handle model turn content (audio/text)
          for (final part in message.modelTurn?.parts ?? []) {
            if (part is InlineDataPart && part.mimeType.startsWith('audio/')) {
              _audioController.add(part.bytes);
            } else if (part is TextPart) {
              _transcriptController.add(TranscriptEntry(
                speaker: Speaker.agent,
                text: part.text,
                timestamp: DateTime.now(),
              ));
            }
          }
        } else if (message is LiveServerToolCall) {
          for (final call in message.functionCalls ?? []) {
            final toolCall = model.ToolCall(
              id: call.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
              name: call.name,
              arguments: Map<String, dynamic>.from(call.args),
              requiresConfirmation: call.name == 'submit_form',
            );
            _toolCallController.add(toolCall);
          }
        }
      }
    } catch (e) {
      _transcriptController.add(TranscriptEntry(
        speaker: Speaker.system,
        text: 'Connection error: $e',
        timestamp: DateTime.now(),
      ));
      _isConnected = false;
    }
  }

  void sendAudio(Uint8List audioData) {
    if (!_isConnected || _session == null) return;
    _session!.sendAudioRealtime(
      InlineDataPart('audio/pcm', audioData),
    );
  }

  Future<void> sendToolResult(String name, String? id, Map<String, dynamic> result) async {
    if (!_isConnected || _session == null) return;
    _session!.sendToolResponse([
      FunctionResponse(name, result, id: id),
    ]);
  }

  Future<void> disconnect() async {
    _isConnected = false;
    await _session?.close();
    _session = null;
  }

  void dispose() {
    disconnect();
    _audioController.close();
    _transcriptController.close();
    _toolCallController.close();
    _interruptionController.close();
  }
}
