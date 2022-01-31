/// SVG Path specification parser
///
import 'path.dart'
    show Arc, Close, CubicBezier, Line, Move, Path, Point, QuadraticBezier;

const COMMANDS = {
  'M',
  'm',
  'Z',
  'z',
  'L',
  'l',
  'H',
  'h',
  'V',
  'v',
  'C',
  'c',
  'S',
  's',
  'Q',
  'q',
  'T',
  't',
  'A',
  'a'
};
const UPPERCASE = {'M', 'Z', 'L', 'H', 'V', 'C', 'S', 'Q', 'T', 'A'};

final COMMAND_RE = RegExp("(?=[${COMMANDS.join('')}])");
final FLOAT_RE = RegExp(r"^[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?");

class ParserResult<T> {
  final T value;
  final String remaining;

  const ParserResult({required this.value, required this.remaining});
}

class InvalidPathError implements Exception {
  final String msg;
  const InvalidPathError(this.msg);

  @override
  String toString() => 'InvalidPathError: $msg';
}

// The argument sequences from the grammar, made sane.
// u: Non-negative number
// s: Signed number or coordinate
// c: coordinate-pair, which is two coordinates/numbers, separated by whitespace
// f: A one character flag, doesn't need whitespace, 1 or 0
const ARGUMENT_SEQUENCE = {
  "M": "c",
  "Z": "",
  "L": "c",
  "H": "s",
  "V": "s",
  "C": "ccc",
  "S": "cc",
  "Q": "cc",
  "T": "c",
  "A": "uusffc",
};

/// Strips whitespace and commas
String strip_array(String arg_array) {
  // EBNF wsp:(#x20 | #x9 | #xD | #xA) + comma: 0x2C
  while (arg_array.isNotEmpty && ' \t\n\r,'.contains(arg_array[0])) {
    arg_array = arg_array.substring(1);
  }
  return arg_array;
}

ParserResult<double> pop_number(String arg_array) {
  final res = FLOAT_RE.firstMatch(arg_array);
  if (res == null) {
    throw InvalidPathError("Expected a number, got '$arg_array'.");
  }

  final number = double.parse(res.group(0)!);
  final start = res.start;
  final end = res.end;
  arg_array = arg_array.substring(0, start) + arg_array.substring(end);
  arg_array = strip_array(arg_array);

  return ParserResult(value: number, remaining: arg_array);
}

ParserResult<double> pop_unsigned_number(arg_array) {
  final number = pop_number(arg_array);
  if (number.value < 0) {
    throw InvalidPathError("Expected a non-negative number, got '$number'.");
  }
  return number;
}

ParserResult<Point> pop_coordinate_pair(arg_array) {
  final x = pop_number(arg_array);
  final y = pop_number(x.remaining);
  return ParserResult(value: Point(x.value, y.value), remaining: y.remaining);
}

ParserResult<bool> pop_flag(String arg_array) {
  final flag = arg_array[0];
  arg_array = arg_array.substring(1);
  arg_array = strip_array(arg_array);
  if (flag == '0') return ParserResult(value: false, remaining: arg_array);
  if (flag == '1') return ParserResult(value: true, remaining: arg_array);

  throw InvalidPathError("Expected either 1 or 0, got '$flag'");
}

const FIELD_POPPERS = {
  "u": pop_unsigned_number,
  "s": pop_number,
  "c": pop_coordinate_pair,
  "f": pop_flag,
};

class Command {
  final String command;
  final String args;

  const Command({required this.command, required this.args});

  @override
  String toString() => 'Command: $command $args';
}

// Splits path into commands and arguments
List<Command> _commandify_path(String pathdef) {
  List<Command> tokens = [];
  List<String> token = [];
  for (String c in pathdef.split(COMMAND_RE)) {
    String x = c[0];
    String? y = (c.length > 1) ? c.substring(1).trim() : null;
    if (!COMMANDS.contains(x)) {
      throw InvalidPathError("Path does not start with a command: $pathdef");
    }
    if (token.isNotEmpty) {
      tokens.add(Command(command: token[0], args: token[1]));
      // yield token;
    }
    if (x == "z" || x == "Z") {
      // The end command takes no arguments, so add a blank one
      token.addAll([x, ""]);
    } else {
      // token = [x, x.substring(1).trim()];
      token = [x];
    }

    if (y != null) {
      token.add(y);
    }
  }
  tokens.add(Command(command: token[0], args: token[1]));
  // yield token;
  return tokens;
}

class Token {
  final String command;
  final List<Object> args;

  const Token({required this.command, required this.args});

  @override
  String toString() => 'Token: $command ($args)';
}

List<Token> _tokenize_path(String pathdef) {
  List<Token> tokens = [];
  for (final token in _commandify_path(pathdef)) {
    // _commandify_path(pathdef).forEach((List<String> token) {
    String command = token.command;
    String args = token.args;

    // Shortcut this for the close command, that doesn't have arguments:
    if (command == "z" || command == "Z") {
      tokens.add(Token(command: command, args: []));
      continue;
    }

    // For the rest of the commands, we parse the arguments and
    // yield one command per full set of arguments
    final String arg_sequence = ARGUMENT_SEQUENCE[command.toUpperCase()]!;
    String arguments = args;
    while (arguments.isNotEmpty) {
      final List<Object> command_arguments = [];
      for (final arg in arg_sequence.split('')) {
        try {
          final result = FIELD_POPPERS[arg]!.call(arguments);
          arguments = result.remaining;
          command_arguments.add(result.value);
        } on InvalidPathError {
          throw InvalidPathError("Invalid path element $command $args");
        }
      }

      tokens.add(Token(command: command, args: command_arguments));
      // yield (command,) + tuple(command_arguments)

      // Implicit Moveto commands should be treated as Lineto commands.
      if (command == "m") {
        command = "l";
      } else if (command == "M") {
        command = "L";
      }
    }
  }
  return tokens;
}

