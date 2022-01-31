import 'dart:collection';
import 'dart:math' as math;
import 'dart:math' show sqrt, sin, cos, acos, log, pi;

import 'package:bisection/extension.dart';

import '../common/Point.dart';

// try:
//     from collections.abc import MutableSequence
// except ImportError:
//     from collections import MutableSequence

// This file contains classes for the different types of SVG path segments as
// well as a Path object that contains a sequence of path segments.

double radians(num n) => n * pi / 180;
double degrees(num n) => n * 180 / pi;


const defaultMinDepth = 5;
const defaultError = 1e-12;

/// Recursively approximates the length by straight lines
double segmentLength({
  required SvgPath curve,
  required num start,
  required num end,
  required Point startPoint,
  required Point endPoint,
  required double error,
  required int minDepth,
  required double depth,
}) {
  num mid = (start + end) / 2;
  Point midPoint = curve.point(mid);
  double length = (endPoint - startPoint).abs();
  double firstHalf = (midPoint - startPoint).abs();
  double secondHalf = (endPoint - midPoint).abs();

  double length2 = firstHalf + secondHalf;
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

  /// Calculate the x,y position at a certain position of the path
  Point point(num pos);

  /// Calculate the length of the path up to a certain position
  double size({double error = defaultError, int minDepth = defaultMinDepth});
}

abstract class Bezier extends SvgPath {
  const Bezier({
    required Point start,
    required Point end,
  }) : super(start: start, end: end);

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

  // def __ne__(self, other):
  //     if not isinstance(other, Line):
  //         return NotImplemented
  //     return not self == other

  @override
  Point point(num pos) => start + (end - start).times(pos);

