import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeController extends GetxController {
  var primaryColor = (Colors.white as Color).obs; // Color로 캐스팅하여 선언

  void changeTheme(Color color) {
    primaryColor.value = color;
  }
}
