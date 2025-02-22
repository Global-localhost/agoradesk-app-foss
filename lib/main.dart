import 'dart:io';
import 'dart:math' as math;

import 'package:agoradesk/core/app.dart';
import 'package:agoradesk/core/app_hive.dart';
import 'package:agoradesk/core/app_parameters.dart';
import 'package:agoradesk/core/app_shared_prefs.dart';
import 'package:agoradesk/core/flavor_type.dart';
import 'package:agoradesk/core/secure_storage.dart';
import 'package:agoradesk/core/services/notifications/models/push_model.dart';
import 'package:agoradesk/init_app_parameters.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:intl/intl_standalone.dart' if (dart.library.html) 'package:intl/intl_browser.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/translations/foreground_messages_mixin.dart';
import 'firebase_options_agoradesk.dart' as agoradesk_options;
import 'firebase_options_localmonero.dart' as localmonero_options;

const kNotificationsChannel = 'trades_channel';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const String flavorString = String.fromEnvironment('app.flavor');
  const flavor = flavorString == 'localmonero' ? FlavorType.localmonero : FlavorType.agoradesk;
  const String includeFcmString = String.fromEnvironment('app.includeFcm');
  final includeFcm = includeFcmString != 'false' || Platform.isIOS;
  const String checkUpdates = String.fromEnvironment('app.checkUpdates');
  const isCheckUpdates = checkUpdates == 'true';
  if (includeFcm) {
    if (flavor == FlavorType.localmonero) {
      await Firebase.initializeApp(
        options: localmonero_options.DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp(
        options: agoradesk_options.DefaultFirebaseOptions.currentPlatform,
      );
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } else {
    Permission.notification.request();
  }

  ///
  /// common initializations
  ///
  await SecureStorage.ensureInitialized();
  await AppSharedPrefs.ensureInitialized();
  await AppHive.ensureInitialized();
  await findSystemLocale();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    if (kDebugMode) DeviceOrientation.portraitDown,
  ]);

  // Enables full screen mode by switching to [SystemUiMode.immersive] as system ui mode.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  ///
  /// Init awesome notofications
  ///
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: kNotificationsChannel,
        channelName: 'Trades channel',
        channelDescription: 'Notifications about trades',
        importance: NotificationImportance.Max,
        channelShowBadge: true,
      ),
    ],
  );

  ///
  /// if the app is terminated and user presses to a notification
  /// here we got payload info
  ///
  bool appRanFromPush = false;
  String? tradeId;
  ReceivedAction? receivedAction = await AwesomeNotifications().getInitialNotificationAction();

  if (receivedAction != null && receivedAction.payload != null) {
    final PushModel push = PushModel.fromJson(receivedAction.payload!);
    if (push.objectId != null && push.objectId!.isNotEmpty) {
      appRanFromPush = true;
      tradeId = push.objectId;
    }
  }

  ///
  /// Initializations that are depend on flavor
  ///

  final bool isGoogleAvailable = includeFcm ? await checkGoogleAvailable() : false;
  GetIt.I.registerSingleton<AppParameters>(
    initAppParameters(
      flavor,
      isGoogleAvailable,
      includeFcm,
      appRanFromPush,
      tradeId,
      isCheckUpdates,
    ),
  );

  final bool sentryIsOn = AppSharedPrefs().sentryIsOn != false;

  if (kDebugMode || includeFcm == false || sentryIsOn == false) {
    runApp(const App());
    return;
  }
  SentryFlutter.init(
    (options) {
      options
        ..dsn = GetIt.I<AppParameters>().sentryDsn
        ..reportSilentFlutterErrors = true
        ..attachStacktrace = false
        ..enableAutoSessionTracking = false
        ..tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(const App()),
  );
}

///
/// detect does Google Play available or not
///
@pragma('vm:entry-point')
Future<bool> checkGoogleAvailable() async {
  // We use this check to run foreground isolate task on Android.
  // So, in case it is not Android we returns true, because with true isolate won't start.
  if (Platform.isAndroid == false) {
    return true;
  }

  final GooglePlayServicesAvailability gPlayState =
      await GoogleApiAvailability.instance.checkGooglePlayServicesAvailability();
  List<GooglePlayServicesAvailability> googleUnavalableStates = [
    GooglePlayServicesAvailability.serviceInvalid,
    GooglePlayServicesAvailability.notAvailableOnPlatform,
    GooglePlayServicesAvailability.serviceDisabled,
    GooglePlayServicesAvailability.serviceMissing,
    GooglePlayServicesAvailability.unknown,
  ];
  if (googleUnavalableStates.contains(gPlayState)) {
    return false;
  }
  return true;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await SecureStorage.ensureInitialized();
    final SecureStorage _secureStorage = SecureStorage();
    final locale = await _secureStorage.read(SecureStorageKey.locale);
    final String langCode = locale ?? Platform.localeName.substring(0, 2);
    final PushModel push = PushModel.fromJson(message.data);
    final awesomeMessageId = math.Random().nextInt(10000000);
    final Map<String, String> payload = push.toJson().map((key, value) => MapEntry(key, value?.toString() ?? ''));
    final bool res = await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: awesomeMessageId,
        channelKey: kNotificationsChannel,
        title: ForegroundMessagesMixin.translatedNotificationTitle(push, langCode),
        body: push.msg,
        notificationLayout: NotificationLayout.Default,
        payload: payload,
      ),
    );
    if (res) {
      String barMessagesString = await _secureStorage.read(SecureStorageKey.pushAndObjectIds) ?? '';
      barMessagesString += ';$awesomeMessageId:${push.objectId}';
      _secureStorage.write(SecureStorageKey.pushAndObjectIds, barMessagesString);
    }
  } catch (e) {
    debugPrint('++++_firebaseMessagingBackgroundHandler error $e');
  }
}
