import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _carNumberController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase(
    databaseURL: 'https://ai-connectcar-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).reference();
  String _errorMessage = '';
  List<bool> _selectedCarType = [true, false];

  void _signUp() async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      User? user = userCredential.user;

      if (user != null) {
        await _saveUserData(user);
        await _saveLoginState(_emailController.text, _passwordController.text);
        _showSuccessDialog(context);
      }
    } on FirebaseAuthException catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError('알 수 없는 오류가 발생했습니다.');
    }
  }

  Future<void> _saveUserData(User user) async {
    String carType = _selectedCarType[0] ? 'general' : 'emergency';
    String vehicleNumber = _carNumberController.text.replaceAll(RegExp(r'[^0-9]'), '');
    Map<String, dynamic> userData = _buildUserData(carType);

    await _database.child(carType).child(vehicleNumber).set(userData);
  }

  Map<String, dynamic> _buildUserData(String carType) {
    if (carType == 'general') {
      return {
        'email': _emailController.text.trim(),
        'battery': 100, // 배터리 잔량 기본값 추가
        'location': {'lat': 0, 'long': 0},
        'trigger': '',
        'userRequest': {'requestText': '', 'requestState': '', 'standbyState': ''},
        'problem': {
          'rxState': '',
          'txState': '',
          'myState': '',
          'nmState': '',
          'txText': '',
          'rxText': '',
          'myText': '',
          'nmText': ''
        },
        'Service': {
          'gasStation': {'name': '', 'location': {'lat': 0, 'long': 0}},
          'chargeStation': {'name': '', 'location': {'lat': 0, 'long': 0}},
          'restArea': {'name': '', 'location': {'lat': 0, 'long': 0}},
        },
        'report': {'112': 0, '119': 0, '0800482000': 0},
        'LBS': {},
      };
    } else {
      return {
        'email': _emailController.text.trim(),
        'battery': 100, // 배터리 잔량 기본값 추가
        'userRequest': {'requestText': '', 'requestState': '', 'standbyState': ''},
        'location': {'lat': 0, 'long': 0},
        'trigger': '',
        'problem': {'egState': '', 'egText': ''},
        'LBS': {},
      };
    }
  }

  Future<void> _saveLoginState(String email, String password) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email);
    await prefs.setString('password', password);
  }

  void _handleError(String? message) {
    setState(() {
      _errorMessage = message ?? '알 수 없는 오류가 발생했습니다.';
    });
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('축하합니다!'),
          content: Text('회원가입 되었습니다!'),
          actions: [
            TextButton(
              child: Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _carNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('회원가입')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_emailController, '이메일'),
              _buildTextField(_passwordController, '비밀번호', obscureText: true),
              _buildTextField(_carNumberController, '차량 번호'),
              SizedBox(height: 20),
              Text('차량 타입'),
              _buildToggleButtons(),
              SizedBox(height: 20),
              if (_errorMessage.isNotEmpty) _buildErrorText(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUp,
                child: Text('회원가입'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextField _buildTextField(TextEditingController controller, String labelText, {bool obscureText = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: labelText),
      obscureText: obscureText,
      keyboardType: keyboardType,
    );
  }

  ToggleButtons _buildToggleButtons() {
    return ToggleButtons(
      isSelected: _selectedCarType,
      onPressed: (int index) {
        setState(() {
          for (int i = 0; i < _selectedCarType.length; i++) {
            _selectedCarType[i] = i == index;
          }
        });
      },
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('일반차량'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('응급차량'),
        ),
      ],
    );
  }

  Text _buildErrorText() {
    return Text(
      _errorMessage,
      style: TextStyle(color: Colors.red),
    );
  }
}
