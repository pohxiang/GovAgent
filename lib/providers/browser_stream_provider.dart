import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/models/browser_frame.dart';

class BrowserStreamNotifier extends Notifier<BrowserFrame?> {
  @override
  BrowserFrame? build() => null;

  void updateFrame(BrowserFrame frame) {
    state = frame;
  }

  void clear() {
    state = null;
  }
}

final browserStreamProvider =
    NotifierProvider<BrowserStreamNotifier, BrowserFrame?>(
  BrowserStreamNotifier.new,
);
