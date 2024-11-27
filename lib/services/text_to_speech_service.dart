import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> initializeTts() async {
    await _flutterTts.setLanguage("id-ID");
  }

  Future<void> speak(String message) async {
    await _flutterTts.speak(message);
    await _flutterTts.awaitSpeakCompletion(true);
  }

  void stop() {
    _flutterTts.stop();
  }
}