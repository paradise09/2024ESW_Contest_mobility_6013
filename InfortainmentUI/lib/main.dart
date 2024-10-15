import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/authentication/login_screen.dart';
import 'features/authentication/sign_up_screen.dart';
import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/settings/settings_screen.dart';
import 'firebase_options.dart';
import 'features/home/widgets/tts_manager.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  KakaoSdk.init(nativeAppKey: '485169cb19d2eda65a5d36105f83a53b');
  Get.put(ThemeController()); // ThemeController 초기화

  // 로그인 상태 확인 및 초기 화면 설정
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? email = prefs.getString('email');
  String? password = prefs.getString('password');
  Widget initialScreen;

  // 저장된 이메일과 비밀번호를 로그로 출력
  print("저장된 이메일: $email");
  print("저장된 비밀번호: $password");

  if (email != null && password != null) {
    // 저장된 자격 증명으로 로그인 시도
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      User? user = userCredential.user;
      if (user != null) {
        print("로그인 성공: ${user.email}");
        initialScreen = HomeScreen();
      } else {
        print("로그인 실패: 사용자 정보 없음");
        initialScreen = SplashScreen();
      }
    } catch (e) {
      print("로그인 오류: $e");
      initialScreen = SplashScreen();
    }
  } else {
    // 저장된 자격 증명이 없을 경우 SplashScreen으로 이동
    initialScreen = SplashScreen();
  }

  runApp(MyApp(ttsManager: TtsManager(), initialScreen: initialScreen));
}


class MyApp extends StatelessWidget {
  final TtsManager ttsManager;
  final Widget initialScreen;

  MyApp({required this.ttsManager, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find();

    return Obx(() {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AIConnectCar',
        theme: ThemeData.dark().copyWith(
          primaryColor: themeController.primaryColor.value,
          hintColor: Colors.white,
          buttonTheme: ButtonThemeData(
            buttonColor: themeController.primaryColor.value,
            textTheme: ButtonTextTheme.primary,
          ),
        ),
        home: initialScreen,
        routes: {
          '/splash': (context) => SplashScreen(),
          '/login': (context) => LoginScreen(),
          '/sign_up': (context) => SignUpScreen(),
          '/home': (context) => HomeScreen(),
          '/settings': (context) => SettingsScreen(ttsManager: ttsManager),
        },
      );
    });
  }
}
