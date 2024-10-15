import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../home/widgets/tts_manager.dart';
import '../recommend/recommend_places_screen.dart';

class SettingsScreen extends StatefulWidget {
  final TtsManager ttsManager;

  SettingsScreen({required this.ttsManager});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _voiceGuide = true;
  bool _warningSound = true;
  double _brightness = 0.5;
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _profileController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase(
    databaseURL: 'https://ai-connectcar-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).reference();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVehicleInfo();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _voiceGuide = prefs.getBool('voiceGuide') ?? true;
      _warningSound = prefs.getBool('warningSound') ?? true;
      _brightness = prefs.getDouble('brightness') ?? 0.5;
      _profileController.text = prefs.getString('profileInfo') ?? '';
    });
  }

  void _loadVehicleInfo() async {
    User? user = _auth.currentUser;
    if (user != null) {
      // 'general' 및 'emergency' 노드에서 이메일로 차량 번호 검색
      DatabaseEvent generalEvent = await _database
          .child('general')
          .orderByChild('email')
          .equalTo(user.email)
          .once();
      DatabaseEvent emergencyEvent = await _database
          .child('emergency')
          .orderByChild('email')
          .equalTo(user.email)
          .once();

      if (generalEvent.snapshot.value != null) {
        Map<dynamic, dynamic> generalData =
        generalEvent.snapshot.value as Map<dynamic, dynamic>;
        String vehicleNumber = generalData.keys.first;
        setState(() {
          _vehicleController.text = vehicleNumber;
        });
      } else if (emergencyEvent.snapshot.value != null) {
        Map<dynamic, dynamic> emergencyData =
        emergencyEvent.snapshot.value as Map<dynamic, dynamic>;
        String vehicleNumber = emergencyData.keys.first;
        setState(() {
          _vehicleController.text = vehicleNumber;
        });
      }
    }
  }

  void _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('voiceGuide', _voiceGuide);
    prefs.setBool('warningSound', _warningSound);
    prefs.setDouble('brightness', _brightness);
    prefs.setString('vehicleInfo', _vehicleController.text);
    prefs.setString('profileInfo', _profileController.text);
    widget.ttsManager.enableVoiceGuide(_voiceGuide);
  }

  void _navigateToRecommendPlaces() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecommendPlacesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('마이 프로필')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ListTile(
              title: TextField(
                controller: _vehicleController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Vehicle Info',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                enabled: false,
              ),
            ),
            ListTile(
              title: TextField(
                controller: _profileController,
                decoration: InputDecoration(labelText: 'Profile Info'),
                onChanged: (String value) {
                  _saveSettings();
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _navigateToRecommendPlaces,
                child: Text('추천받은 장소 보기'),
              ),
            ),
            SizedBox(height: 20,),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text('환경설정', style: TextStyle(color: Colors.white, fontSize: 20),),
            ),
            SwitchListTile(
              title: Text('Voice Guide'),
              value: _voiceGuide,
              onChanged: (bool value) {
                setState(() {
                  _voiceGuide = value;
                });
                _saveSettings();
              },
            ),
            SwitchListTile(
              title: Text('Warning Sound'),
              value: _warningSound,
              onChanged: (bool value) {
                setState(() {
                  _warningSound = value;
                });
                _saveSettings();
              },
            ),
            ListTile(
              title: Text('Brightness'),
              subtitle: Slider(
                value: _brightness,
                onChanged: (double value) {
                  setState(() {
                    _brightness = value;
                  });
                  _saveSettings();
                },
                min: 0.0,
                max: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
