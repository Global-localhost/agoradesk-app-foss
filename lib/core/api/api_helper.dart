import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

mixin ApiHelper {
  static String? parseErrorToString(DioError e) {
    log('++++ApiHelper parseErrorToString -- $e');
    if (e.response != null && e.response!.data is Map) {
      // Parse validation error messages
      if (e.response!.data.containsKey('errors')) {
        final errors = e.response!.data['errors'] as Map<String, dynamic>;
        for (final key in errors.keys) {
          if (errors[key] != null) {
            return errors[key] is String ? errors[key] : errors[key]!.first;
          }
        }
      }

      // Parse summary error message
      if (e.response!.data.containsKey('message')) {
        return e.response!.data['message'];
      }

      if (e.response!.data.containsKey('error')) {
        late final String resError;
        try {
          resError = json.encode(e.response!.data['error']);
        } catch (err) {
          resError = e.response!.data['error'];
        }
        return resError;
      }
    } else if (e.toString().contains('connectTimeout')) {
      return 'Timeout!';
    }
    return null;
  }

  static ApiError parseErrorToApiError(dynamic err, String? objectStr) {
    debugPrint('[++++parseErrorToApiError objectStr] $err');
    try {
      final e = err as DioError;
      String message = '';
      if (e.type == DioErrorType.connectTimeout) {
        Map<String, dynamic> messageMap = {'message': 'Connection timeout'};

        return ApiError(
          statusCode: 400,
          errorCode: 4001,
          message: messageMap,
          response: e.response,
          captchaCookie: e.response?.headers['set-cookie']![0].split(';')[0],
        );
      }
      if (e.error != null && e.error is String) {
        late Map<String, dynamic> messageMap;
        try {
          messageMap = json.decode(json.decode(e.error));
        } catch (e2) {
          try {
            messageMap = json.decode(e.response.toString())['error'];
          } catch (e3) {
            debugPrint('[++++parseErrorToApiError2] - $e2');
            debugPrint('[++++parseErrorToApiError3] - $e3');
            messageMap = {'message': 'Unknow error'};
          }
        }

        return ApiError(
          statusCode: e.response!.statusCode!,
          errorCode: messageMap['error_code'],
          message: messageMap,
          response: e.response,
          captchaCookie: e.response?.headers['set-cookie']![0].split(';')[0],
        );
      }

      if (e.response != null && e.response!.data is Map) {
        // Parse validation error messages
        if (e.response!.data.containsKey('errors')) {
          final errors = e.response!.data['errors'] as Map<String, dynamic>;
          for (final key in errors.keys) {
            if (errors[key] != null) {
              return errors[key] is String ? errors[key] : errors[key]!.first;
            }
          }
        }

        // Parse summary error message
        if (e.response!.data.containsKey('message')) {
          message = e.response!.data['message'];
        } else if (e.response!.data.containsKey('error')) {
          message = json.encode(e.response!.data['error']);
        }
        late Map<String, dynamic> messageMap;
        try {
          messageMap = json.decode(message);
        } catch (e) {
          messageMap = {'message': message};
        }
        return ApiError(
          statusCode: e.response!.statusCode!,
          errorCode: messageMap['error_code'],
          message: messageMap,
          response: e.response,
          captchaCookie: e.response?.headers['set-cookie']![0].split(';')[0],
        );
      }

      ///
      /// parse no connection state
      ///
      if (e.toString().contains('SocketException: Failed host lookup')) {
        return ApiError(
          statusCode: 7000,
          errorCode: 7000,
          message: {'error_code': 4000},
          response: e.response,
          captchaCookie: e.response?.headers['set-cookie']![0].split(';')[0],
        );
      }
      return ApiError(statusCode: 520, message: {'message': 'Unknown error'});
    } catch (e) {
      return ApiError(statusCode: 520, message: {'message': 'Unknown error'});
    }
  }
}

class ApiError {
  ApiError({
    required this.statusCode,
    this.errorCode,
    required this.message,
    this.response,
    this.captchaCookie,
    this.captchaLocalPath,
  });

  final int statusCode;
  final int? errorCode;
  final Map<String, dynamic> message;
  final Response? response;
  final String? captchaCookie;
  final String? captchaLocalPath;

  factory ApiError.unknown() => ApiError(statusCode: 520, message: {'message': 'Unknown error'});
}
