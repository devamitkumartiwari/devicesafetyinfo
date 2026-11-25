// Draws the example app's launcher icon (a phone with a shield on its screen, on teal) and
// writes it for both platforms. Run from the example folder:
//
//   flutter test tool/generate_app_icon_test.dart
//
// Output:
// * iOS: one 1024 px opaque PNG ("single size" app icon; Xcode derives every other size).
// * Android: vector drawables (adaptive foreground + monochrome for Android 8+, and a legacy
//   icon for Android 7) instead of a PNG per density. The soft shadow and glow, which are
//   blurs in the PNG, are approximated with stacked translucent shapes and a radial gradient.
// * build/icon_preview/*.svg: SVG twins of the Android vectors, to eyeball them (not committed).
//
// No image tools or extra packages needed: Flutter's renderer draws the PNG, and both
// platforms use the same geometry ([_Layout]).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Background gradient (also in android/.../drawable/ic_launcher_background.xml).
const _bgLight = Color(0xFF2BD9A8);
const _bgDark = Color(0xFF00796B);

// Phone.
const _body = Colors.white;
const _speakerColor = Color(0xFFB2DFDB);
const _screenTop = Color(0xFF00695C);
const _screenBottom = Color(0xFF003D33);

// Shield on the screen.
const _shieldLight = Color(0xFF8CFFC9);
const _shieldDark = Color(0xFF1DE9B6);
const _check = Color(0xFF00463B);

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

// ---------------------------------------------------------------------------------------------
// Geometry shared by the PNG painter and the vector writer.
// ---------------------------------------------------------------------------------------------

/// One path command: `M`, `L`, `Q`, `C` or `Z` with its points.
typedef _Seg = (String, List<Offset>);

/// Where everything goes for an icon of [size] units.
class _Layout {
  _Layout(this.size, _Kind kind) {
    // Adaptive icons are 108 units with a 66-unit safe circle: the phone's corners stay in it.
    h = switch (kind) {
      _Kind.foreground || _Kind.monochrome => size * 0.54,
      _Kind.rounded => size * 0.62,
      _Kind.square => size * 0.68,
    };
    final w = h * 0.60;
    phone = Rect.fromCenter(
      center: Offset(size / 2, size / 2),
      width: w,
      height: h,
    );
    body = RRect.fromRectAndRadius(phone, Radius.circular(h * 0.13));
    screen = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        phone.left + h * 0.045,
        phone.top + h * 0.10,
        phone.right - h * 0.045,
        phone.bottom - h * 0.08,
      ),
      Radius.circular(h * 0.06),
    );
    speaker = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(phone.center.dx, phone.top + h * 0.05),
        width: h * 0.16,
        height: h * 0.025,
      ),
      Radius.circular(h * 0.0125),
    );
    shieldBox = Rect.fromCenter(
      center: Offset(screen.center.dx, screen.center.dy + h * 0.005),
      width: h * 0.40,
      height: h * 0.46,
    );
  }

  final double size;
  late final double h;
  late final Rect phone;
  late final RRect body, screen, speaker;
  late final Rect shieldBox;

  Rect get full => Rect.fromLTWH(0, 0, size, size);
  RRect get roundedBackground => RRect.fromRectAndRadius(
    full.deflate(size * 0.04),
    Radius.circular(size * 0.22),
  );
  double get checkWidth => h * 0.055;
  double get shadowOffset => size * 0.015;
  double get shadowBlur => size * 0.02;
  double get glowRadius => shieldBox.width * 0.62;
  double get glowBlur => h * 0.06;

  /// The shield outline.
  List<_Seg> get shield {
    final box = shieldBox;
    Offset p(double x, double y) =>
        Offset(box.left + x * box.width, box.top + y * box.height);
    final a = p(0.5, 0.0), b = p(0.96, 0.15), c = p(0.96, 0.46);
    final d = p(0.5, 1.0), e = p(0.04, 0.46), f = p(0.04, 0.15);
    return [
      ('M', [a]),
      ('Q', [p(0.75, 0.10), b]),
      ('L', [c]),
      ('C', [p(0.96, 0.76), p(0.74, 0.93), d]),
      ('C', [p(0.26, 0.93), p(0.04, 0.76), e]),
      ('L', [f]),
      ('Q', [p(0.25, 0.10), a]),
      ('Z', []),
    ];
  }

  /// The check mark's centerline: start, corner, end.
  (Offset, Offset, Offset) get checkPoints {
    final box = shieldBox;
    Offset p(double x, double y) =>
        Offset(box.left + x * box.width, box.top + y * box.height);
    return (p(0.27, 0.50), p(0.44, 0.67), p(0.75, 0.33));
  }

  List<_Seg> get checkLine {
    final (s, m, e) = checkPoints;
    return [
      ('M', [s]),
      ('L', [m]),
      ('L', [e]),
    ];
  }
}

