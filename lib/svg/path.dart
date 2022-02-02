/// This file contains classes for the different types of SVG path segments as
/// well as a Path object that contains a sequence of path segments.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:math' show sqrt, sin, cos, acos, log, pi;

import 'package:bisection/extension.dart';

import '../common/point.dart';

num radians(num n) => n * pi / 180;
num degrees(num n) => n * 180 / pi;

const defaultMinDepth = 5;
const defaultError = 1e-12;

extension _RemovePointIfInt on num {
  num get removePointIfInt => truncate() == this ? truncate() : this;
}

/// Recursively approximates the length by straight lines
num segmentLength({
  required SvgPath curve,
  required num start,
  required num end,
  required Point startPoint,
  required Point endPoint,
  required num error,
  required int minDepth,
  required num depth,
}) {
  num mid = (start + end) / 2;
  Point midPoint = curve.point(mid);
  num length = (endPoint - startPoint).abs();
  num firstHalf = (midPoint - startPoint).abs();
  num secondHalf = (endPoint - midPoint).abs();

  num length2 = firstHalf + secondHalf;
  if ((length2 - length > error) || (depth < minDepth)) {
    // Calculate the length of each segment:
    depth += 1;
    return segmentLength(
          curve: curve,
          start: start,
          end: mid,
          startPoint: startPoint,
          endPoint: midPoint,
          error: error,
          minDepth: minDepth,
          depth: depth,
        ) +
        segmentLength(
          curve: curve,
          start: mid,
          end: end,
          startPoint: midPoint,
          endPoint: endPoint,
          error: error,
          minDepth: minDepth,
          depth: depth,
        );
  }
  // This is accurate enough.
  return length2;
}

abstract class SvgPath {
  final Point start;
  final Point end;

  const SvgPath({
    required this.start,
    required this.end,
  });

  @override
  bool operator ==(Object other) =>
      other is SvgPath && start == other.start && end == other.end;

  @override
  int get hashCode => start.hashCode ^ end.hashCode;

  /// Calculate the x,y position at a certain position of the path
  Point point(num pos);

  /// Calculate the length of the path up to a certain position
  num size({num error = defaultError, int minDepth = defaultMinDepth});
}

abstract class Bezier extends SvgPath {
  const Bezier({
    required Point start,
    required Point end,
  }) : super(start: start, end: end);

  @override
  bool operator ==(Object other) => other is Bezier && super == other;

  @override
  int get hashCode => super.hashCode + 0;

  /// Checks if this segment would be a smooth segment following the previous
  bool isSmoothFrom(Object? previous);
}

/// A straight line
/// The base for Line() and Close().
class Linear extends SvgPath {
  const Linear({
    required Point start,
    required Point end,
  }) : super(start: start, end: end);

  @override
  bool operator ==(Object other) => other is Linear && super == other;

  @override
  int get hashCode => super.hashCode + 0;

  @override
  Point point(num pos) => start + (end - start).times(pos);

  @override
  num size({num error = defaultError, int minDepth = defaultMinDepth}) {
    final distance = end - start;
    return sqrt(distance.x * distance.x + distance.y * distance.y);
  }
}

class Line extends Linear {
  const Line({
    required Point start,
    required Point end,
  }) : super(start: start, end: end);

  @override
  bool operator ==(Object other) => other is Line && super == other;

  @override
  int get hashCode => super.hashCode + 0;

  @override
  String toString() {
    return "Line(start=$start, end=$end)";
  }
}

class CubicBezier extends Bezier {
  final Point control1;
  final Point control2;

  const CubicBezier({
    required Point start,
    required this.control1,
    required this.control2,
    required Point end,
  }) : super(start: start, end: end);

  @override
  bool operator ==(Object other) =>
      other is CubicBezier &&
      control1 == other.control1 &&
      control2 == other.control2 &&
      super == other;

  @override
  int get hashCode => super.hashCode ^ control1.hashCode ^ control2.hashCode;

  @override
  String toString() => "CubicBezier(start=$start, control1=$control1, "
      "control2=$control2, end=$end)";

  @override
  bool isSmoothFrom(Object? previous) => previous is CubicBezier
      ? start == previous.end &&
          control1 - start == previous.end - previous.control2
      : control1 == start;

