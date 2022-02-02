import 'package:flutter_test/flutter_test.dart';
import 'package:kanimaji/common/point.dart';
import 'package:kanimaji/svg/parser.dart';
import 'package:kanimaji/svg/path.dart';

void main() {
  /// """Examples from the SVG spec"""
  test("svg_examples", () {
    Path path1 = parsePath("M 100 100 L 300 100 L 200 300 z");
    expect(
      path1,
      Path.fromSegments([
        const Move(to: Point(100, 100)),
        const Line(start: Point(100, 100), end: Point(300, 100)),
        const Line(start: Point(300, 100), end: Point(200, 300)),
        const Close(start: Point(200, 300), end: Point(100, 100)),
      ]),
    );

    // for Z command behavior when there is multiple subpaths
    path1 = parsePath("M 0 0 L 50 20 M 100 100 L 300 100 L 200 300 z");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point.zero),
        Line(start: Point.zero, end: Point(50, 20)),
        Move(to: Point(100, 100)),
        Line(start: Point(100, 100), end: Point(300, 100)),
        Line(start: Point(300, 100), end: Point(200, 300)),
        Close(start: Point(200, 300), end: Point(100, 100)),
      ]),
    );

    path1 = parsePath("M 100 100 L 200 200");
    Path path2 = parsePath("M100 100L200 200");
    expect(path1, path2);

    path1 = parsePath("M 100 200 L 200 100 L -100 -200");
    path2 = parsePath("M 100 200 L 200 100 -100 -200");
    expect(path1, path2);

    path1 = parsePath("""M100,200 C100,100 250,100 250,200
                              S400,300 400,200""");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(100, 200)),
        CubicBezier(
          start: Point(100, 200),
          control1: Point(100, 100),
          control2: Point(250, 100),
          end: Point(250, 200),
        ),
        CubicBezier(
          start: Point(250, 200),
          control1: Point(250, 300),
          control2: Point(400, 300),
          end: Point(400, 200),
        ),
      ]),
    );

    path1 = parsePath("M100,200 C100,100 400,100 400,200");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(100, 200)),
        CubicBezier(
          start: Point(100, 200),
          control1: Point(100, 100),
          control2: Point(400, 100),
          end: Point(400, 200),
        ),
      ]),
    );

    path1 = parsePath("M100,500 C25,400 475,400 400,500");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(100, 500)),
        CubicBezier(
          start: Point(100, 500),
          control1: Point(25, 400),
          control2: Point(475, 400),
          end: Point(400, 500),
        ),
      ]),
    );

    path1 = parsePath("M100,800 C175,700 325,700 400,800");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(100, 800)),
        CubicBezier(
          start: Point(100, 800),
          control1: Point(175, 700),
          control2: Point(325, 700),
          end: Point(400, 800),
        ),
      ]),
    );

    path1 = parsePath("M600,200 C675,100 975,100 900,200");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(600, 200)),
        CubicBezier(
          start: Point(600, 200),
          control1: Point(675, 100),
          control2: Point(975, 100),
          end: Point(900, 200),
        ),
      ]),
    );

    path1 = parsePath("M600,500 C600,350 900,650 900,500");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(600, 500)),
        CubicBezier(
          start: Point(600, 500),
          control1: Point(600, 350),
          control2: Point(900, 650),
          end: Point(900, 500),
        ),
      ]),
    );

    path1 = parsePath("""M600,800 C625,700 725,700 750,800
                          S875,900 900,800""");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(600, 800)),
        CubicBezier(
            start: Point(600, 800),
            control1: Point(625, 700),
            control2: Point(725, 700),
            end: Point(750, 800)),
        CubicBezier(
          start: Point(750, 800),
          control1: Point(775, 900),
          control2: Point(875, 900),
          end: Point(900, 800),
        ),
      ]),
    );

    path1 = parsePath("M200,300 Q400,50 600,300 T1000,300");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(200, 300)),
        QuadraticBezier(
          start: Point(200, 300),
          control: Point(400, 50),
          end: Point(600, 300),
        ),
        QuadraticBezier(
          start: Point(600, 300),
          control: Point(800, 550),
          end: Point(1000, 300),
        ),
      ]),
    );

    path1 = parsePath("M300,200 h-150 a150,150 0 1,0 150,-150 z");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(300, 200)),
        Line(start: Point(300, 200), end: Point(150, 200)),
        Arc(
          start: Point(150, 200),
          radius: Point(150, 150),
          rotation: 0,
          arc: true,
          sweep: false,
          end: Point(300, 50),
        ),
        Close(start: Point(300, 50), end: Point(300, 200)),
      ]),
    );

    path1 = parsePath("M275,175 v-150 a150,150 0 0,0 -150,150 z");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(275, 175)),
        Line(start: Point(275, 175), end: Point(275, 25)),
        Arc(
          start: Point(275, 25),
          radius: Point(150, 150),
          rotation: 0,
          arc: false,
          sweep: false,
          end: Point(125, 175),
        ),
        Close(start: Point(125, 175), end: Point(275, 175)),
      ]),
    );

    path1 = parsePath("M275,175 v-150 a150,150 0 0,0 -150,150 L 275,175 z");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(275, 175)),
        Line(start: Point(275, 175), end: Point(275, 25)),
        Arc(
          start: Point(275, 25),
          radius: Point(150, 150),
          rotation: 0,
          arc: false,
          sweep: false,
          end: Point(125, 175),
        ),
        Line(start: Point(125, 175), end: Point(275, 175)),
        Close(start: Point(275, 175), end: Point(275, 175)),
      ]),
    );

    path1 = parsePath("""M600,350 l 50,-25
                          a25,25 -30 0,1 50,-25 l 50,-25
                          a25,50 -30 0,1 50,-25 l 50,-25
                          a25,75 -30 0,1 50,-25 l 50,-25
                          a25,100 -30 0,1 50,-25 l 50,-25""");
    expect(
      path1,
      Path.fromSegments(const [
        Move(to: Point(600, 350)),
        Line(start: Point(600, 350), end: Point(650, 325)),
        Arc(
          start: Point(650, 325),
          radius: Point(25, 25),
          rotation: -30,
          arc: false,
          sweep: true,
          end: Point(700, 300),
        ),
        Line(start: Point(700, 300), end: Point(750, 275)),
        Arc(
          start: Point(750, 275),
          radius: Point(25, 50),
          rotation: -30,
          arc: false,
          sweep: true,
          end: Point(800, 250),
        ),
        Line(start: Point(800, 250), end: Point(850, 225)),
        Arc(
          start: Point(850, 225),
          radius: Point(25, 75),
          rotation: -30,
          arc: false,
          sweep: true,
          end: Point(900, 200),
        ),
        Line(start: Point(900, 200), end: Point(950, 175)),
        Arc(
          start: Point(950, 175),
          radius: Point(25, 100),
          rotation: -30,
          arc: false,
          sweep: true,
          end: Point(1000, 150),
        ),
        Line(start: Point(1000, 150), end: Point(1050, 125)),
      ]),
    );
  });

  // def test_others(self):
  //     # Other paths that need testing:

  //     # Relative moveto:
  //     path1 = parsePath("M 0 0 L 50 20 m 50 80 L 300 100 L 200 300 z")
  //     expect(
  //         path1,
  //         Path.fromSegments(const [
  //             Move(0j),
  //             Line(start: Point(0, 0), end: Point(50, 20)),
  //             Move(to: Point(100, 100)),
  //             Line(start: Point(100, 100), end: Point(300, 100)),
  //             Line(start: Point(300, 100), end: Point(200, 300)),
  //             Close(Point(200, 300), Point(100, 100)),
  //         ),
  //     )

  //     # Initial smooth and relative CubicBezier
  //     path1 = parsePath("""M100,200 s 150,-100 150,0""")
  //     expect(
  //         path1,
  //         Path.fromSegments(const [
  //             Move(to: Point(100, 200)),
  //             CubicBezier(start: Point(100, 200), control1: Point(100, 200), control2: Point(250, 100), end: Point(250, 200),),
  //         ),
  //     )

  //     # Initial smooth and relative QuadraticBezier
  //     path1 = parsePath("""M100,200 t 150,0""")
  //     expect(
  //         path1,
  //         Path.fromSegments(const [Move(Point(100, 200)), QuadraticBezier(start: Point(100, 200), control: Point(100, 200), end: Point(250, 200)),),
  //     )

  //     # Relative QuadraticBezier
  //     path1 = parsePath("""M100,200 q 0,0 150,0""")
  //     expect(
  //         path1,
  //         Path.fromSegments(const [Move(Point(100, 200)), QuadraticBezier(start: Point(100, 200), control: Point(100, 200), end: Point(250, 200)),),
  //     )

  // def test_negative(self):
  //     """You don't need spaces before a minus-sign"""
  //     path1 = parsePath("M100,200c10-5,20-10,30-20")
  //     path2 = parsePath("M 100 200 c 10 -5 20 -10 30 -20")
  //     expect(path1, path2)

  // def test_numbers(self):
  //     """Exponents and other number format cases"""
  //     # It can be e or E, the plus is optional, and a minimum of +/-3.4e38 must be supported.
  //     path1 = parsePath("M-3.4e38 3.4E+38L-3.4E-38,3.4e-38")
  //     path2 = Path.fromSegments(const [
  //         Move(-3.4e38 + 3.4e38j), Line(-3.4e38 + 3.4e38j, -3.4e-38 + 3.4e-38j)
  //     )
  //     expect(path1, path2)

  // def test_errors(self):
  //     self.assertRaises(ValueError, parsePath, "M 100 100 L 200 200 Z 100 200")

  // def test_non_path(self):
  //     # It's possible in SVG to create paths that has zero length,
  //     # we need to handle that.

  //     path = parsePath("M10.236,100.184")
  //     expect(path.d(), "M 10.236,100.184")

  // def test_issue_45(self):
  //     path = parsePath(
  //         "m 1672.2372,-54.8161 "
  //         "a 14.5445,14.5445 0 0 0 -11.3152,23.6652 "
  //         "l 27.2573,27.2572 27.2572,-27.2572 "
  //         "a 14.5445,14.5445 0 0 0 -11.3012,-23.634 "
  //         "a 14.5445,14.5445 0 0 0 -11.414,5.4625 "
  //         "l -4.542,4.5420 "
  //         "l -4.5437,-4.5420 "
  //         "a 14.5445,14.5445 0 0 0 -11.3984,-5.4937 "
  //         "z"
  //     )

  //     self.assertIn("A 14.5445,14.5445 0 0,0 1672.24,-54.8161 Z", path.d())
}
