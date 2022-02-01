
# Kanimaji

Add animated kanji strokes to your app!

## Features

This library is a port of [Kanimaji][kanimaji], a library for animating kanji.
It provides a way to convert stroke data from [KanjiVG][kanjivg] into kanji animations.

This library ports this ability into flutter, and lets you choose speed, colors, and formats, in the form of a `Kanimaji` widget and a SVG/GIF generating function.

## Getting started

Start by adding the project to your pubspec.yaml.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder. 

```dart
const like = 'sample';
```

## Additional information

The [svg library used](lib/svg) is mostly a rewrite of pythons [svg.path][svg.path].
This is what kanimaji originally used for animation, and even thought there's a lot of svg path parsers in dart, I found none that was able to calculate the length of the path. If you do find one, please let me know!

Also, do note that most of the comments in the project is brought over from the python projects.
I've tried to adjust and remove some of them to make them more useful, but they shouldn't be trusted if there's doubt.

[svg.path]: https://pypi.org/project/svg.path/