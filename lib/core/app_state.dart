import 'dart:async';

import 'package:agoradesk/core/app_shared_prefs.dart';
import 'package:agoradesk/core/events.dart';
import 'package:agoradesk/core/secure_storage.dart';
import 'package:agoradesk/core/translations/country_info_mixin.dart';
import 'package:agoradesk/features/account/data/models/notification_model.dart';
import 'package:agoradesk/features/wallet/data/models/wallet_balance_model.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timeago/timeago.dart';

const _kLocaleDebounceTag = 'switch-locale';
const _kSmallScreenHeigh = 700.0;

class AppState extends ChangeNotifier with CountryInfoMixin {
  AppState({
    Locale? locale,
    ThemeMode themeMode = ThemeMode.dark,
    required SecureStorage secureStorage,
  })  : _locale = locale,
        _secureStorage = secureStorage,
        _themeMode = themeMode;

  final SecureStorage _secureStorage;
  ThemeMode _themeMode;
  Locale? _locale;
  String? _countryCode;
  String? _currencyCode = 'USD';
  bool _hasPinCode = false;

  String? _pinCode;
  String? openedTradeId;
  double? _screenHeight;

  String get username => AppSharedPrefs().username ?? '';

  bool get isSmallScreen => _screenHeight != null && _screenHeight! < _kSmallScreenHeigh;

  bool get sentryIsOn {
    try {
      return AppSharedPrefs().sentryIsOn ?? true;
    } catch (e) {
      return true;
    }
  }

  set sentryIsOn(bool val) {
    AppSharedPrefs().setBool(AppSharedPrefsKey.sentryIsOn, val: val);
  }

  bool get pushFcmTokenSavedToApi => AppSharedPrefs().pushFcmTokenSavedToApi ?? false;

  bool get iosFirstNotificationWasRun => AppSharedPrefs().iosFirstNotificationWasRun ?? false;

  set iosFirstNotificationWasRun(bool val) {
    AppSharedPrefs().setBool(AppSharedPrefsKey.iosFirstNotificationWasRun, val: val);
  }

  set pushFcmTokenSavedToApi(bool val) {
    AppSharedPrefs().setBool(AppSharedPrefsKey.pushFcmTokenSavedToApi, val: val);
  }

  String get langCode => locale.languageCode.substring(0, 2);

  ///
  /// Image uploading controller
  ///
  final BehaviorSubject<double> _uploadingController = BehaviorSubject<double>.seeded(0.0);

  ValueStream<double> get uploadingProgress$ => _uploadingController.stream;

  set uploadingProgress(double v) => _uploadingController.add(v);

  double get uploadingProgress => uploadingProgress$.value;

  final BehaviorSubject<bool> _uploadingStatusController = BehaviorSubject<bool>.seeded(false);

  ValueStream<bool> get uploadingStatus$ => _uploadingStatusController.stream;

  set uploadingStatus(bool v) => _uploadingStatusController.add(v);

  bool get uploadingStatus => uploadingStatus$.value;

  ///
  /// Connection controller
  ///
  final BehaviorSubject<bool> _connectionController = BehaviorSubject<bool>.seeded(true);

  ValueStream<bool> get connection$ => _connectionController.stream;

  set connection(bool v) => _connectionController.add(v);

  bool get connection => connection$.value;

  ///
  /// Reload market stream
  ///
  final StreamController<bool> _reloadMarketController = StreamController<bool>.broadcast();

  Stream<bool> get reloadMarket => _reloadMarketController.stream;

  Sink get sinkReloadMarket => _reloadMarketController;

  // final StreamController<bool> _amenPressedDown = StreamController<bool>.broadcast();
  // Stream<bool> get amenPressedDown => _amenPressedDown.stream;
  // Sink get sinkAmenPressedDown => _amenPressedDown;

  ///
  /// Unread / read state across the app
  ///
  final BehaviorSubject<bool> _hasUnreadController = BehaviorSubject<bool>.seeded(false);

  ValueStream<bool> get hasUnread$ => _hasUnreadController.stream;

  set hasUnread(bool v) => _hasUnreadController.add(v);

  bool get hasUnread => hasUnread$.value;

  ///
  ///
  ///
  final BehaviorSubject<bool> _notificationsLoadingController = BehaviorSubject<bool>.seeded(false);

  ValueStream<bool> get notificationsLoading$ => _notificationsLoadingController.stream;

  set notificationsLoading(bool v) => _notificationsLoadingController.add(v);

  bool get notificationsLoading => notificationsLoading$.value;

  ///
  ///
  ///
  final BehaviorSubject<bool> _notificationsMarkedReadController = BehaviorSubject<bool>.seeded(false);

  ValueStream<bool> get notificationsMarkedRead$ => _notificationsMarkedReadController.stream;

