import 'package:flutter_tts/flutter_tts.dart';

class TtsManager {
  final FlutterTts _flutterTts = FlutterTts();
  bool isSpeaking = false;
  bool isVoiceGuideEnabled = true;

  TtsManager() {
    _flutterTts.setStartHandler(() {
      isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      isSpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      isSpeaking = false;
      print("TTS Error: $msg");
    });

    _initializeTtsSettings();
  }

  Future<void> speak(String text) async {
    if (isVoiceGuideEnabled) {
      try {
        await _flutterTts.speak(text);
      } catch (e) {
        print("TTS speak error: $e");
        isSpeaking = false;
      }
    }
  }

  void setStartHandler(void Function() handler) {
    _flutterTts.setStartHandler(handler);
  }

  void setCompletionHandler(void Function() handler) {
    _flutterTts.setCompletionHandler(handler);
  }

  void enableVoiceGuide(bool isEnabled) {
    isVoiceGuideEnabled = isEnabled;
  }

  void _initializeTtsSettings() async {
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      print("TTS initialization error: $e");
    }
  }
}
