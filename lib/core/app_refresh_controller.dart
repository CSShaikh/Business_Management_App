import 'package:flutter/foundation.dart';

/// Global data-change signal used only to refresh already-open app screens
/// immediately after provider/repository changes.
class AppRefreshController extends ChangeNotifier {
  AppRefreshController._();

  static final AppRefreshController instance = AppRefreshController._();

  int _version = 0;

  int get version => _version;

  void bump() {
    _version++;
    notifyListeners();
  }
}
