/// SVG Path specification parser

import '../common/Point.dart';
import 'path.dart';

const _commands = {
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

// const _uppercaseCommands = {'M', 'Z', 'L', 'H', 'V', 'C', 'S', 'Q', 'T', 'A'};

final _commandPattern = RegExp("(?=[${_commands.join('')}])");
final _floatPattern = RegExp(r"^[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?");

class _ParserResult<T> {
  final T value;
  final String remaining;

  const _ParserResult({required this.value, required this.remaining});
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
const _argumentSequence = {
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
String _stripArray(String stringToParse) {
  // EBNF wsp:(#x20 | #x9 | #xD | #xA) + comma: 0x2C
  while (stringToParse.isNotEmpty && ' \t\n\r,'.contains(stringToParse[0])) {
    stringToParse = stringToParse.substring(1);
  }
  return stringToParse;
}

_ParserResult<num> _parseNumber(String stringToParse) {
  final res = _floatPattern.firstMatch(stringToParse);
  if (res == null) {
    throw InvalidPathError("Expected a number, got '$stringToParse'.");
  }

  final number = num.parse(res.group(0)!);
  final start = res.start;
  final end = res.end;
  stringToParse =
      stringToParse.substring(0, start) + stringToParse.substring(end);
  stringToParse = _stripArray(stringToParse);

  return _ParserResult(value: number, remaining: stringToParse);
}

_ParserResult<num> _parseUnsignedNumber(String stringToParse) {
  final number = _parseNumber(stringToParse);
  if (number.value < 0) {
    throw InvalidPathError("Expected a non-negative number, got '$number'.");
  }
  return number;
}

_ParserResult<Point> _parseCoordinatePair(String stringToParse) {
  final x = _parseNumber(stringToParse);
  final y = _parseNumber(x.remaining);
  return _ParserResult(value: Point(x.value, y.value), remaining: y.remaining);
}

_ParserResult<bool> _parseflag(String stringToParse) {
  final flag = stringToParse[0];
  stringToParse = stringToParse.substring(1);
  stringToParse = _stripArray(stringToParse);
  if (flag == '0') return _ParserResult(value: false, remaining: stringToParse);
  if (flag == '1') return _ParserResult(value: true, remaining: stringToParse);

  throw InvalidPathError("Expected either 1 or 0, got '$flag'");
}

const fieldParsers = {
  "u": _parseUnsignedNumber,
  "s": _parseNumber,
  "c": _parseCoordinatePair,
  "f": _parseflag,
};

class _Command {
  final String command;
  final String args;

  const _Command({required this.command, required this.args});

  @override
  String toString() => 'Command: $command $args';
}

// Splits path into commands and arguments
List<_Command> _commandifyPath(String pathdef) {
  List<_Command> tokens = [];
  List<String> token = [];
  for (String c in pathdef.split(_commandPattern)) {
    String x = c[0];
    String? y = (c.length > 1) ? c.substring(1).trim() : null;

    if (!_commands.contains(x)) {
      throw InvalidPathError("Path does not start with a command: $pathdef");
    }
    if (token.isNotEmpty) {
      tokens.add(_Command(command: token[0], args: token[1]));
      // yield token;
    }
    if (x == "z" || x == "Z") {
      // The end command takes no arguments, so add a blank one
      token = [x, ""];
    } else {
      token = [x];
    }

    if (y != null) {
      token.add(y);
    }
  }
  tokens.add(_Command(command: token[0], args: token[1]));
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

List<Token> _tokenizePath(String pathdef) {
  List<Token> tokens = [];
  for (final token in _commandifyPath(pathdef)) {
    String command = token.command;
    String args = token.args;

    // Shortcut this for the close command, that doesn't have arguments:
    if (command == "z" || command == "Z") {
      tokens.add(Token(command: command, args: []));
      continue;
    }

    // For the rest of the commands, we parse the arguments and
    // yield one command per full set of arguments
    final String stringToParse = _argumentSequence[command.toUpperCase()]!;
    String arguments = args;
    while (arguments.isNotEmpty) {
      final List<Object> commandArguments = [];
      for (final arg in stringToParse.split('')) {
        try {
          final result = fieldParsers[arg]!.call(arguments);
          arguments = result.remaining;
          commandArguments.add(result.value);
        } on InvalidPathError {
          throw InvalidPathError("Invalid path element $command $args");
        }
      }

      tokens.add(Token(command: command, args: commandArguments));

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

Path parsePath(String pathdef) {
  final segments = Path();
  Point? startPos;
  String? lastCommand;
  Point currentPos = Point.zero;

  for (final token in _tokenizePath(pathdef)) {
    final command = token.command.toUpperCase();
    final absolute = token.command.toUpperCase() == token.command;
    if (command == "M") {
      final pos = token.args[0] as Point;
      if (absolute) {
        currentPos = pos;
      } else {
        currentPos += pos;
      }
      segments.add(Move(to: currentPos));
      startPos = currentPos;
    } else if (command == "Z") {
      // TODO Throw error if not available:
      segments.add(Close(start: currentPos, end: startPos!));
      currentPos = startPos;
    } else if (command == "L") {
      Point pos = token.args[0] as Point;
      if (!absolute) {
        pos += currentPos;
      }
      segments.add(Line(start: currentPos, end: pos));
      currentPos = pos;
    } else if (command == "H") {
      num hpos = token.args[0] as num;
      if (!absolute) {
        hpos += currentPos.x;
      }
      final pos = Point(hpos, currentPos.y);
      segments.add(Line(start: currentPos, end: pos));
      currentPos = pos;
    } else if (command == "V") {
      num vpos = token.args[0] as num;
      if (!absolute) {
        vpos += currentPos.y;
      }
      final pos = Point(currentPos.x, vpos);
      segments.add(Line(start: currentPos, end: pos));
      currentPos = pos;
    } else if (command == "C") {
      Point control1 = token.args[0] as Point;
      Point control2 = token.args[1] as Point;
      Point end = token.args[2] as Point;

      if (!absolute) {
        control1 += currentPos;
        control2 += currentPos;
        end += currentPos;
      }

      segments.add(
        CubicBezier(
          start: currentPos,
          control1: control1,
          control2: control2,
          end: end,
        ),
      );
      currentPos = end;
    } else if (command == "S") {
      // Smooth curve. First control point is the "reflection" of
      // the second control point in the previous path.
      Point control2 = token.args[0] as Point;
      Point end = token.args[1] as Point;

      if (!absolute) {
        control2 += currentPos;
        end += currentPos;
      }

      late final Point control1;

      if (lastCommand == 'C' || lastCommand == 'S') {
        // The first control point is assumed to be the reflection of
        // the second control point on the previous command relative
        // to the current point.
        control1 =
            currentPos + currentPos - (segments.last as CubicBezier).control2;
      } else {
        // If there is no previous command or if the previous command
        // was not an C, c, S or s, assume the first control point is
        // coincident with the current point.
        control1 = currentPos;
      }
      segments.add(
        CubicBezier(
          start: currentPos,
          control1: control1,
          control2: control2,
          end: end,
        ),
      );
      currentPos = end;
    } else if (command == "Q") {
      Point control = token.args[0] as Point;
      Point end = token.args[1] as Point;

      if (!absolute) {
        control += currentPos;
        end += currentPos;
      }

      segments.add(
        QuadraticBezier(start: currentPos, control: control, end: end),
      );
      currentPos = end;
    } else if (command == "T") {
      // Smooth curve. Control point is the "reflection" of
      // the second control point in the previous path.
      Point end = token.args[0] as Point;

      if (!absolute) {
        end += currentPos;
      }

      late final Point control;
      if (lastCommand == "Q" || lastCommand == 'T') {
        // The control point is assumed to be the reflection of
        // the control point on the previous command relative
        // to the current point.
        control = currentPos +
            currentPos -
            (segments.last as QuadraticBezier).control;
      } else {
        // If there is no previous command or if the previous command
        // was not an Q, q, T or t, assume the first control point is
        // coincident with the current point.
        control = currentPos;
      }

      segments.add(
        QuadraticBezier(start: currentPos, control: control, end: end),
      );
      currentPos = end;
    } else if (command == "A") {
      // For some reason I implemented the Arc with a complex radius.
      // That doesn't really make much sense, but... *shrugs*
      final radius = Point(token.args[0] as num, token.args[1] as num);
      final rotation = token.args[2] as num;
      final arc = token.args[3] as bool;
      final sweep = token.args[4] as bool;
      Point end = token.args[5] as Point;

      if (!absolute) {
        end += currentPos;
      }

      segments.add(
        Arc(
          start: currentPos,
          radius: radius,
          rotation: rotation,
          arc: arc,
          sweep: sweep,
          end: end,
        ),
      );
      currentPos = end;
    }

    // Finish up the loop in preparation for next command
    lastCommand = command;
  }

  return segments;
}
