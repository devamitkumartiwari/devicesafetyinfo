// Draws the example app's launcher icon (a phone with a shield on its screen, on teal) and
// writes every Android and iOS size. Run from the example folder:
//
//   flutter test tool/generate_app_icon_test.dart
//
// No image tools or extra packages needed: Flutter's own renderer draws the PNGs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Background gradient (also in android/.../drawable/ic_launcher_background.xml).
const _bgLight = Color(0xFF2BD9A8);
const _bgDark = Color(0xFF00796B);

// Phone.
const _body = Colors.white;
const _screenTop = Color(0xFF00695C);
const _screenBottom = Color(0xFF003D33);

// Shield on the screen.
const _shieldLight = Color(0xFF8CFFC9);
const _shieldDark = Color(0xFF1DE9B6);
const _check = Color(0xFF00463B);

/// The shield outline in [box].
Path _shield(Rect box) {
  Offset p(double x, double y) =>
      Offset(box.left + x * box.width, box.top + y * box.height);
  final a = p(0.5, 0.0), b = p(0.96, 0.15), c = p(0.96, 0.46);
  final d = p(0.5, 1.0), e = p(0.04, 0.46), f = p(0.04, 0.15);
  final q1 = p(0.75, 0.10), q2 = p(0.25, 0.10);
  final c1 = p(0.96, 0.76), c2 = p(0.74, 0.93);
  final c3 = p(0.26, 0.93), c4 = p(0.04, 0.76);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..quadraticBezierTo(q1.dx, q1.dy, b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, d.dx, d.dy)
    ..cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, e.dx, e.dy)
    ..lineTo(f.dx, f.dy)
    ..quadraticBezierTo(q2.dx, q2.dy, a.dx, a.dy)
    ..close();
}

/// The check mark inside the shield [box].
Path _checkMark(Rect box) {
  Offset p(double x, double y) =>
      Offset(box.left + x * box.width, box.top + y * box.height);
  final s = p(0.27, 0.50), m = p(0.44, 0.67), e = p(0.75, 0.33);
  return Path()
    ..moveTo(s.dx, s.dy)
    ..lineTo(m.dx, m.dy)
    ..lineTo(e.dx, e.dy);
}

enum _Kind {
  /// iOS: full square, gradient background, no transparency.
  square,

  /// Android 7 and older: rounded square with transparent corners.
  rounded,

  /// Android 8+ adaptive foreground: the phone only, inside the safe zone.
  foreground,

  /// Android 13+ themed icon: one-color silhouette (only alpha is used).
  monochrome,
}

void _paint(Canvas canvas, double size, _Kind kind) {
  final full = Rect.fromLTWH(0, 0, size, size);

  if (kind == _Kind.square || kind == _Kind.rounded) {
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        full.topLeft,
        full.bottomRight,
        const [_bgLight, _bgDark],
      );
    if (kind == _Kind.rounded) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          full.deflate(size * 0.04),
          Radius.circular(size * 0.22),
        ),
        bg,
      );
    } else {
      canvas.drawRect(full, bg);
    }
  }

  // Adaptive icons are 108 units with a 66-unit safe circle: the phone's corners stay in it.
  final h = switch (kind) {
    _Kind.foreground || _Kind.monochrome => size * 0.54,
    _Kind.rounded => size * 0.62,
    _Kind.square => size * 0.68,
  };
  final w = h * 0.60;
  final phone = Rect.fromCenter(
    center: Offset(size / 2, size / 2),
    width: w,
    height: h,
  );
  final body = RRect.fromRectAndRadius(phone, Radius.circular(h * 0.13));
  final screen = RRect.fromRectAndRadius(
    Rect.fromLTRB(
      phone.left + h * 0.045,
      phone.top + h * 0.10,
      phone.right - h * 0.045,
      phone.bottom - h * 0.08,
    ),
    Radius.circular(h * 0.06),
  );
  final speaker = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(phone.center.dx, phone.top + h * 0.05),
      width: h * 0.16,
      height: h * 0.025,
    ),
    Radius.circular(h * 0.0125),
  );
  final shieldBox = Rect.fromCenter(
    center: Offset(screen.center.dx, screen.center.dy + h * 0.005),
    width: h * 0.40,
    height: h * 0.46,
  );
  final shield = _shield(shieldBox);
  final check = _checkMark(shieldBox);
  final checkPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = h * 0.055
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  if (kind == _Kind.monochrome) {
    // Phone outline with the screen cut out, the shield solid, the check cut out.
    canvas.saveLayer(full, Paint());
    final solid = Paint()..color = Colors.white;
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(body, solid);
    canvas.drawRRect(screen, clear);
    canvas.drawRRect(speaker, clear);
    canvas.drawPath(shield, solid);
    canvas.drawPath(check, checkPaint..blendMode = BlendMode.clear);
    canvas.restore();
    return;
  }

  // Soft shadow under the phone.
  canvas.drawRRect(
    body.shift(Offset(0, size * 0.015)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.02),
  );

  // Phone body, speaker and screen.
  canvas.drawRRect(body, Paint()..color = _body);
  canvas.drawRRect(speaker, Paint()..color = const Color(0xFFB2DFDB));
  canvas.drawRRect(
    screen,
    Paint()
      ..shader = ui.Gradient.linear(
        screen.outerRect.topCenter,
        screen.outerRect.bottomCenter,
        const [_screenTop, _screenBottom],
      ),
  );

  // Glow behind the shield, kept inside the screen.
  canvas.save();
  canvas.clipRRect(screen);
  canvas.drawCircle(
    shieldBox.center,
    shieldBox.width * 0.62,
    Paint()
      ..color = _shieldDark.withValues(alpha: 0.30)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.06),
  );
  canvas.restore();

  // Mint shield with a dark check.
  canvas.drawPath(
    shield,
    Paint()
      ..shader = ui.Gradient.linear(
        shieldBox.topLeft,
        shieldBox.bottomRight,
        const [_shieldLight, _shieldDark],
      ),
  );
  canvas.drawPath(check, checkPaint..color = _check);
}

Future<void> _write(String path, int size, _Kind kind) async {
  final recorder = ui.PictureRecorder();
  _paint(Canvas(recorder), size.toDouble(), kind);
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate app icons', (tester) async {
    await tester.runAsync(() async {
      // iOS: every size listed in AppIcon.appiconset.
      const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      const iosIcons = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
      };
      for (final MapEntry(key: name, value: size) in iosIcons.entries) {
        await _write('$ios/$name', size, _Kind.square);
      }

      // Android: legacy icon (48 dp) and adaptive layers (108 dp) per density.
      const res = 'android/app/src/main/res';
      const densities = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      };
      for (final MapEntry(key: d, value: scale) in densities.entries) {
        final legacy = (48 * scale).round();
        final layer = (108 * scale).round();
        await _write('$res/mipmap-$d/ic_launcher.png', legacy, _Kind.rounded);
        await _write(
          '$res/mipmap-$d/ic_launcher_foreground.png',
          layer,
          _Kind.foreground,
        );
        await _write(
          '$res/mipmap-$d/ic_launcher_monochrome.png',
          layer,
          _Kind.monochrome,
        );
      }

      // A large copy for the README or a store listing.
      await _write('tool/app_icon_1024.png', 1024, _Kind.square);
    });
  });
}
