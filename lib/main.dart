import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // qr_code_scanner_plus disposes its controller by calling stopCamera()
  // unawaited when the QRView unmounts. iOS tears down the native scanner view
  // first, so that call returns CameraException(404, 'No barcode scanner found')
  // as an unhandled async error every time the QR tab is left. It is a benign
  // teardown race with no functional effect, so swallow exactly that one; every
  // other error falls through to Flutter's default handling.
  final previousOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is CameraException && error.code == '404') return true;
    return previousOnError?.call(error, stack) ?? false;
  };
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0B0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: KubelyApp()));
}