Path parse_path(String pathdef) {
  final segments = Path();
  Point? start_pos;
  String? last_command;
  Point current_pos = Point.zero;

  for (final token in _tokenize_path(pathdef)) {
    final command = token.command.toUpperCase();
    final absolute = token.command.toUpperCase() == token.command;
    if (command == "M") {
      final pos = token.args[0] as Point;
      if (absolute) {
        current_pos = pos;
      } else {
        current_pos += pos;
      }
      segments.add(Move(to: current_pos));
      start_pos = current_pos;
    } else if (command == "Z") {
      // TODO Throw error if not available:
      segments.add(Close(start: current_pos, end: start_pos!));
      current_pos = start_pos;
    } else if (command == "L") {
      Point pos = token.args[0] as Point;
      if (!absolute) {
        pos += current_pos;
      }
      segments.add(Line(start: current_pos, end: pos));
      current_pos = pos;
    } else if (command == "H") {
      double hpos = token.args[0] as double;
      if (!absolute) {
        hpos += current_pos.x;
      }
      final pos = Point(hpos, current_pos.y);
      segments.add(Line(start: current_pos, end: pos));
      current_pos = pos;
    } else if (command == "V") {
      double vpos = token.args[0] as double;
      if (!absolute) {
        vpos += current_pos.y;
      }
      final pos = Point(current_pos.x, vpos);
      segments.add(Line(start: current_pos, end: pos));
      current_pos = pos;
    } else if (command == "C") {
      Point control1 = token.args[0] as Point;
      Point control2 = token.args[1] as Point;
      Point end = token.args[2] as Point;

      if (!absolute) {
        control1 += current_pos;
        control2 += current_pos;
        end += current_pos;
      }

      segments.add(
        CubicBezier(
          start: current_pos,
          control1: control1,
          control2: control2,
          end: end,
        ),
      );
      current_pos = end;
    } else if (command == "S") {
      // Smooth curve. First control point is the "reflection" of
      // the second control point in the previous path.
      Point control2 = token.args[0] as Point;
      Point end = token.args[1] as Point;

      if (!absolute) {
        control2 += current_pos;
        end += current_pos;
      }

      late final Point control1;

      if (last_command == 'C' || last_command == 'S') {
        // The first control point is assumed to be the reflection of
        // the second control point on the previous command relative
        // to the current point.
        control1 =
            current_pos + current_pos - (segments.last as CubicBezier).control2;
      } else {
        // If there is no previous command or if the previous command
        // was not an C, c, S or s, assume the first control point is
        // coincident with the current point.
        control1 = current_pos;
      }
      segments.add(
        CubicBezier(
            start: current_pos,
            control1: control1,
            control2: control2,
            end: end),
      );
      current_pos = end;
    } else if (command == "Q") {
      Point control = token.args[0] as Point;
      Point end = token.args[1] as Point;

      if (!absolute) {
        control += current_pos;
        end += current_pos;
      }

      segments.add(
        QuadraticBezier(start: current_pos, control: control, end: end),
      );
      current_pos = end;
    } else if (command == "T") {
      // Smooth curve. Control point is the "reflection" of
      // the second control point in the previous path.
      Point end = token.args[0] as Point;

      if (!absolute) {
        end += current_pos;
      }

      late final Point control;
      if (last_command == "Q" || last_command == 'T') {
        // The control point is assumed to be the reflection of
        // the control point on the previous command relative
        // to the current point.
        control = current_pos +
            current_pos -
            (segments.last as QuadraticBezier).control;
      } else {
        // If there is no previous command or if the previous command
        // was not an Q, q, T or t, assume the first control point is
        // coincident with the current point.
        control = current_pos;
      }

      segments.add(
        QuadraticBezier(start: current_pos, control: control, end: end),
      );
      current_pos = end;
    } else if (command == "A") {
      // For some reason I implemented the Arc with a complex radius.
      // That doesn't really make much sense, but... *shrugs*
      final radius = Point(token.args[0] as double, token.args[1] as double);
      final rotation = token.args[2] as double;
      final arc = token.args[3] as bool;
      final sweep = token.args[4] as bool;
      Point end = token.args[5] as Point;

      if (!absolute) {
        end += current_pos;
      }

      segments.add(
        Arc(
          start: current_pos,
          radius: radius,
          rotation: rotation,
          arc: arc,
          sweep: sweep,
          end: end,
        ),
      );
      current_pos = end;
    }

    // Finish up the loop in preparation for next command
    last_command = command;
  }

  return segments;
}

void main(List<String> args) {
  // print(_commandify_path('M 10 10 C 20 20, 40 20, 50 10'));
//   print(_tokenize_path('M 10 10 C 20 20, 40 20, 50 10'));
//   print(_tokenize_path('M 10 80 Q 52.5 10, 95 80 T 180 80'));
//   print(_tokenize_path("""
// M 10 315
//            L 110 215
//            A 30 50 0 0 1 162.55 162.45
//            L 172.55 152.45
//            A 30 50 -45 0 1 215.1 109.9
//            L 315 10
//   """));

  print(parse_path('M 10 10 C 20 20, 40 20, 50 10'));
  print(parse_path('M 10 80 Q 52.5 10, 95 80 T 180 80'));
  print(parse_path("""
M 10 315
           L 110 215
           A 30 50 0 0 1 162.55 162.45
           L 172.55 152.45
           A 30 50 -45 0 1 215.1 109.9
           L 315 10
  """));
}