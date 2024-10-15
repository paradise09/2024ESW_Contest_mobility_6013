import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:get/get.dart';

import '../../theme_controller.dart';
import '../settings/settings_screen.dart';
import 'widgets/call_manager.dart';
import 'widgets/database_manager.dart';
import 'widgets/location_service.dart';
import 'widgets/navigation_manager.dart';
import 'widgets/tts_manager.dart';
import 'widgets/voice_animation.dart';
import 'widgets/state_to_image.dart';
import 'widgets/speech_recognition_manager.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseManager _databaseManager = DatabaseManager(
      'https://ai-connectcar-default-rtdb.asia-southeast1.firebasedatabase.app/');
  final TtsManager _ttsManager = TtsManager();
  final CallManager _callManager = CallManager();
  final NavigationManager _navigationManager = NavigationManager();
  final LocationService _locationService = LocationService();

  User? _user;
  String? _vehicleNumber;
  bool _isVoiceGuideEnabled = true;
  String? _displayedImage;
  String _ttsText = '';
  Timer? _locationTimer;
  LatLng? _currentPosition;
  GoogleMapController? _mapController;
  String? _userType;
  double _currentBearing = 0.0;
  StreamSubscription? _compassSubscription;
  StreamSubscription? _batterySubscription; // 배터리 리스너 추가
  SpeechRecognitionManager? _speechRecognitionManager;
  String _currentRequestState = '0'; // 현재 requestState 값을 저장할 변수
  bool _showEarIcon = false; // 귀 모양 아이콘 상태 변수
  int _batteryLevel = 100; // 배터리 잔량 변수 추가

  @override
  void initState() {
    super.initState();
    _initialize();
    _requestPermissions();
    _listenToCompass();
  }

  Future<void> _initialize() async {
    await _requestPermissions();
    _user = _auth.currentUser;
    if (_user != null) {
      await _getVehicleNumberAndListenForUpdates();
      _startLocationUpdates();
      _listenToCompass();
      _ttsManager.setStartHandler(_onTtsStart);
      _ttsManager.setCompletionHandler(_onTtsComplete);
      await _loadSettings();

      // 배터리 리스너 초기화
      if (_userType != null && _vehicleNumber != null) {
        _listenToBattery(_userType!, _vehicleNumber!);
      }

      // 여기에 setState 추가하여 _speechRecognitionManager 초기화 후 상태 업데이트
      if (_userType != null && _vehicleNumber != null) {
        await _initializeSpeechRecognition(_userType!, _vehicleNumber!);
        setState(() {}); // 상태 업데이트
      }
    }
  }

  // 배터리 레벨에 따른 색상을 반환하는 헬퍼 함수
  Color getBatteryColor(int level) {
    if (level >= 80 && level <= 100) {
      return Colors.blue;
    } else if (level >= 50 && level < 80) {
      return Colors.green;
    } else if (level >= 20 && level < 50) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  Future<void> _listenToBattery(String userType, String vehicleNumber) async {
    DatabaseReference batteryRef = _databaseManager
        .getDatabaseRef()
        .child(userType)
        .child(vehicleNumber)
        .child('battery');

    _batterySubscription = batteryRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        int battery = 100;
        if (data is int) {
          battery = data;
        } else if (data is String) {
          battery = int.tryParse(data) ?? 100;
        }
        setState(() {
          _batteryLevel = battery;
        });
      }
    });
  }

  Future<void> _requestPermissions() async {
    if (await Permission.locationWhenInUse.request().isGranted) {
      await Permission.activityRecognition.request();
    }
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (_userType != null && _vehicleNumber != null) {
        await _locationService.updateLocation(_userType!, _vehicleNumber!);
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
          });
          _moveCameraToCurrentPosition();
        }
      }
    });
  }

  void _listenToCompass() {
    _compassSubscription = FlutterCompass.events!.listen((event) {
      if (mounted) {
        setState(() {
          _currentBearing = event.heading ?? 0.0;
        });
        _moveCameraToCurrentPosition();
      }
    });
  }

  void _moveCameraToCurrentPosition() {
    if (_currentPosition != null && _mapController != null) {
      final LatLng targetPosition = _currentPosition!;
      _mapController?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: targetPosition,
          zoom: 19.0,
          tilt: 30.0,
          bearing: _currentBearing,
        ),
      ));
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _compassSubscription?.cancel();
    _batterySubscription?.cancel(); // 배터리 리스너 취소
    super.dispose();
  }

  Future<void> _getVehicleNumberAndListenForUpdates() async {
    _vehicleNumber = await _databaseManager.getVehicleNumber();
    if (_vehicleNumber != null) {
      _userType = await _databaseManager.getUserType(_vehicleNumber!);
      _listenForStateUpdates(_userType!, _vehicleNumber!);
      _listenForCallUpdates(_userType!, _vehicleNumber!);
      _listenForNavigationUpdates(_userType!, _vehicleNumber!);
      if (_userType != null && _vehicleNumber != null) {
        await _initializeSpeechRecognition(_userType!, _vehicleNumber!);
        setState(() {}); // 상태 업데이트
      }
    }
  }

  Future<void> _initializeSpeechRecognition(
      String userType, String vehicleNumber) async {
    DatabaseReference userRequestRef = _databaseManager
        .getDatabaseRef()
        .child(userType)
        .child(vehicleNumber)
        .child('userRequest');
    _speechRecognitionManager = SpeechRecognitionManager(userRequestRef);
    await _speechRecognitionManager!.initialize(context);
  }

  void _listenForStateUpdates(String userType, String vehicleNumber) {
    // userRequest의 standbyState가 1인지 확인하는 부분 추가
    _databaseManager
        .getDatabaseRef()
        .child(userType)
        .child(vehicleNumber)
        .child('userRequest')
        .child('standbyState')
        .onValue
        .listen((event) {
      String standbyState =
      (event.snapshot.value ?? '0') as String; // null인 경우 기본값 '0' 사용
      if (standbyState == '1') {
        _updateTtsText(null); // standbyState가 1일 때 '듣고 있습니다'로 표시합니다.
      }
    });

    _databaseManager
        .getDatabaseRef()
        .child(userType)
        .child(vehicleNumber)
        .child('problem')
        .onValue
        .listen((event) {
      DataSnapshot dataSnapshot = event.snapshot;
      if (dataSnapshot.value != null) {
        Map<dynamic, dynamic> values =
        dataSnapshot.value as Map<dynamic, dynamic>;

        String combinedText = '';
        if (_isVoiceGuideEnabled) {
          if (userType == 'general') {
            if (values['myText'] != null &&
                values['myText'].toString().trim().isNotEmpty) {
              combinedText += '${values['myText']} ';
            }
            if (values['rxText'] != null &&
                values['rxText'].toString().trim().isNotEmpty) {
              combinedText += '${values['rxText']} ';
            }
            if (values['txText'] != null &&
                values['txText'].toString().trim().isNotEmpty) {
              combinedText += '${values['txText']} ';
            }
            if (values['nmText'] != null &&
                values['nmText'].toString().trim().isNotEmpty) {
              combinedText += '${values['nmText']} ';
            }
          } else if (userType == 'emergency') {
            if (values['egText'] != null &&
                values['egText'].toString().trim().isNotEmpty) {
              combinedText += '${values['egText']} ';
            }
          }
          if (combinedText.trim().isNotEmpty) {
            _updateTtsText(combinedText.trim());
          }
        }

        _displayStateImage(values['rxState']);
        _displayStateImage(values['txState']);
        _displayStateImage(values['myState']);
      } else {}
    });
  }

  void _displayStateImage(String? state) {
    if (state != null && stateToImage.containsKey(state)) {
      _showImageForDuration(stateToImage[state]);
    }
  }

  void _updateTtsText(String? text) {
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        _ttsText = text;
      });
      _showImageForDuration(stateToImage[_ttsText]);
      _ttsManager.speak(text); // TTS로 텍스트 읽기
    } else {
      setState(() {
        _ttsText = '듣고 있습니다';
      });
    }
  }

  void _showImageForDuration(String? image) {
    setState(() {
      _displayedImage = image;
    });

    // 15초 후에 이미지를 숨김
    Future.delayed(Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _displayedImage = null;
        });
      }
    });
  }

  void _listenForCallUpdates(String userType, String vehicleNumber) {
    _databaseManager
        .getDatabaseRef()
        .child(userType)
        .child(vehicleNumber)
        .child('report')
        .onValue
        .listen((event) {
      DataSnapshot dataSnapshot = event.snapshot;
      if (dataSnapshot.value != null) {
        Map<dynamic, dynamic> values =
        dataSnapshot.value as Map<dynamic, dynamic>;
        if (values['112'] == 1) _callManager.makePhoneCall('112');
        if (values['119'] == 1) _callManager.makePhoneCall('119');
        if (values['0800482000'] == 1)
          _callManager.makePhoneCall('0800482000');
      } else {}
    });
  }

  void _listenForNavigationUpdates(String userType, String vehicleNumber) {
    _databaseManager
        .getDatabaseRef()
        .child(userType)
        .child(vehicleNumber)
        .child('Service')
        .onValue
        .listen((event) async {
      DataSnapshot dataSnapshot = event.snapshot;
      if (dataSnapshot.value != null) {
        Map<dynamic, dynamic> values =
        dataSnapshot.value as Map<dynamic, dynamic>;
        await _handleServiceUpdate(values, 'chargeStation');
        await _handleServiceUpdate(values, 'gasStation');
        await _handleServiceUpdate(values, 'restArea');
      } else {}
    });
  }

  Future<void> _handleServiceUpdate(
      Map<dynamic, dynamic> values, String serviceType) async {
    var service = values[serviceType];
    if (service != null && service['location'] != null) {
      double lat = _convertToDouble(service['location']['lat']);
      double long = _convertToDouble(service['location']['long']);
      String name = service['name'];
      if (lat != 0.0 && long != 0.0) {
        print('Navigating to $serviceType: $name, lat: $lat, long: $long');
        try {
          await _navigationManager.navigateToDestination(name, lat, long);
        } catch (e) {
          print('Error launching navigation: $e');
        }
      } else {}
    }
  }

  double _convertToDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isVoiceGuideEnabled = prefs.getBool('isVoiceGuideEnabled') ?? true;
    });
    _ttsManager.enableVoiceGuide(_isVoiceGuideEnabled);
  }

  void _onTtsStart() {
    setState(() {
      _ttsManager.isSpeaking = true;
    });
  }

  void _onTtsComplete() {
    setState(() {
      _ttsManager.isSpeaking = false;
    });
  }

  void _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('email');
    await prefs.remove('password');
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find();

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/aiconnectcar_logo.png',
                width: 30,
                height: 30,
              ),
              SizedBox(width: 5),
              Text('AIConnectCar'),
            ],
          ),
          actions: [
            // 배터리 잔량 표시 위젯 추가
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.battery_full,
                    color: getBatteryColor(_batteryLevel),
                  ),
                  SizedBox(width: 5),
                  Text(
                    '$_batteryLevel%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => _logout(context),
            ),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(ttsManager: _ttsManager),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentPosition ?? LatLng(0, 0),
                        zoom: 19.0,
                        tilt: 30.0,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      padding: EdgeInsets.only(top: 300),
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        if (_currentPosition != null) {
                          _moveCameraToCurrentPosition();
                        }
                      },
                    ),
                    if (_displayedImage != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Image.asset(
                            _displayedImage!,
                            width: 130,
                            height: 130,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Row(
                  children: [
                    VoiceAnimation(isSpeaking: _ttsManager.isSpeaking),
                    SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 20.0),
                        decoration: BoxDecoration(
                          color: themeController.primaryColor.value,
                          // 하단 컨테이너 색상 설정
                          borderRadius: BorderRadius.circular(15.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 6.0,
                            ),
                          ],
                        ),
                        child: Text(
                          _ttsText.isNotEmpty ? _ttsText : '듣고 있습니다',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    if (_speechRecognitionManager != null &&
                        _speechRecognitionManager!.showEarIcon) // 초기화 여부를 확인하여 표시
                      Icon(Icons.blur_on, size: 30, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