  @override
  Point point(num pos) =>
      start.times(math.pow(1 - pos, 3)) +
      control1.times(math.pow(1 - pos, 2) * 3 * pos) +
      control2.times(math.pow(pos, 2) * 3 * (1 - pos)) +
      end.times(math.pow(pos, 3));

  @override
  num size({num error = defaultError, int minDepth = defaultMinDepth}) {
    final startPoint = point(0);
    final endPoint = point(1);
    return segmentLength(
      curve: this,
      start: 0,
      end: 1,
      startPoint: startPoint,
      endPoint: endPoint,
      error: error,
      minDepth: minDepth,
      depth: 0,
    );
  }
}

class QuadraticBezier extends Bezier {
  final Point control;

  const QuadraticBezier({
    required Point start,
    required Point end,
    required this.control,
  }) : super(start: start, end: end);

  @override
  bool operator ==(Object other) =>
      other is QuadraticBezier && control == other.control && super == other;

  @override
  int get hashCode => super.hashCode ^ control.hashCode;

  @override
  String toString() =>
      "QuadraticBezier(start=$start, control=$control, end=$end)";

  @override
  bool isSmoothFrom(Object? previous) => previous is QuadraticBezier
      ? start == previous.end &&
          (control - start) == (previous.end - previous.control)
      : control == start;

  @override
  Point point(num pos) =>
      start.times(math.pow(1 - pos, 2)) +
      control.times(pos * (1 - pos) * 2) +
      end.times(math.pow(pos, 2));

  @override
  num size({num error = defaultError, int minDepth = defaultMinDepth}) {
    final Point a = start - control.times(2) + end;
    final Point b = (control - start).times(2);
    final num aDotB = a.x * b.x + a.y * b.y;

    late final num s;
    if (a.abs() < 1e-12) {
      s = b.abs();
    } else if ((aDotB + a.abs() * b.abs()).abs() < 1e-12) {
      final k = b.abs() / a.abs();
      s = (k >= 2) ? b.abs() - a.abs() : a.abs() * ((k * k) / 2 - k + 1);
    } else {
      // For an explanation of this case, see
      // http://www.malczak.info/blog/quadratic-bezier-curve-length/
      final num A = 4 * (a.x * a.x + a.y * a.y);
      final num B = 4 * (a.x * b.x + a.y * b.y);
      final num C = b.x * b.x + b.y * b.y;

      final num sabc = 2 * sqrt(A + B + C);
      final num a2 = sqrt(A);
      final num a32 = 2 * A * a2;
      final num c2 = 2 * sqrt(C);
      final num bA = B / a2;

      s = (a32 * sabc +
              a2 * B * (sabc - c2) +
              (4 * C * A - (B * B)) * log((2 * a2 + bA + sabc) / (bA + c2))) /
          (4 * a32);
    }
    return s;
  }
}

/// radius is complex, rotation is in degrees,
/// large and sweep are 1 or 0 (True/False also work)
class Arc extends SvgPath {
  final Point radius;
  final num rotation;
  final bool arc;
  final bool sweep;
  // late final num radiusScale;
  // late final Point center;
  // late final num theta;
  // late num delta;

  const Arc({
    required Point start,
    required Point end,
    required this.radius,
    required this.rotation,
    required this.arc,
    required this.sweep,
  }) : super(start: start, end: end);

  @override
  bool operator ==(Object other) =>
      other is Arc &&
      radius == other.radius &&
      rotation == other.rotation &&
      arc == other.arc &&
      sweep == other.sweep &&
      super == other;

  @override
  int get hashCode =>
      super.hashCode ^
      radius.hashCode ^
      rotation.hashCode ^
      arc.hashCode ^
      sweep.hashCode;

  @override
  String toString() => 'Arc(start=$start, radius=$radius, rotation=$rotation, '
      'arc=$arc, sweep=$sweep, end=$end)';


