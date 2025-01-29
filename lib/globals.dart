//not used

import 'package:flutter/material.dart';

class Globals with ChangeNotifier {
  static Globals? _instance;
  factory Globals() => _instance ??= Globals._();

  Globals._();

  int myGlobalVariable = 0;

  void updateGlobalVariable(int newValue) {
    myGlobalVariable = newValue;
    notifyListeners();
  }
}
