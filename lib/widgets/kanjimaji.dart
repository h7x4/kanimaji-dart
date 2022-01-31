import 'package:flutter/material.dart';

extension _Hexcode on Color {
  String get hexcode => '#${value.toRadixString(16).padLeft(8, '0')}';
}

class Kanimaji extends StatelessWidget {
  final String kanji;
  const Kanimaji({
    Key? key,
    required this.kanji,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
