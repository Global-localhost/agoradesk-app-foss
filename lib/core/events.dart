import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';

EventBus eventBus = EventBus();

///
/// Common events
///

class LogOutEvent {
  const LogOutEvent();
}

class BeforeAppInitEvent {
  const BeforeAppInitEvent();
}

class AfterAppInitEvent {
  const AfterAppInitEvent();
}

class LocaleChangedEvent {
  final Locale? locale;

  const LocaleChangedEvent(this.locale);
}

class ThemeModeChangedEvent {
  final ThemeMode? mode;

  const ThemeModeChangedEvent(this.mode);
}

class DisplayCaptchaEvent {
  const DisplayCaptchaEvent({
    required this.cookie1,
    required this.cookie2,
    required this.body,
  });

  final String cookie1;
  final String cookie2;
  final String? body;
}

///
/// Push events
///

class FcmTokenChangedEvent {
  final String? token;

  const FcmTokenChangedEvent(this.token);
}

class PushReceivedEvent {
  final String title;
  final String body;
  final Map<String, dynamic>? data;

  const PushReceivedEvent({
    required this.title,
    required this.body,
    this.data,
  });
}

class Display503Event {
  const Display503Event();
}

///
/// Flash events
///

enum FlashEventType { error, success, info }

class FlashEvent {
  final FlashEventType type;
  final String? message;

  const FlashEvent._(this.type, this.message);

  factory FlashEvent.error(String? message) {
    return FlashEvent._(FlashEventType.error, message);
  }

  factory FlashEvent.success(String? message) {
    return FlashEvent._(FlashEventType.success, message);
  }

  factory FlashEvent.info(String? message) {
    return FlashEvent._(FlashEventType.info, message);
  }
}

///
/// Awesome notifications message clicked on the phone tray
///

class AwesomeMessageClickedEvent {
  final String? tradeId;

  const AwesomeMessageClickedEvent(this.tradeId);
}
