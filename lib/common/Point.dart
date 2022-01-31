import 'dart:math' as math;

class Point {
  final num x;
  final num y;

  const Point(this.x, this.y);
  const Point.from({this.x = 0, this.y = 0});
  static const zero = Point(0, 0);

  operator +(covariant Point p) => Point(x + p.x, y + p.y);
  operator -(covariant Point p) => Point(x - p.x, y - p.y);
  operator *(covariant Point p) => Point(x * p.x, y * p.y);
  operator /(covariant Point p) => Point(x / p.x, y / p.y);

  Point addX(num n) => Point(x + n, y);
  Point addY(num n) => Point(x, y + n);
  Point add(num n) => Point(x + n, y + n);

  Point subtractX(num n) => Point(x - n, y);
  Point subtractY(num n) => Point(x, y - n);
  Point subtractXY(num n) => Point(x - n, y - n);

  Point xSubtract(num n) => Point(n - x, y);
  Point ySubtract(num n) => Point(x, n - y);
  Point xySubtract(num n) => Point(n - x, n - y);

  Point timesX(num n) => Point(x * n, y);
  Point timesY(num n) => Point(x, y * n);
  Point times(num n) => Point(x * n, y * n);

  Point dividesX(num n) => Point(x / n, y);
  Point dividesY(num n) => Point(x, y / n);
  Point divides(num n) => Point(x / n, y / n);

  Point pow(int n) => Point(math.pow(x, n), math.pow(y, n));
  double abs() => math.sqrt(x * x + y * y);

  @override
  String toString() => '($x,$y)';
}