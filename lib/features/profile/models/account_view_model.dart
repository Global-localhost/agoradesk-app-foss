import 'dart:async';

import 'package:agoradesk/core/app_state.dart';
import 'package:agoradesk/core/events.dart';
import 'package:agoradesk/core/theme/theme.dart';
import 'package:agoradesk/core/utils/validator_mixin.dart';
import 'package:agoradesk/core/widgets/branded/agora_dialog_two_buttons.dart';
import 'package:agoradesk/features/auth/data/services/auth_service.dart';
import 'package:agoradesk/router.gr.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:restart_app/restart_app.dart';
import 'package:vm/vm.dart';

class AccountViewModel extends ViewModel with ValidatorMixin {
  AccountViewModel({
    required AuthService authService,
    required AppState appState,
  })  : _appState = appState,
        _authService = authService;

  final AppState _appState;
  final AuthService _authService;

  String? userName;
  String appVersionStr = '';

  late bool isGuestMode;

  @override
  Future<void> init() async {
    //todo - refactor me (maybe with AutoRoute)
    isGuestMode = _authService.authState == AuthState.guest;
    _authService.onAuthStateChange.listen((e) {
      isGuestMode = e == AuthState.guest;
      if (e == AuthState.loggedIn) {
        initModel();
      }
      notifyListeners();
    });

    if (_authService.isAuthenticated) {
      initModel();
    }

    PackageInfo.fromPlatform().then(
      (info) {
        appVersionStr = '${info.appName}/${info.version}+${info.buildNumber}';
        notifyListeners();
      },
    );
    super.init();
  }

  void initModel() async {
    userName = _appState.username;
  }

  bool isSentryOn() {
    return _appState.sentryIsOn;
  }

  bool hasCurrentPin() {
    return _appState.hasPinCode;
  }

  Future setPinCode() async {
    await AutoRouter.of(context).push(const PinCodeSetRoute());
    notifyListeners();
  }

  void switchSentryStatus(BuildContext context) {
    _appState.sentryIsOn = !_appState.sentryIsOn;
    notifyListeners();

    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (_) => AgoraDialogTwoButtons(
        body: Text(context.intl.app_anonymous_crash_diagnostics_restart),
        mainAction: Restart.restartApp,
        mainActionText: context.intl.app_restart_now,
        secondAction: () => Navigator.of(context).pop(),
        secondActionText: context.intl.app_postpone,
      ),
    );
  }

  bool isDarkTheme() {
    return _appState.themeMode == ThemeMode.dark;
  }

  bool biometricAuthIsOn() {
    return _appState.biometricAuthIsOn;
  }

  void switchBiometricAuth() async {
    // in case switching on biometric auth the PIN code must be enabled.
    if (!_appState.biometricAuthIsOn) {
      if (!_appState.hasPinCode) {
        await showDialog(
          barrierDismissible: true,
          context: context,
          builder: (_) => AgoraDialogTwoButtons(
            title: context.intl.app_biometric_authentication,
            body: Text(context.intl.app_biometric_authentication_message),
            mainActionText: context.intl.pin_set,
            mainAction: () async {
              await setPinCode();
              Navigator.of(context).pop();
            },
            secondActionText: 'Cancel',
            secondAction: () {
              Navigator.of(context).pop();
            },
          ),
        );
      }
      if (_appState.hasPinCode) {
        _appState.biometricAuthIsOn = !_appState.biometricAuthIsOn;
      }
    } else {
      _appState.biometricAuthIsOn = !_appState.biometricAuthIsOn;
    }
    notifyListeners();
  }

  void switchTheme() {
    if (isDarkTheme()) {
      _appState.themeMode = ThemeMode.light;
    } else {
      _appState.themeMode = ThemeMode.dark;
    }
  }

  Future removePin(BuildContext contex) async {
    await _appState.removePinCode();
    _appState.hasPinCode = false;
    _appState.biometricAuthIsOn = false;
    eventBus.fire(FlashEvent.success(context.intl.remove_pin_message_success));
    notifyListeners();
  }

  void updateWith({
    bool? displayCaptcha,
    // bool? loading,
  }) {
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
