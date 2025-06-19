import 'package:flutter/material.dart';

class FilterModel extends ChangeNotifier {
  RangeValues ageRange = const RangeValues(18, 40);
  double maxDistance = 50;
  String gender = 'all';

  void updateAge(RangeValues v) { ageRange = v; notifyListeners(); }
  void updateDistance(double d) { maxDistance = d; notifyListeners(); }
  void updateGender(String g) { gender = g; notifyListeners(); }
}