  // Conversion from endpoint to center parameterization
  // http://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes
  num get _cosr => cos(radians(rotation));
  num get _sinr => sin(radians(rotation));
  num get _dx => (start.x - end.x) / 2;
  num get _dy => (start.y - end.y) / 2;
  num get _x1prim => _cosr * _dx + _sinr * _dy;
  num get _x1primSq => _x1prim * _x1prim;
  num get _y1prim => -_sinr * _dx + _cosr * _dy;
  num get _y1primSq => _y1prim * _y1prim;
  num get _rx => (radiusScale > 1 ? radiusScale : 1) * radius.x;
  num get _ry => (radiusScale > 1 ? radiusScale : 1) * radius.y;
  num get _rxSq => _rx * _rx;
  num get _rySq => _ry * _ry;
  num get _ux => (_x1prim - _cxprim) / _rx;
  num get _uy => (_y1prim - _cyprim) / _ry;
  num get _vx => (-_x1prim - _cxprim) / _rx;
  num get _vy => (-_y1prim - _cyprim) / _ry;
  num get t1 => _rxSq * _y1primSq;
  num get t2 => _rySq * _x1primSq;
  num get c =>
      (arc == sweep ? 1 : -1) *
      sqrt(((_rxSq * _rySq - t1 - t2) / (t1 + t2)).abs());
  num get _cxprim => c * _rx * _y1prim / _ry;
  num get _cyprim => -c * _ry * _x1prim / _rx;

  num get radiusScale {
    final rs = (_x1primSq / (radius.x * radius.x)) +
        (_y1primSq / (radius.y * radius.y));
    return rs > 1 ? sqrt(rs) : 1;
  }

  Point get center => Point(
        (_cosr * _cxprim - _sinr * _cyprim) + ((start.x + end.x) / 2),
        (_sinr * _cxprim + _cosr * _cyprim) + ((start.y + end.y) / 2),
      );
  
  num get theta {
    final num n = sqrt(_ux * _ux + _uy * _uy);
    final num p = _ux;
    return (((_uy < 0) ? -1 : 1) * degrees(acos(p / n))) % 360;
  }

  num get delta {
    final num n = sqrt((_ux * _ux + _uy * _uy) * (_vx * _vx + _vy * _vy));
    final num p = _ux * _vx + _uy * _vy;
    num d = p / n;
    // In certain cases the above calculation can through inaccuracies
    // become just slightly out of range, f ex -1.0000000000000002.
    if (d > 1.0) {
      d = 1.0;
    } else if (d < -1.0) {
      d = -1.0;
    }

    return ((((_ux * _vy - _uy * _vx) < 0) ? -1 : 1) * degrees(acos(d))) % 360 - (!sweep ? 360 : 0);
  }

  @override
  Point point(num pos) {
    // This is equivalent of omitting the segment
    if (start == end) return start;

    // This should be treated as a straight line
    if (this.radius.x == 0 || this.radius.y == 0) {
      return start + (end - start) * pos;
    }

    final angle = radians(theta + pos * delta);
    final cosr = cos(radians(rotation));
    final sinr = sin(radians(rotation));
    final radius = this.radius.times(radiusScale);

    final x =
        cosr * cos(angle) * radius.x - sinr * sin(angle) * radius.y + center.x;

    final y =
        sinr * cos(angle) * radius.x + cosr * sin(angle) * radius.y + center.y;

    return Point(x, y);
  }

  /// The length of an elliptical arc segment requires numerical
  /// integration, and in that case it's simpler to just do a geometric
  /// approximation, as for cubic bezier curves.
  @override
  num size({num error = defaultError, minDepth = defaultMinDepth}) {
    // This is equivalent of omitting the segment
    if (start == end) return 0;

    // This should be treated as a straight line
    if (radius.x == 0 || radius.y == 0) {
      final distance = end - start;
      return sqrt(distance.x * distance.x + distance.y * distance.y);
    }

    if (radius.x == radius.y) {
      // It's a circle, which simplifies this a LOT.
      final radius = this.radius.x * radiusScale;
      return radians(radius * delta).abs();
    }

    final startPoint = point(0);
    final endPoint = point(1);
    return segmentLength(
        curve: this,
        start: 0,
        end: 1,
        startPoint: startPoint,
        endPoint: endPoint,
        error: error,
        minDepth: minDepth,
        depth: 0);
  }
}

/// Represents move commands. Does nothing, but is there to handle
/// paths that consist of only move commands, which is valid, but pointless.
class Move extends SvgPath {
  const Move({required Point to}) : super(start: to, end: to);

  @override
  bool operator ==(Object other) => other is Move && super == other;

  @override
  int get hashCode => super.hashCode + 0;

  @override
  String toString() => "Move(to=$start)";

  @override
  Point point(num pos) => start;

  @override
  num size({num error = defaultError, int minDepth = defaultMinDepth}) => 0;
}

/// Represents the closepath command
class Close extends Linear {
  const Close({
    required Point start,
    required Point end,
  }) : super(start: start, end: end);

