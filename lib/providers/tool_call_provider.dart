import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/models/tool_call.dart';

class ToolCallNotifier extends Notifier<ToolCall?> {
  @override
  ToolCall? build() => null;

  void setPendingConfirmation(ToolCall toolCall) {
    state = toolCall;
  }

  void clearPending() {
    state = null;
  }
}

final toolCallProvider = NotifierProvider<ToolCallNotifier, ToolCall?>(
  ToolCallNotifier.new,
);