Path _toPath(List<_Seg> segs) {
  final path = Path();
  for (final (op, p) in segs) {
    switch (op) {
      case 'M':
        path.moveTo(p[0].dx, p[0].dy);
      case 'L':
        path.lineTo(p[0].dx, p[0].dy);
      case 'Q':
        path.quadraticBezierTo(p[0].dx, p[0].dy, p[1].dx, p[1].dy);
      case 'C':
        path.cubicTo(p[0].dx, p[0].dy, p[1].dx, p[1].dy, p[2].dx, p[2].dy);
      case 'Z':
        path.close();
    }
  }
  return path;
}

// ---------------------------------------------------------------------------------------------
// PNG (iOS).
// ---------------------------------------------------------------------------------------------

void _paint(Canvas canvas, double size, _Kind kind) {
  final l = _Layout(size, kind);

  if (kind == _Kind.square || kind == _Kind.rounded) {
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        l.full.topLeft,
        l.full.bottomRight,
        const [_bgLight, _bgDark],
      );
    if (kind == _Kind.rounded) {
      canvas.drawRRect(l.roundedBackground, bg);
    } else {
      canvas.drawRect(l.full, bg);
    }
  }

  final shield = _toPath(l.shield);
  final check = _toPath(l.checkLine);
  final checkPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = l.checkWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  // Soft shadow under the phone.
  canvas.drawRRect(
    l.body.shift(Offset(0, l.shadowOffset)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, l.shadowBlur),
  );

  // Phone body, speaker and screen.
  canvas.drawRRect(l.body, Paint()..color = _body);
  canvas.drawRRect(l.speaker, Paint()..color = _speakerColor);
  canvas.drawRRect(
    l.screen,
    Paint()
      ..shader = ui.Gradient.linear(
        l.screen.outerRect.topCenter,
        l.screen.outerRect.bottomCenter,
        const [_screenTop, _screenBottom],
      ),
  );

  // Glow behind the shield, kept inside the screen.
  canvas.save();
  canvas.clipRRect(l.screen);
  canvas.drawCircle(
    l.shieldBox.center,
    l.glowRadius,
    Paint()
      ..color = _shieldDark.withValues(alpha: 0.30)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, l.glowBlur),
  );
  canvas.restore();

  // Mint shield with a dark check.
  canvas.drawPath(
    shield,
    Paint()
      ..shader = ui.Gradient.linear(
        l.shieldBox.topLeft,
        l.shieldBox.bottomRight,
        const [_shieldLight, _shieldDark],
      ),
  );
  canvas.drawPath(check, checkPaint..color = _check);
}

Future<void> _writePng(String path, int size, _Kind kind) async {
  final recorder = ui.PictureRecorder();
  _paint(Canvas(recorder), size.toDouble(), kind);
  final image = await recorder.endRecording().toImage(size, size);
  // iOS icons must be opaque, and App Store Connect rejects a 1024 px icon that has an alpha
  // channel at all. Flutter's PNG encoder always writes RGBA, so encode RGB ourselves.
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(_encodeOpaquePng(rgba!.buffer.asUint8List(), size, size));
}

