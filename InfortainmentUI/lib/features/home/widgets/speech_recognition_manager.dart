import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:get/get.dart';
import '../../../theme_controller.dart';

class SpeechRecognitionManager with WidgetsBindingObserver {
  final DatabaseReference userRequestRef;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentSentence = '';
  bool _uploadState = false; // 앱 내 변수
  Timer? _restartTimer; // 재시작 타이머
  StreamSubscription<DatabaseEvent>? _requestStateSubscription; // requestState 구독
  String _currentRequestState = '0'; // 현재 requestState 값을 저장할 변수
  bool _showEarIcon = false; // 귀 모양 아이콘 상태 변수

  // Getter for _showEarIcon
  bool get showEarIcon => _showEarIcon; // showEarIcon getter 추가

  // Constructor
  SpeechRecognitionManager(this.userRequestRef) {
    WidgetsBinding.instance.addObserver(this);
    _listenToRequestState();
  }

  // Initialize the speech recognition manager
  Future<void> initialize(BuildContext context) async {
    bool available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );

    if (available) {
      _startListening(); // 초기화 후 듣기 시작
    } else {
      print('Speech recognition not available.');
    }
  }

  // Start listening to speech
  void _startListening() {
    _speech.listen(
      onResult: _onSpeechResult,
      listenFor: Duration(seconds: 20),
      pauseFor: Duration(seconds: 5),
      localeId: 'ko_KR',
    );
    _isListening = true;
  }

  // Handle speech recognition result
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      String recognizedText = result.recognizedWords;
      print('Recognized text: $recognizedText');
      _currentSentence = recognizedText;
      _uploadState = true;
      _uploadText(_currentSentence.trim());
    }
  }

  void _onSpeechStatus(String status) {
    print('Speech status: $status');

    if (status == 'done') {
      _isListening = false;
      if (!_uploadState) {
        _restartListeningWithDelay(); // 재시작
      }
      _showEarIcon = false;
    } else if (status == 'listening') {
      _isListening = true;
      if (_currentRequestState == '1') {
        _showEarIcon = true;
      }
    }
  }

  // Handle speech recognition errors
  void _onSpeechError(SpeechRecognitionError error) {
    print('Speech recognition error: ${error.errorMsg}');
    _isListening = false;
    if (!_uploadState) {
      _restartListeningWithDelay(); // 재시작
    }
  }

  // Upload recognized text to Firebase
  Future<void> _uploadText(String text) async {
    try {
      await userRequestRef.update({'requestText': text});
      print('Text uploaded successfully to ${userRequestRef.path}');
    } catch (error) {
      print('Error uploading text to ${userRequestRef.path}: $error');
    }

    // 업로드 후 _uploadState를 false로 설정하고 다시 듣기 시작
    _uploadState = false;
    _restartListeningWithDelay();
  }

  // Restart listening with a delay
  void _restartListeningWithDelay() {
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(seconds: 2), () {
      _startListening();
    });
  }

  // Listen to requestState changes
  void _listenToRequestState() {
    final ThemeController themeController = Get.find();
    _requestStateSubscription = userRequestRef.child('requestState').onValue.listen((event) {
      String requestState = (event.snapshot.value ?? '0') as String; // null인 경우 기본값 '0' 사용
      print('Request state: $requestState');
      _currentRequestState = requestState;
      if (requestState == '1') {
        themeController.changeTheme(Colors.greenAccent);
        if (_isListening) {
          _showEarIcon = true;
        }
      } else {
        themeController.changeTheme(Colors.white);
        _showEarIcon = false;
      }
    });
  }

  // Set upload state
  void setUploadState(bool state) {
    _uploadState = state;
    if (_uploadState) {
      _uploadText(_currentSentence.trim()); // 업로드 상태가 true인 경우 텍스트 업로드
    }
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _speech.stop();
      _restartTimer?.cancel();
      _requestStateSubscription?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _restartListeningWithDelay();
      _listenToRequestState();
    }
  }

  // Dispose resources
  @override
  void dispose() {
    _restartTimer?.cancel();
    _requestStateSubscription?.cancel();
    _speech.stop();
    WidgetsBinding.instance.removeObserver(this);
  }
}
