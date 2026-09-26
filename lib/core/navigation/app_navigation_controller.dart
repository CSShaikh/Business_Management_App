import 'package:flutter/foundation.dart';

/// Lightweight app-level navigation requests used by child forms.
///
/// Add/Edit screens can request the dashboard after a successful CREATE without
/// needing a direct reference to MainNavigationScreen.
class AppNavigationController {
  AppNavigationController._();

  static final ValueNotifier<int> homeRequests = ValueNotifier<int>(0);

  static void requestHome() {
    homeRequests.value++;
  }
}