/// Encodes fully opaque RGBA pixels as an 8-bit RGB PNG (color type 2, no alpha channel),
/// choosing the PNG row filter per row and compressing at zlib's highest level.
Uint8List _encodeOpaquePng(Uint8List rgba, int width, int height) {
  final stride = width * 3;
  final rows = List.generate(height, (y) {
    final row = Uint8List(stride);
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      if (rgba[i + 3] != 255) {
        throw StateError('iOS icon pixel ($x, $y) is not opaque');
      }
      row.setRange(x * 3, x * 3 + 3, rgba, i);
    }
    return row;
  });

  // Filtered scanlines: one filter-type byte, then the filtered row. The filter with the
  // smallest sum of absolute (signed) bytes is picked, the usual PNG heuristic.
  final raw = BytesBuilder(copy: false);
  final zero = Uint8List(stride);
  for (var y = 0; y < height; y++) {
    final cur = rows[y], up = y > 0 ? rows[y - 1] : zero;
    Uint8List? best;
    var bestType = 0, bestCost = 1 << 62;
    for (var type = 0; type <= 4; type++) {
      final out = Uint8List(stride);
      var cost = 0;
      for (var i = 0; i < stride; i++) {
        final a = i >= 3 ? cur[i - 3] : 0, b = up[i], c = i >= 3 ? up[i - 3] : 0;
        final predictor = switch (type) {
          0 => 0,
          1 => a,
          2 => b,
          3 => (a + b) >> 1,
          _ => _paeth(a, b, c),
        };
        final v = (cur[i] - predictor) & 0xFF;
        out[i] = v;
        cost += v < 128 ? v : 256 - v;
      }
      if (cost < bestCost) {
        bestCost = cost;
        bestType = type;
        best = out;
      }
    }
    raw
      ..addByte(bestType)
      ..add(best!);
  }

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2) // color type: RGB, no alpha
    ..setUint8(10, 0) // deflate
    ..setUint8(11, 0) // adaptive filtering
    ..setUint8(12, 0); // no interlace
  final idat = ZLibEncoder(level: 9).convert(raw.takeBytes());

  return (BytesBuilder(copy: false)
        ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(_chunk('IDAT', idat))
        ..add(_chunk('IEND', const [])))
      .takeBytes();
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

/// One PNG chunk: length, type, data, CRC-32 of type + data.
Uint8List _chunk(String type, List<int> data) {
  final out = ByteData(12 + data.length)..setUint32(0, data.length);
  final bytes = out.buffer.asUint8List()
    ..setRange(4, 8, type.codeUnits)
    ..setRange(8, 8 + data.length, data);
  out.setUint32(8 + data.length, _crc32(bytes.sublist(4, 8 + data.length)));
  return bytes;
}

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

// ---------------------------------------------------------------------------------------------
// Vectors (Android VectorDrawable, plus SVG previews).
// ---------------------------------------------------------------------------------------------

sealed class _Fill {
  const _Fill();
}

final class _Solid extends _Fill {
  const _Solid(this.color);
  final Color color;
}

final class _Linear extends _Fill {
  const _Linear(this.from, this.to, this.start, this.end);
  final Offset from, to;
  final Color start, end;
}

final class _Radial extends _Fill {
  const _Radial(this.center, this.radius, this.stops);
  final Offset center;
  final double radius;
  final List<(double, Color)> stops;
}

class _Shape {
  const _Shape(
    this.d, {
    this.fill,
    this.stroke,
    this.strokeWidth = 0,
    this.evenOdd = false,
    this.clip,
  });

  final String d;
  final _Fill? fill;
  final Color? stroke;
  final double strokeWidth;
  final bool evenOdd;

  /// Path data this shape is clipped to.
  final String? clip;
}