  @override
  bool operator ==(Object other) => other is Close && super == other;

  @override
  int get hashCode => super.hashCode + 0;

  @override
  String toString() => "Close(start=$start, end=$end)";
}

/// A Path is a sequence of path segments
class Path extends ListBase<SvgPath> {
  late final List<SvgPath?> segments;
  List<num>? _memoizedLengths;
  num? _memoizedLength;
  final List<num> _fractions = [];

  Path() {
    segments = [];
  }

  Path.fromSegments(this.segments);

  @override
  bool operator ==(Object other) => other is Path && segments == other.segments;

  @override
  int get hashCode => segments.hashCode;

  @override
  SvgPath operator [](int index) => segments[index]!;

  @override
  void operator []=(int index, SvgPath value) {
    segments[index] = value;
    _memoizedLength = null;
  }

  @override
  int get length => segments.length;

  @override
  set length(int newLength) => segments.length = newLength;

  @override
  String toString() =>
      'Path(${[for (final s in segments) s.toString()].join(", ")})';

  void _calcLengths(
      {num error = defaultError, int minDepth = defaultMinDepth}) {
    if (_memoizedLength != null) return;

    final lengths = [
      for (final s in segments) s!.size(error: error, minDepth: minDepth)
    ];
    _memoizedLength = lengths.reduce((a, b) => a + b);
    if (_memoizedLength == 0) {
      _memoizedLengths = lengths;
    } else {
      _memoizedLengths = [for (final l in lengths) l / _memoizedLength!];
    }

    // Calculate the fractional distance for each segment to use in point()
    num fraction = 0;
    for (final l in _memoizedLengths!) {
      fraction += l;
      _fractions.add(fraction);
    }
  }

  Point point({required num pos, num error = defaultError}) {
    // Shortcuts
    if (pos == 0.0) {
      return segments[0]!.point(pos);
    }
    if (pos == 1.0) {
      return segments.last!.point(pos);
    }

    _calcLengths(error: error);

    // Fix for paths of length 0 (i.e. points)
    if (length == 0) {
      return segments[0]!.point(0.0);
    }

    // Find which segment the point we search for is located on:
    late final num segmentPos;
    int i = _fractions.bisectRight(pos);
    if (i == 0) {
      segmentPos = pos / _fractions[0];
    } else {
      segmentPos =
          (pos - _fractions[i - 1]) / (_fractions[i] - _fractions[i - 1]);
    }
    return segments[i]!.point(segmentPos);
  }

  num size({error = defaultError, minDepth = defaultMinDepth}) {
    _calcLengths(error: error, minDepth: minDepth);
    return _memoizedLength!;
  }

  String d() {
    Point? currentPos;
    final parts = [];
    SvgPath? previousSegment;
    final end = last.end;

    String formatNumber(num n) => n.removePointIfInt.toString();
    String coord(Point p) => '${formatNumber(p.x)},${formatNumber(p.y)}';

    for (final segment in this) {
      final start = segment.start;
      // If the start of this segment does not coincide with the end of
      // the last segment or if this segment is actually the close point
      // of a closed path, then we should start a new subpath here.
      if (segment is Close) {
        parts.add("Z");
      } else if (segment is Move ||
          (currentPos != start) ||
          (start == end && previousSegment is! Move)) {
        parts.add("M ${coord(segment.start)}");
      }

      if (segment is Line) {
        parts.add("L ${coord(segment.end)}");
      } else if (segment is CubicBezier) {
        if (segment.isSmoothFrom(previousSegment)) {
          parts.add("S ${coord(segment.control2)} ${coord(segment.end)}");
        } else {
          parts.add(
            "C ${coord(segment.control1)} ${coord(segment.control2)} ${coord(segment.end)}",
          );
        }
      } else if (segment is QuadraticBezier) {
        if (segment.isSmoothFrom(previousSegment)) {
          parts.add("T ${coord(segment.end)}");
        } else {
          parts.add("Q ${coord(segment.control)} ${coord(segment.end)}");
        }
      } else if (segment is Arc) {
        parts.add(
          "A ${coord(segment.radius)} ${formatNumber(segment.rotation)} "
          "${segment.arc ? 1 : 0},${segment.sweep ? 1 : 0} ${coord(segment.end)}",
        );
      }

      currentPos = segment.end;
      previousSegment = segment;
    }

    return parts.join(" ").toUpperCase();
  }
}