  set notificationsMarkedRead(bool v) => _notificationsMarkedReadController.add(v);

  bool get notificationsMarkedRead => notificationsMarkedRead$.value;

  ///
  /// Notifications stream
  ///
  final BehaviorSubject<List<ActivityNotificationModel>> _notificationsController =
      BehaviorSubject<List<ActivityNotificationModel>>.seeded([]);

  ValueStream<List<ActivityNotificationModel>> get notifications$ => _notificationsController.stream;

  set notifications(List<ActivityNotificationModel> v) => _notificationsController.add(v);

  List<ActivityNotificationModel> get notifications => notifications$.value;

  ///
  /// Wallet balances stream
  ///

  final BehaviorSubject<List<WalletBalanceModel>> balanceController =
      BehaviorSubject<List<WalletBalanceModel>>.seeded([]);

  set balance(List<WalletBalanceModel> v) => balanceController.add(v);

  List<WalletBalanceModel> get balance => balanceController.value;

  ///
  /// Wallet balances stream
  ///

  final BehaviorSubject<List<double>> assetPriceController = BehaviorSubject<List<double>>.seeded([]);

  set assetPrice(List<double> v) => assetPriceController.add(v);

  List<double> get assetPrice => assetPriceController.value;

  ///

  String get currencyCode => _currencyCode ?? 'USD';

  String get countryCode => _countryCode ?? 'US';

  set countryCode(String val) {
    AppSharedPrefs().setString(AppSharedPrefsKey.countryCode, val);
    updateWith(countryCode: val);
  }

  bool initialized = false;

  Locale get locale => _locale ?? const Locale('en');

  LookupMessages get messagesLocaleTimeago {
    return _lookupMessagesMap.containsKey(langCode) ? _lookupMessagesMap[langCode]! : _lookupMessagesMap['en']!;
  }

  final Map<String, LookupMessages> _lookupMessagesMap = {
    'af': EnMessages(),
    'af_short': EnShortMessages(),
    'en': EnMessages(),
    'en_short': EnShortMessages(),
    'es': EsMessages(),
    'es_short': EsShortMessages(),
    'ru': RuMessages(),
    'ru_short': RuShortMessages(),
    'it': ItMessages(),
    'it_short': ItShortMessages(),
    'ko': KoMessages(),
    'ko_short': KoMessages(),
    'pt': PtBrMessages(),
    'pt_short': PtBrShortMessages(),
    'zh': ZhMessages(),
    'zh_short': ZhMessages(),
  };

  set locale(Locale locale) {
    EasyDebounce.debounce(
      _kLocaleDebounceTag,
      const Duration(milliseconds: 100),
      () {
        updateWith(locale: locale);
        AppSharedPrefs().setString(AppSharedPrefsKey.locale, locale.languageCode);
        _secureStorage.write(SecureStorageKey.locale, locale.languageCode);
        eventBus.fire(LocaleChangedEvent(locale));
      },
    );
  }

  bool get hasPinCode => _hasPinCode;

  set hasPinCode(bool val) {
    updateWith(hasPinCode: val);
  }

  String? get pinCode => _pinCode;

  set pinCode(String? val) {
    _pinCode = val;
    notifyListeners();
  }

  bool get biometricAuthIsOn {
    try {
      return AppSharedPrefs().biometricAuthIsOn ?? false;
    } catch (e) {
      return false;
    }
  }

  set biometricAuthIsOn(bool val) {
    AppSharedPrefs().setBool(AppSharedPrefsKey.biometricAuthIsOn, val: val);
  }

  ThemeMode get themeMode => _themeMode;

  set themeMode(ThemeMode mode) {
    AppSharedPrefs().setString(AppSharedPrefsKey.themeMode, mode.name);
    updateWith(themeMode: mode);
    eventBus.fire(ThemeModeChangedEvent(mode));
  }

  // todo move to service
  Future removePinCode() async {
    await _secureStorage.delete(SecureStorageKey.pin);
  }

  void updateWith({
    Locale? locale,
    ThemeMode? themeMode,
    bool? hasPinCode,
    double? screenHeight,
    String? countryCode,
    bool notify = true,
  }) {
    _locale = locale ?? _locale;
    _screenHeight = screenHeight ?? _screenHeight;
    _themeMode = themeMode ?? _themeMode;
    _hasPinCode = hasPinCode ?? _hasPinCode;
    if (countryCode != null && countryCode != _countryCode) {
      _currencyCode = getCountryCurrencyCode(countryCode);
    }
    _countryCode = countryCode ?? _countryCode;
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _connectionController.close();
    _uploadingController.close();
    _hasUnreadController.close();
    EasyDebounce.cancel(_kLocaleDebounceTag);
  }
}