String _n(double v) {
  final s = v.toStringAsFixed(2);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

String _pt(Offset p) => '${_n(p.dx)},${_n(p.dy)}';

String _d(List<_Seg> segs) => segs
    .map((s) => s.$1 == 'Z' ? 'Z' : '${s.$1}${s.$2.map(_pt).join(' ')}')
    .join(' ');

/// A rounded rectangle as path data (circular arcs).
String _rrectD(RRect r) {
  final rad = r.tlRadiusX;
  final (x, y, w, h) = (r.left, r.top, r.width, r.height);
  final a = '${_n(rad)},${_n(rad)} 0 0 1';
  return 'M${_n(x + rad)},${_n(y)} H${_n(x + w - rad)} A$a ${_n(x + w)},${_n(y + rad)} '
      'V${_n(y + h - rad)} A$a ${_n(x + w - rad)},${_n(y + h)} '
      'H${_n(x + rad)} A$a ${_n(x)},${_n(y + h - rad)} '
      'V${_n(y + rad)} A$a ${_n(x + rad)},${_n(y)} Z';
}

String _circleD(Offset c, double r) =>
    'M${_n(c.dx - r)},${_n(c.dy)} A${_n(r)},${_n(r)} 0 1 1 ${_n(c.dx + r)},${_n(c.dy)} '
    'A${_n(r)},${_n(r)} 0 1 1 ${_n(c.dx - r)},${_n(c.dy)} Z';

/// The outline of the check mark stroked with round caps and joins, as one closed polygon.
/// The monochrome icon cuts it out of the shield (even-odd fill), which a stroke can't do.
String _checkOutlineD(_Layout l) {
  final (s, m, e) = l.checkPoints;
  final r = l.checkWidth / 2;
  Offset unit(Offset v) => v / v.distance;
  Offset normal(Offset d) => Offset(-d.dy, d.dx);
  final d1 = unit(m - s), d2 = unit(e - m);
  final n1 = normal(d1), n2 = normal(d2);
  final cross = d1.dx * d2.dy - d1.dy * d2.dx;
  // Turning toward +normal makes that side the inside of the corner.
  final insideSign = cross > 0 ? 1.0 : -1.0;
  final dot = d1.dx * d2.dx + d1.dy * d2.dy;
  final miter = (n1 + n2) * (r / (1 + dot));

  final pts = <Offset>[];
  // Arc around [c] from angle a0 by sweep, as line points (excluding the start).
  void arc(Offset c, double a0, double sweep) {
    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      final a = a0 + sweep * i / steps;
      pts.add(c + Offset(math.cos(a), math.sin(a)) * r);
    }
  }

  double angle(Offset v) => math.atan2(v.dy, v.dx);
  double shortSweep(double from, double to) {
    var d = to - from;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    return d;
  }

  // Side +n: along the first segment, around the corner, along the second.
  pts.add(s + n1 * r);
  if (insideSign > 0) {
    pts.add(m + miter);
  } else {
    pts.add(m + n1 * r);
    arc(m, angle(n1), shortSweep(angle(n1), angle(n2)));
  }
  pts.add(e + n2 * r);
  // Round cap at the end: half a turn through the direction of travel.
  final endSweep = shortSweep(angle(n2), angle(d2)) > 0 ? math.pi : -math.pi;
  arc(e, angle(n2), endSweep);
  // Side -n: back along the second segment, around the corner, back along the first.
  if (insideSign < 0) {
    pts.add(m - miter);
  } else {
    pts.add(m - n2 * r);
    arc(m, angle(-n2), shortSweep(angle(-n2), angle(-n1)));
  }
  pts.add(s - n1 * r);
  // Round cap at the start: half a turn through the reverse direction.
  final startSweep = shortSweep(angle(-n1), angle(-d1)) > 0 ? math.pi : -math.pi;
  arc(s, angle(-n1), startSweep);

  return 'M${pts.map(_pt).join(' L')} Z';
}

/// The shapes for an Android vector icon of [size] units.
List<_Shape> _vectorShapes(double size, _Kind kind) {
  final l = _Layout(size, kind);
  final shield = _d(l.shield);

  if (kind == _Kind.monochrome) {
    // Only alpha matters: phone outline with the screen and speaker cut out, then the shield
    // with the check cut out.
    const white = _Solid(Colors.white);
    return [
      _Shape(
        '${_rrectD(l.body)} ${_rrectD(l.screen)} ${_rrectD(l.speaker)}',
        fill: white,
        evenOdd: true,
      ),
      _Shape('$shield ${_checkOutlineD(l)}', fill: white, evenOdd: true),
    ];
  }

  return [
    if (kind == _Kind.rounded)
      _Shape(
        _rrectD(l.roundedBackground),
        fill: _Linear(l.full.topLeft, l.full.bottomRight, _bgLight, _bgDark),
      ),
    // Soft shadow: a few slightly larger, faint copies of the body (a blur isn't available).
    for (final grow in [1.0, 0.75, 0.5, 0.3, 0.12])
      _Shape(
        _rrectD(
          l.body
              .shift(Offset(0, l.shadowOffset))
              .inflate(l.shadowBlur * grow),
        ),
        fill: _Solid(Colors.black.withValues(alpha: 0.055)),
      ),
    _Shape(_rrectD(l.body), fill: const _Solid(_body)),
    _Shape(_rrectD(l.speaker), fill: const _Solid(_speakerColor)),
    _Shape(
      _rrectD(l.screen),
      fill: _Linear(
        l.screen.outerRect.topCenter,
        l.screen.outerRect.bottomCenter,
        _screenTop,
        _screenBottom,
      ),
    ),
    // Glow: a blurred disc is flat inside and fades over about two blur radii at the edge.
    () {
      final outer = l.glowRadius + 2 * l.glowBlur;
      final glow = _shieldDark.withValues(alpha: 0.30);
      return _Shape(
        _circleD(l.shieldBox.center, outer),
        fill: _Radial(l.shieldBox.center, outer, [
          (0, glow),
          ((l.glowRadius - l.glowBlur) / outer, glow),
          (1, glow.withValues(alpha: 0)),
        ]),
        clip: _rrectD(l.screen),
      );
    }(),
    _Shape(
      shield,
      fill: _Linear(
        l.shieldBox.topLeft,
        l.shieldBox.bottomRight,
        _shieldLight,
        _shieldDark,
      ),
    ),
    _Shape(_d(l.checkLine), stroke: _check, strokeWidth: l.checkWidth),
  ];
}

