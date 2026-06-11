import 'dart:async';
import 'package:universal_io/io.dart'; 
import 'package:flutter/foundation.dart'; 

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void>? _initFuture;
  static bool _initialized = false;
  static int _nextNotificationId = 0;

  // Web-Safe Platform Checks
  static bool get _isDesktopPlatform {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  static bool get _usesFlutterLocalNotifications {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Thread-safe singleton initializer
  static Future<void> init() {
    _initFuture ??= _performInit();
    return _initFuture!;
  }

  static Future<void> _performInit() async {
    try {
      if (_isDesktopPlatform) {
        await localNotifier.setup(
          appName: 'Remind Me',
          shortcutPolicy: ShortcutPolicy.ignore, 
        );
      } else if (_usesFlutterLocalNotifications) {
        // NOTE: Ensure '@mipmap/ic_launcher' exists, or replace with a dedicated white status icon
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestSoundPermission: true,
        );

        await _flutterNotifications.initialize(
          const InitializationSettings(android: androidSettings, iOS: iosSettings),
        );

        // Fix: Explicitly request permission on Android 13+ (API 33+)
        if (Platform.isAndroid) {
          final androidPlugin = _flutterNotifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          if (androidPlugin != null) {
            await androidPlugin.requestNotificationsPermission();
          }
        }
      }
    } catch (e) {
      debugPrint("Notification init error (Continuing safely): $e");
    } finally {
      _initialized = true; 
    }
  }

  static Future<void> showNotification(
    String title,
    String body, {
    String? identifier,
    bool playSound = true,
  }) async {
    if (!_initialized) {
      await init();
    }

    try {
      if (_usesFlutterLocalNotifications) {
        // Fix: Keep the ID safely in bounds of a signed 32-bit integer
        final int id = _nextNotificationId;
        _nextNotificationId = (_nextNotificationId + 1) % 100000;

        await _flutterNotifications.show(
          id,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'schedule_alerts',
              'Schedule alerts',
              channelDescription: 'Reminders when a time block starts or ends.',
              importance: playSound ? Importance.max : Importance.low,
              priority: playSound ? Priority.high : Priority.defaultPriority,
              playSound: playSound,
              enableVibration: playSound,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: playSound,
            ),
          ),
        );
        return;
      }

      if (_isDesktopPlatform) {
        LocalNotification notification = LocalNotification(
          identifier: identifier,
          title: title,
          body: body,
          silent: !playSound,
        );

        notification.onClick = () {
          unawaited(_showDesktopWindow());
        };

        notification.show();
      } else if (kIsWeb) {
        // Fallback or HTML5 notification interop can be handled here if needed
        debugPrint("WEB NOTIFICATION TRIGGERED: $title - $body");
      }
    } catch (e) {
      debugPrint("Failed to show notification to OS: $e");
    }
  }

  static Future<void> _showDesktopWindow() async {
    if (!_isDesktopPlatform) return;
    try {
      // Fix: Un-minimize first if the window is currently minimized
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('WindowManager error: $e');
    }
  }
}
