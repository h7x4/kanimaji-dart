// import pytest
// from svg.path import parser

import 'package:flutter_test/flutter_test.dart';
import 'package:kanimaji/common/point.dart';
import 'package:kanimaji/svg/parser.dart' show Command, Token, commandifyPath, parsePath, tokenizePath;

class TokenizerTest {
  final String pathdef;
  final List<Command> commands;
  final List<Token> tokens;

  const TokenizerTest({
    required this.pathdef,
    required this.commands,
    required this.tokens,
  });
}

final List<TokenizerTest> tokenizerTests = [
  const TokenizerTest(
    pathdef: "M 100 100 L 300 100 L 200 300 z",
    commands: [
      Command(command: "M", args: "100 100"),
      Command(command: "L", args: "300 100"),
      Command(command: "L", args: "200 300"),
      Command(command: "z", args: ""),
    ],
    tokens: [
      Token(command: "M", args: [Point(100, 100)]),
      Token(command: "L", args: [Point(300, 100)]),
      Token(command: "L", args: [Point(200, 300)]),
      Token(command: "z", args: [])
    ],
  ),
  const TokenizerTest(
    pathdef:
        "M 5 1 v 7.344 A 3.574 3.574 0 003.5 8 3.515 3.515 0 000 11.5 C 0 13.421 1.579 15 3.5 15 "
        "A 3.517 3.517 0 007 11.531 v -7.53 h 6 v 4.343 A 3.574 3.574 0 0011.5 8 3.515 3.515 0 008 11.5 "
        "c 0 1.921 1.579 3.5 3.5 3.5 1.9 0 3.465 -1.546 3.5 -3.437 V 1 z",
    commands: [
      Command(command: "M", args: "5 1"),
      Command(command: "v", args: "7.344"),
      Command(
          command: "A", args: "3.574 3.574 0 003.5 8 3.515 3.515 0 000 11.5"),
      Command(command: "C", args: "0 13.421 1.579 15 3.5 15"),
      Command(command: "A", args: "3.517 3.517 0 007 11.531"),
      Command(command: "v", args: "-7.53"),
      Command(command: "h", args: "6"),
      Command(command: "v", args: "4.343"),
      Command(
          command: "A", args: "3.574 3.574 0 0011.5 8 3.515 3.515 0 008 11.5"),
      Command(
          command: "c",
          args: "0 1.921 1.579 3.5 3.5 3.5 1.9 0 3.465 -1.546 3.5 -3.437"),
      Command(command: "V", args: "1"),
      Command(command: "z", args: ""),
    ],
    tokens: [
      Token(command: "M", args: [Point(5, 1)]),
      Token(command: "v", args: [7.344]),
      Token(command: "A", args: [3.574, 3.574, 0, false, false, Point(3.5, 8)]),
      Token(
          command: "A", args: [3.515, 3.515, 0, false, false, Point(0, 11.5)]),
      Token(
          command: "C",
          args: [Point(0, 13.421), Point(1.579, 15), Point(3.5, 15)]),
      Token(
          command: "A",
          args: [3.517, 3.517, 0, false, false, Point(7, 11.531)]),
      Token(command: "v", args: [-7.53]),
      Token(command: "h", args: [6]),
      Token(command: "v", args: [4.343]),
      Token(
          command: "A", args: [3.574, 3.574, 0, false, false, Point(11.5, 8)]),
      Token(
          command: "A", args: [3.515, 3.515, 0, false, false, Point(8, 11.5)]),
      Token(
          command: "c",
          args: [Point(0, 1.921), Point(1.579, 3.5), Point(3.5, 3.5)]),
      Token(
          command: "c",
          args: [Point(1.9, 0), Point(3.465, -1.546), Point(3.5, -3.437)]),
      Token(command: "V", args: [1]),
      Token(command: "z", args: []),
    ],
  ),
  const TokenizerTest(
    pathdef: "M 600,350 L 650,325 A 25,25 -30 0,1 700,300 L 750,275",
    commands: [
      Command(command: "M", args: "600,350"),
      Command(command: "L", args: "650,325"),
      Command(command: "A", args: "25,25 -30 0,1 700,300"),
      Command(command: "L", args: "750,275"),
    ],
    tokens: [
      Token(command: "M", args: [Point(600, 350)]),
      Token(command: "L", args: [Point(650, 325)]),
      Token(command: "A", args: [25, 25, -30, false, true, Point(700, 300)]),
      Token(command: "L", args: [Point(750, 275)]),
    ],
  ),
];

void main() {
  test('Test commandifier', () {
    for (final tokenizerTest in tokenizerTests) {
      expect(commandifyPath(tokenizerTest.pathdef), tokenizerTest.commands);
    }
  });

  test('Test tokenizer', () {
    for (final tokenizerTest in tokenizerTests) {
      expect(tokenizePath(tokenizerTest.pathdef), tokenizerTest.tokens);
    }
  });

  test('Test parser', () {
    for (final tokenizerTest in tokenizerTests) {
      parsePath(tokenizerTest.pathdef);
    }
  });
}