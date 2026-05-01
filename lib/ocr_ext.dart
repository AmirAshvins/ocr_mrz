// ===== Geometry model from your cornerPoints =====
import 'dart:math' as math;

import 'package:camera_kit_plus/camera_kit_plus.dart';

class Geom {
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double width;
  final double height;
  final double cx; // center x
  final double cy; // center y
  final double angle; // radians; 0 = perfectly horizontal

  Geom({required this.left, required this.top, required this.right, required this.bottom, required this.width, required this.height, required this.cx, required this.cy, required this.angle});
}

Geom _geomFromCorners(List<OcrPoint> pts) {
  // pts can come in any order; find min/max bounds + estimate angle from top edge
  final xs = pts.map((p) => p.x).toList();
  final ys = pts.map((p) => p.y).toList();
  final left = xs.reduce((a, b) => a < b ? a : b);
  final right = xs.reduce((a, b) => a > b ? a : b);
  final top = ys.reduce((a, b) => a < b ? a : b);
  final bottom = ys.reduce((a, b) => a > b ? a : b);
  final width = (right - left).abs();
  final height = (bottom - top).abs();
  final cx = (left + right) / 2.0;
  final cy = (top + bottom) / 2.0;

  // Angle estimation: pick two points with smallest y as "top edge"
  final sortedByY = [...pts]..sort((a, b) => a.y.compareTo(b.y));
  final p1 = sortedByY.first;
  final p2 = sortedByY[1];
  final angle = (p2.y - p1.y).abs() < 1e-6 ? 0.0 : Math.atan2(p2.y - p1.y, p2.x - p1.x);

  return Geom(left: left, top: top, right: right, bottom: bottom, width: width, height: height, cx: cx, cy: cy, angle: angle);
}

// Small math shim (no dart:math name clashes in your files)
class Math {
  static double atan2(double y, double x) => (y == 0 && x == 0) ? 0 : math.atan2(y, x);

  static double abs(double v) => v.abs();
}
