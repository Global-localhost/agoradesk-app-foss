import 'package:agoradesk/core/app_parameters.dart';
import 'package:agoradesk/core/flavor_type.dart';
import 'package:agoradesk/core/utils/error_parse_mixin.dart';
import 'package:agoradesk/core/utils/validator_mixin.dart';
import 'package:agoradesk/features/auth/data/models/sign_up_request_model.dart';
import 'package:agoradesk/features/auth/data/services/auth_service.dart';
import 'package:agoradesk/features/auth/screens/dialog_captcha.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:vm/vm.dart';

class LoginViewModel extends ViewModel with ValidatorMixin, ErrorParseMixin {
  LoginViewModel({
    required AuthService authService,
  }) : _authService = authService;

  final AuthService _authService;

  String? _username;
  String? _password;
  String? _otp;
  String? _captchaInput;
  String? _captchaCookie;
  String? captchaUrl;
  String? captchaLocalPath;
  bool _displayCaptcha = false;
  bool _loading = false;
  bool _passwordVisible = false;
  bool isFormReady = false;
  String errorMessage = '';
  bool displayError = false;

  ScrollController scrollController = ScrollController();
  final FocusNode captchaFocus = FocusNode();
  TextEditingController passwordController = TextEditingController(text: '');
  TextEditingController otpController = TextEditingController(text: '');

  String? get username => _username;

  set username(String? v) => updateWith(username: v);

  String? get otp => _otp;

  set otp(String? v) => updateWith(otp: v);

  String? get password => _password;

  set password(String? v) => updateWith(password: v);

  bool get passwordVisible => _passwordVisible;

  set passwordVisible(bool v) => updateWith(passwordVisible: v);
  bool get loading => _loading;

  set loading(bool v) => updateWith(loading: v);

  bool get displayCaptcha => _displayCaptcha;

  set displayCaptcha(bool v) => updateWith(displayCaptcha: v);

  String? get captchaInput => _captchaInput;

  set captchaInput(String? v) => updateWith(captchaInput: v);

  @override
  void init() {
    _updateFormReadyState();
    notifyListeners();

    passwordController.addListener(() {
      password = passwordController.text;
    });
    otpController.addListener(() {
      otp = otpController.text;
    });
    super.init();
  }

  void guestModeOn() {
    _authService.guestModeOn();
  }

  void changePasswordVisibility() {
    passwordVisible = !passwordVisible;
  }

  Future<bool> login() async {
    if (isFormReady) {
      loading = true;
      final request = SignUpRequestModel(
        username: _username!,
        password: _password!,
        frontType: GetIt.I<AppParameters>().flavor.title(),
        captcha: _captchaInput,
        captchaCookie: _captchaCookie,
        otp: otp,
      );
      final res = await _authService.login(request);
      loading = false;
      if (res.isLeft) {
        _captchaCookie = res.left.captchaCookie;
        final String? captchaPath = res.left.captchaLocalPath;
        if (captchaPath != null) {
          _captchaInput = await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) => DialogCaptcha(
              path: captchaPath,
            ),
          );
          if (validateCaptcha(_captchaInput)) {
            login();
          }
        } else {
          handleApiError(res.left, context);
        }
        return false;
      }
      return res.right;
    }
    return false;
  }

  void _updateFormReadyState() {
    if (validatePassword(password) &&
        validateAlphanumericUnderscore(username) &&
        validateOtpWithNull(otp) &&
        (!_displayCaptcha || (_captchaInput != null && validateAlphanumeric(_captchaInput!)))) {
      isFormReady = true;
    } else {
      isFormReady = false;
    }
  }

  void updateWith({
    String? password,
    String? username,
    String? otp,
    String? email,
    String? captchaInput,
    bool? passwordVisible,
    bool? isTermsAgree,
    bool? displayCaptcha,
    bool? loading,
  }) {
    _password = password ?? _password;
    _passwordVisible = passwordVisible ?? _passwordVisible;
    _username = username ?? _username;
    _otp = otp ?? _otp;
    _captchaInput = captchaInput ?? _captchaInput;
    _displayCaptcha = displayCaptcha ?? _displayCaptcha;
    _loading = loading ?? _loading;
    _updateFormReadyState();
    notifyListeners();
  }

  @override
  void dispose() {
    scrollController.dispose();
    captchaFocus.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