  @override
  double size({double error = defaultError, int minDepth = defaultMinDepth}) {
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
  String toString() {
    return "Line(start=$start, end=$end)";
  }
  // @override
  // operator ==(covariant Line other) => start == other.start && end == other.end;
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
  String toString() => "CubicBezier(start=$start, control1=$control1, "
      "control2=$control2, end=$end)";

  // @override
  // operator ==(covariant CubicBezier other) =>
  //           start == other.start &&
  //           and end == other.end &&
  //           and control1 == other.control1 &&
  //           and control2 == other.control2;

  // def __ne__(self, other):
  //     if not isinstance(other, CubicBezier):
  //         return NotImplemented
  //     return not self == other

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
  double size({double error = defaultError, int minDepth = defaultMinDepth}) {
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

class QuadraticBezier extends Bezier {
  final Point control;

  const QuadraticBezier({
    required Point start,
    required Point end,
    required this.control,
  }) : super(
          start: start,
          end: end,
        );

  @override
  String toString() =>
      "QuadraticBezier(start=$start, control=$control, end=$end)";

  // def __eq__(self, other):
  //     if not isinstance(other, QuadraticBezier):
  //         return NotImplemented
  //     return (
  //         self.start == other.start
  //         and self.end == other.end
  //         and self.control == other.control
  //     )

  // def __ne__(self, other):
  //     if not isinstance(other, QuadraticBezier):
  //         return NotImplemented
  //     return not self == other

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
  double size({double error = defaultError, int minDepth = defaultMinDepth}) {
    final Point a = start - control.times(2) + end;
    final Point b = (control - start).times(2);
    final num aDotB = a.x * b.x + a.y * b.y;

    late final double s;
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

      final double sabc = 2 * sqrt(A + B + C);
      final double a2 = sqrt(A);
      final double a32 = 2 * A * a2;
      final double c2 = 2 * sqrt(C);
      final double bA = B / a2;

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
  final double rotation;
  final bool arc;
  final bool sweep;
  late final num radiusScale;
  late final Point center;
  late final num theta;
  late final num delta;

  Arc({
    required Point start,
    required Point end,
    required this.radius,
    required this.rotation,
    required this.arc,
    required this.sweep,
  }) : super(start: start, end: end) {
    _parameterize();
  }

  @override
  String toString() => "Arc(start=$start, radius=$radius, rotation=$rotation, "
      "arc=$arc, sweep=$sweep, end=$end)";

  // def __eq__(self, other):
  //     if not isinstance(other, Arc):
  //         return NotImplemented
  //     return (
  //         self.start == other.start
  //         and self.end == other.end
  //         and self.radius == other.radius
  //         and self.rotation == other.rotation
  //         and self.arc == other.arc
  //         and self.sweep == other.sweep
  //     )

  // def __ne__(self, other):
  //     if not isinstance(other, Arc):
  //         return NotImplemented
  //     return not self == other

  void _parameterize() {
    // Conversion from endpoint to center parameterization
    // http://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes

    // This is equivalent of omitting the segment, so do nothing
    if (start == end) return;

    // This should be treated as a straight line
    if (radius.x == 0 || radius.y == 0) return;

    final cosr = cos(radians(rotation));
    final sinr = sin(radians(rotation));
    final dx = (start.x - end.x) / 2;
    final dy = (start.y - end.y) / 2;
    final x1prim = cosr * dx + sinr * dy;
    final x1primSq = x1prim * x1prim;
    final y1prim = -sinr * dx + cosr * dy;
    final y1primSq = y1prim * y1prim;

    num rx = radius.x;
    num rxSq = rx * rx;
    num ry = radius.y;
    num rySq = ry * ry;

    // Correct out of range radii
    num radiusScale = (x1primSq / rxSq) + (y1primSq / rySq);
    if (radiusScale > 1) {
      radiusScale = sqrt(radiusScale);
      rx *= radiusScale;
      ry *= radiusScale;
      rxSq = rx * rx;
      rySq = ry * ry;
      this.radiusScale = radiusScale;
    } else {
      // SVG spec only scales UP
      this.radiusScale = 1;
    }

    final t1 = rxSq * y1primSq;
    final t2 = rySq * x1primSq;
    double c = sqrt(((rxSq * rySq - t1 - t2) / (t1 + t2)).abs());

    if (arc == sweep) {
      c = -c;
    }
    final cxprim = c * rx * y1prim / ry;
    final cyprim = -c * ry * x1prim / rx;

    center = Point(
      (cosr * cxprim - sinr * cyprim) + ((start.x + end.x) / 2),
      (sinr * cxprim + cosr * cyprim) + ((start.y + end.y) / 2),
    );

    final ux = (x1prim - cxprim) / rx;
    final uy = (y1prim - cyprim) / ry;
    final vx = (-x1prim - cxprim) / rx;
    final vy = (-y1prim - cyprim) / ry;
    num n = sqrt(ux * ux + uy * uy);
    num p = ux;
    theta = (((uy < 0) ? -1 : 1) * degrees(acos(p / n))) % 360;

    n = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
    p = ux * vx + uy * vy;
    num d = p / n;
    // In certain cases the above calculation can through inaccuracies
    // become just slightly out of range, f ex -1.0000000000000002.
    if (d > 1.0) {
      d = 1.0;
    } else if (d < -1.0) {
      d = -1.0;
    }
    delta = ((((ux * vy - uy * vx) < 0) ? -1 : 1) * degrees(acos(d))) % 360;
    if (!sweep) delta -= 360;
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
  double size({double error = defaultError, minDepth = defaultMinDepth}) {
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

// Represents move commands. Does nothing, but is there to handle
// paths that consist of only move commands, which is valid, but pointless.
class Move extends SvgPath {
  const Move({required Point to}) : super(start: to, end: to);

  @override
  String toString() => "Move(to=$start)";
//     def __eq__(self, other):
//         if not isinstance(other, Move):
//             return NotImplemented
//         return self.start == other.start

//     def __ne__(self, other):
//         if not isinstance(other, Move):
//             return NotImplemented
//         return not self == other

  @override
  Point point(num pos) => start;

  @override
  double size({double error = defaultError, int minDepth = defaultMinDepth}) =>
      0;
}

// Represents the closepath command
class Close extends Linear {
  const Close({
    required Point start,
    required Point end,
  }) : super(start: start, end: end);

  // def __eq__(self, other):
  //     if not isinstance(other, Close):
  //         return NotImplemented
  //     return self.start == other.start and self.end == other.end

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
      {double error = defaultError, int minDepth = defaultMinDepth}) {
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

  Point point({required num pos, double error = defaultError}) {
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

    String formatNumber(num n) => n.toString();
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
        parts.add("M ${coord(start)}");
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
          "${(segment.arc ? 1 : 0).toDouble},${(segment.sweep ? 1 : 0).toDouble} ${coord(end)}",
        );
      }

      currentPos = segment.end;
      previousSegment = segment;
    }

    return parts.join(" ");
  }

//     def __delitem__(self, index):
//         del self._segments[index]
//         self._length = None

//     def reverse(self):
//         # Reversing the order of a path would require reversing each element
//         # as well. That's not implemented.
//         raise NotImplementedError

//     def __len__(self):
//         return len(self._segments)

//     def __eq__(self, other):

//         if not isinstance(other, Path):
//             return NotImplemented
//         if len(self) != len(other):
//             return False
//         for s, o in zip(self._segments, other._segments):
//             if not s == o:
//                 return False
//         return True

//     def __ne__(self, other):
//         if not isinstance(other, Path):
//             return NotImplemented
//         return not self == other

}
