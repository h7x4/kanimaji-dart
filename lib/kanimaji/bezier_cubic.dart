
import 'dart:math' as math;

class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);

  @override
  String toString() => '($x,$y)';
}

double thrt(double x) =>
    x > 0 ? math.pow(x, 1.0 / 3).toDouble() : -math.pow(-x, 1.0 / 3).toDouble();

double sqrt(double x) => x > 0 ? math.sqrt(x) : 0;

double sq(x) => x * x;

double cb(x) => x * x * x;

/// x(t) = t^3 T + 3t^2(1-t) U + 3t(1-t)^2 V + (1-t)^3 W
double time(Point pt1, Point ct1, Point ct2, Point pt2, double x) {
  // var C = Cubic, a,b,c,d,p,q,lambda,sqlambda,tmp,addcoef,t,qb,qc,norm,angle,fact;
  final double a = pt1.x - 3 * ct1.x + 3 * ct2.x - pt2.x;
  final double b = 3 * ct1.x - 6 * ct2.x + 3 * pt2.x;
  final double c = 3 * ct2.x - 3 * pt2.x;
  final double d = pt2.x - x;

  if (a.abs() < 0.000000001) { // quadratic
    if (b.abs() < 0.000000001) return -d / c; // linear

    final qb = c / b;
    final qc = d / b;
    final tmp = sqrt(sq(qb) - 4 * qc);
    return (-qb + ((qb > 0 || qc < 0) ? tmp : -tmp)) / 2;
  }

  final p = -sq(b) / (3 * sq(a)) + c / a;
  final q = 2 * cb(b / (3 * a)) - b * c / (3 * sq(a)) + d / a;
  final addcoef = -b / (3 * a);

  final lmbd = sq(q) / 4 + cb(p) / 27;
  if (lmbd >= 0) { // real
    final sqlambda = sqrt(lmbd);
    final tmp = thrt(-q / 2 + (q < 0 ? sqlambda : -sqlambda));
    return tmp - p / (3 * tmp) + addcoef;
  }

  final norm = sqrt(sq(q) / 4 - lmbd);
  if (norm < 0.0000000001) return addcoef;

  final angle = math.acos(-q / (2 * norm)) / 3;
  final fact = 2 * thrt(norm);
  double t = double.infinity;
  for (final i in [-1, 0, 1]) {
    final tmp = fact * math.cos(angle + i * math.pi * 2 / 3) + addcoef;
    if (tmp >= -0.000000001 && tmp < t) t = tmp;
  }

  return t;
}

double value(Point pt1, Point ct1, Point ct2, Point pt2, double x) {
  final t = time(pt1, ct1, ct2, pt2, x);
  return cb(t) * pt1.y +
      3 * sq(t) * (1 - t) * ct1.y +
      3 * t * sq(1 - t) * ct2.y +
      cb(1 - t) * pt2.y;
}

// if __name__ == "__main__":
//     pt1 = pt(0,0)
//     ct1 = pt(0.25, 0.1)
//     ct2 = pt(0.25, 1.0)
//     pt2 = pt(1,1)

//     part = 100
//     with open('ease.txt', 'w') as f:
//         for i in range(0,part+1,1):
//             x = float(i) / part
//             y = value(pt1, ct1, ct2, pt2, x)
//             f.write("%f %f\n" % (x,y))