String _argb(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

String _vectorDrawable(double size, _Kind kind, {required double dp}) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln(
      '<!-- Generated by tool/generate_app_icon_test.dart; edit that file, not this one. -->',
    )
    ..writeln(
      '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
    )
    ..writeln('    xmlns:aapt="http://schemas.android.com/aapt"')
    ..writeln('    android:width="${_n(dp)}dp"')
    ..writeln('    android:height="${_n(dp)}dp"')
    ..writeln('    android:viewportWidth="${_n(size)}"')
    ..writeln('    android:viewportHeight="${_n(size)}">');

  for (final s in _vectorShapes(size, kind)) {
    final indent = s.clip == null ? '    ' : '        ';
    if (s.clip != null) {
      b
        ..writeln('    <group>')
        ..writeln('        <clip-path android:pathData="${s.clip}" />');
    }
    b.write('$indent<path\n$indent    android:pathData="${s.d}"');
    if (s.evenOdd) b.write('\n$indent    android:fillType="evenOdd"');
    if (s.stroke case final stroke?) {
      b.write(
        '\n$indent    android:strokeColor="${_argb(stroke)}"'
        '\n$indent    android:strokeWidth="${_n(s.strokeWidth)}"'
        '\n$indent    android:strokeLineCap="round"'
        '\n$indent    android:strokeLineJoin="round"',
      );
    }
    switch (s.fill) {
      case _Solid(:final color):
        b.writeln('\n$indent    android:fillColor="${_argb(color)}" />');
      case _Linear(:final from, :final to, :final start, :final end):
        b.writeln(
          '>\n$indent    <aapt:attr name="android:fillColor">'
          '\n$indent        <gradient android:type="linear"'
          ' android:startX="${_n(from.dx)}" android:startY="${_n(from.dy)}"'
          ' android:endX="${_n(to.dx)}" android:endY="${_n(to.dy)}"'
          ' android:startColor="${_argb(start)}" android:endColor="${_argb(end)}" />'
          '\n$indent    </aapt:attr>\n$indent</path>',
        );
      case _Radial(:final center, :final radius, :final stops):
        b
          ..writeln(
            '>\n$indent    <aapt:attr name="android:fillColor">'
            '\n$indent        <gradient android:type="radial"'
            ' android:centerX="${_n(center.dx)}" android:centerY="${_n(center.dy)}"'
            ' android:gradientRadius="${_n(radius)}">',
          )
          ..writeAll([
            for (final (offset, color) in stops)
              '$indent            <item android:offset="${_n(offset)}"'
                  ' android:color="${_argb(color)}" />\n',
          ])
          ..writeln(
            '$indent        </gradient>\n$indent    </aapt:attr>\n$indent</path>',
          );
      case null:
        b.writeln(' />');
    }
    if (s.clip != null) b.writeln('    </group>');
  }
  b.writeln('</vector>');
  return b.toString();
}

