import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/models/transcript_entry.dart';

class TranscriptNotifier extends Notifier<List<TranscriptEntry>> {
  @override
  List<TranscriptEntry> build() => [];

  void addEntry(TranscriptEntry entry) {
    state = [...state, entry];
  }

  void clear() {
    state = [];
  }
}

final transcriptProvider =
    NotifierProvider<TranscriptNotifier, List<TranscriptEntry>>(
  TranscriptNotifier.new,
);