/// An SVG twin of [_vectorDrawable], for previewing the Android icon in a browser.
String _svg(double size, _Kind kind) {
  String rgb(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  String op(Color c) => _n(c.a);
  final defs = StringBuffer(), body = StringBuffer();
  var id = 0;
  for (final s in _vectorShapes(size, kind)) {
    var fill = 'none';
    switch (s.fill) {
      case _Solid(:final color):
        fill = '${rgb(color)}" fill-opacity="${op(color)}';
      case _Linear(:final from, :final to, :final start, :final end):
        defs.write(
          '<linearGradient id="g$id" gradientUnits="userSpaceOnUse" '
          'x1="${_n(from.dx)}" y1="${_n(from.dy)}" x2="${_n(to.dx)}" y2="${_n(to.dy)}">'
          '<stop offset="0" stop-color="${rgb(start)}" stop-opacity="${op(start)}"/>'
          '<stop offset="1" stop-color="${rgb(end)}" stop-opacity="${op(end)}"/>'
          '</linearGradient>',
        );
        fill = 'url(#g$id)';
      case _Radial(:final center, :final radius, :final stops):
        defs.write(
          '<radialGradient id="g$id" gradientUnits="userSpaceOnUse" '
          'cx="${_n(center.dx)}" cy="${_n(center.dy)}" r="${_n(radius)}">',
        );
        for (final (offset, color) in stops) {
          defs.write(
            '<stop offset="${_n(offset)}" stop-color="${rgb(color)}" '
            'stop-opacity="${op(color)}"/>',
          );
        }
        defs.write('</radialGradient>');
        fill = 'url(#g$id)';
      case null:
        break;
    }
    var clip = '';
    if (s.clip != null) {
      defs.write('<clipPath id="c$id"><path d="${s.clip}"/></clipPath>');
      clip = ' clip-path="url(#c$id)"';
    }
    final stroke = s.stroke == null
        ? ''
        : ' stroke="${rgb(s.stroke!)}" stroke-width="${_n(s.strokeWidth)}" '
              'stroke-linecap="round" stroke-linejoin="round"';
    final rule = s.evenOdd ? ' fill-rule="evenodd"' : '';
    body.write('<path d="${s.d}" fill="$fill"$rule$stroke$clip/>');
    id++;
  }
  // Adaptive layers sit on the teal background; show them on it, as a launcher would.
  final bg = kind == _Kind.foreground
      ? '<rect width="${_n(size)}" height="${_n(size)}" fill="url(#bg)"/>'
      : kind == _Kind.monochrome
      ? '<rect width="${_n(size)}" height="${_n(size)}" fill="#3c4043"/>'
      : '';
  return '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" '
      'viewBox="0 0 ${_n(size)} ${_n(size)}"><defs>$defs'
      '<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0" stop-color="${rgb(_bgLight)}"/>'
      '<stop offset="1" stop-color="${rgb(_bgDark)}"/></linearGradient>'
      '</defs>$bg$body</svg>';
}

void _writeText(String path, String text) => File(path)
  ..createSync(recursive: true)
  ..writeAsStringSync(text);

void main() {
  testWidgets('generate app icons', (tester) async {
    await tester.runAsync(() async {
      // iOS: a single 1024 px icon; Xcode 14+ generates the other sizes from it.
      const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      await _writePng('$ios/Icon-App-1024x1024@1x.png', 1024, _Kind.square);
      _writeText('$ios/Contents.json', '''
{
  "images" : [
    {
      "filename" : "Icon-App-1024x1024@1x.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''');

      // Android: vector drawables. Adaptive layers are 108 dp; the legacy icon is 48 dp.
      const res = 'android/app/src/main/res';
      _writeText(
        '$res/drawable/ic_launcher_foreground.xml',
        _vectorDrawable(108, _Kind.foreground, dp: 108),
      );
      _writeText(
        '$res/drawable/ic_launcher_monochrome.xml',
        _vectorDrawable(108, _Kind.monochrome, dp: 108),
      );
      // Android 7: the manifest's @mipmap/ic_launcher (Android 8+ uses mipmap-anydpi-v26).
      _writeText(
        '$res/mipmap/ic_launcher.xml',
        _vectorDrawable(48, _Kind.rounded, dp: 48),
      );

      // Previews (build/ is ignored by git).
      for (final (name, size, kind) in [
        ('foreground', 108.0, _Kind.foreground),
        ('monochrome', 108.0, _Kind.monochrome),
        ('legacy', 48.0, _Kind.rounded),
      ]) {
        _writeText('build/icon_preview/$name.svg', _svg(size, kind));
      }

      // A large copy for the README or a store listing.
      await _writePng('tool/app_icon_1024.png', 1024, _Kind.square);
    });
  });
}
