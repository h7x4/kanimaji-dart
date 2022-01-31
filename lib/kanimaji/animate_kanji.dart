/// ignore_for_file: non_constant_identifier_names, avoid_print, unused_local_variable, dead_code, constant_identifier_names

import 'dart:io';
import 'dart:math' show min, sqrt, pow;

import '../svg/parser.dart';
import '../common/Point.dart';

import 'bezier_cubic.dart' as bezier_cubic;
import 'package:xml/xml.dart';
import 'package:path/path.dart';

double _computePathLength(String path) =>
    parse_path(path).size(error: 1e-8).toDouble();

String _shescape(String path) =>
    "'${path.replaceAll(RegExp(r"(?=['\\\\])"), "\\\\")}'";

extension _Dedent on String {
  String get dedented {
    final withoutEmptyLines =
        this.split('\n').where((l) => l.isNotEmpty).toList();
    final whitespaceAmounts = [
      for (final line in withoutEmptyLines)
        line.split('').takeWhile((c) => c == ' ').length
    ];
    final whitespaceToRemove = whitespaceAmounts.reduce(min);
    return withoutEmptyLines
        .map((l) => l.replaceRange(0, whitespaceToRemove, ''))
        .join('\n');
  }
}

class JsAnimationElement {
  final XmlDocumentFragment bg;
  final XmlDocumentFragment anim;
  final XmlDocumentFragment? brush;
  final XmlDocumentFragment? brushBorder;

  /// the time set (as default) for each animation
  final num time;

  const JsAnimationElement({
    required this.bg,
    required this.anim,
    required this.time,
    this.brush,
    this.brushBorder,
  });
}

// ease, ease-in, etc:
// https://developer.mozilla.org/en-US/docs/Web/CSS/timing-function#ease
const pt1 = Point(0, 0);
const easeCt1 = Point(0.25, 0.1);
const easeCt2 = Point(0.25, 1.0);
const easeInCt1 = Point(0.42, 0.0);
const easeInCt2 = Point(1.0, 1.0);
const easeInOutCt1 = Point(0.42, 0.0);
const easeInOutCt2 = Point(0.58, 1.0);
const easeOutCt1 = Point(0.0, 0.0);
const easeOutCt2 = Point(0.58, 1.0);
const pt2 = Point(1, 1);

// class  {
// }

enum TimingFunction {
  linear,
  ease,
  easeIn,
  easeInOut,
  easeOut,
}

extension Funcs on TimingFunction {
  double Function(double) get func => {
        TimingFunction.linear: (double x) => x,
        TimingFunction.ease: (double x) =>
            bezier_cubic.value(pt1, easeCt1, easeCt2, pt2, x),
        TimingFunction.easeIn: (double x) =>
            bezier_cubic.value(pt1, easeInCt1, easeInCt2, pt2, x),
        TimingFunction.easeInOut: (double x) =>
            bezier_cubic.value(pt1, easeInOutCt1, easeInOutCt2, pt2, x),
        TimingFunction.easeOut: (double x) =>
            bezier_cubic.value(pt1, easeOutCt1, easeOutCt2, pt2, x),
      }[this]!;

  String get name => {
        TimingFunction.linear: 'linear',
        TimingFunction.ease: 'ease',
        TimingFunction.easeIn: 'ease-in',
        TimingFunction.easeInOut: 'ease-in-out',
        TimingFunction.easeOut: 'ease-out',
      }[this]!;
}

// we will need this to deal with svg
const namespaces = {
  'n': 'http://www.w3.org/2000/svg',
  'xlink': 'http://www.w3.org/1999/xlink'
};
// etree.register_namespace("xlink","http://www.w3.org/1999/xlink")
// final parser = etree.XMLParser(remove_blank_text=true);

// gif settings
// const DELETE_TEMPORARY_FILES = false;
const GIF_SIZE = 150;
const GIF_FRAME_DURATION = 0.04;
const GIF_BACKGROUND_COLOR = '#ddf';
// set to true to allow transparent background, much bigger file!
// const GIF_ALLOW_TRANSPARENT = false;

// edit here to decide what will be generated
const GENERATE_SVG = true;
const GENERATE_JS_SVG = true;
const GENERATE_GIF = true;

/// sqrt, ie a stroke 4 times the length is drawn
/// at twice the speed, in twice the time.
double strokeLengthToDuration(double length) => sqrt(length) / 8;

/// global time rescale, let's make animation a bit
/// faster when there are many strokes.
double timeRescale(interval) => pow(2 * interval, 2.0 / 3).toDouble();

/// clear all extra elements this program may have previously added
void clearPreviousElements(XmlDocument doc) {
  for (final XmlNode el in doc
          .getElement('svg', namespace: namespaces['n'])
          ?.getElement('style', namespace: namespaces['n'])
          ?.children ??
      []) {
    if (RegExp(r'-Kanimaji$').hasMatch(el.getAttribute('id') ?? '')) {
      el.parent!.children.remove(el);
    }
  }
  for (final XmlNode g in doc
          .getElement('svg', namespace: namespaces['n'])
          ?.getElement('g', namespace: namespaces['n'])
          ?.children ??
      []) {
    if (RegExp(r'-Kanimaji$').hasMatch(g.getAttribute('id') ?? '')) {
      g.parent!.children.remove(g);
    }
  }
}

/// Note: setting any color to transparent will result in a much bigger
/// filesize for GIFs.
void createAnimation({
  required String inputFile,
  String? outputFile,
  TimingFunction timingFunction = TimingFunction.easeInOut,
  double strokeBorderWidth = 4.5,
  double strokeUnfilledWidth = 3,
  double strokeFilledWidth = 3.1,
  bool showBrush = true,
  bool showBrushFrontBorder = true,
  double brushWidth = 5.5,
  double brushBorderWidth = 7,
  double waitAfter = 1.5,
  String strokeBorderColor = '#666',
  String strokeUnfilledColor = '#EEE',
  String strokeFillingColor = '#F00',
  String strokeFilledColor = '#000',
  String brushColor = '#F00',
  String brushBorderColor = '#666',
}) {
  print('processing $inputFile');
  final String filenameNoext = inputFile.replaceAll(RegExp(r'\.[^\.]+$'), '');
  outputFile ??= '${filenameNoext}_anim.svg';
  final String baseid = basename(filenameNoext);

  // load xml
  final XmlDocument doc = XmlDocument.parse(File(inputFile).readAsStringSync());

  // for xlink namespace introduction
  doc.rootElement.setAttribute('xmlns:xlink', namespaces['xlink']);
  doc.rootElement.setAttribute('xlink:used', '');

  clearPreviousElements(doc);

  /// create groups with a copies (references actually) of the paths
  XmlDocumentFragment pathCopyGroup({
    required String id,
    required String color,
    required double width,
  }) {
    final builder = XmlBuilder();
    builder.element(
      'g',
      attributes: {
        'id': 'kvg:$baseid-$id-Kanimaji',
        'style': 'fill:none;'
            'stroke:$color;'
            'stroke-width:$width;'
            'stroke-linecap:round;'
            'stroke-linejoin:round;',
      },
      isSelfClosing: false,
    );
    return builder.buildFragment();
  }

  final bgGroup = pathCopyGroup(
    id: 'bg',
    color: strokeUnfilledColor,
    width: strokeUnfilledWidth,
  );
  final animGroup = pathCopyGroup(
    id: 'anim',
    color: strokeFilledColor,
    width: strokeFilledWidth,
  );

  late final XmlDocumentFragment brushGroup;
  late final XmlDocumentFragment brushBrdGroup;
  if (showBrush) {
    brushGroup = pathCopyGroup(
      id: 'brush',
      color: brushColor,
      width: brushWidth,
    );
    brushBrdGroup = pathCopyGroup(
      id: 'brush-brd',
      color: brushBorderColor,
      width: brushBorderWidth,
    );
  }

  // compute total length and time, at first
  double totlen = 0;
  double tottime = 0;

  // for (final g in doc.xpath("/n:svg/n:g", namespaces=namespaces) {
  for (final XmlNode g in doc
          .getElement('svg', namespace: namespaces['n'])
          ?.getElement('g', namespace: namespaces['n'])
          ?.children ??
      []) {
    if (RegExp(r'^kvg:StrokeNumbers_').hasMatch(g.getAttribute('id') ?? '')) {
      continue;
    }

    for (final p in g.findAllElements('path', namespace: namespaces['n'])) {
      final pathlen = _computePathLength(p.getAttribute('d')!);
      final duration = strokeLengthToDuration(pathlen);
      totlen += pathlen;
      tottime += duration;
    }
  }

  double animationTime = timeRescale(tottime); // math.pow(3 * tottime, 2.0/3)
  tottime += waitAfter * tottime / animationTime;
  final double actualAnimationTime = animationTime;
  animationTime += waitAfter;

  final Map<int, String> staticCss = {};
  late String animatedCss;

  /// collect the ids of animating elements
  final List<JsAnimationElement> jsAnimationElements = [];

  String jsAnimatedCss = '';

  const String cssHeader =
      '\n/* CSS automatically generated by kanimaji.py, do not edit! */\n';
  if (GENERATE_SVG) animatedCss = cssHeader;
  if (GENERATE_JS_SVG) {
    jsAnimatedCss += cssHeader +
        '''
          .backward {\n
              animation-direction: reverse !important;\n
          }
          ''';
  }
  late final int lastFrameIndex;
  late final double lastFrameDelay;
  if (GENERATE_GIF) {
    // final static_css = {};
    lastFrameIndex = actualAnimationTime ~/ GIF_FRAME_DURATION + 1;
    for (int i = 0; i < lastFrameIndex + 1; i++) {
      staticCss[i] = cssHeader;
    }
    lastFrameDelay = animationTime - lastFrameIndex * GIF_FRAME_DURATION;
  }
  double elapsedlen = 0;
  double elapsedtime = 0;

  // add css elements for all strokes
  for (final XmlNode g in doc
      .getElement('svg', namespace: namespaces['n'])!
      .findElements('g', namespace: namespaces['n'])) {
    // for (final g in doc.xpath("/n:svg/n:g", namespaces=namespaces)){
    final groupid = g.getAttribute('id') ?? '';
    if (RegExp(r'^kvg:StrokeNumbers_').hasMatch(groupid)) {
      final String rule = '''
          #${groupid.replaceAll(':', '\\3a ')} {
              display: none;
          }
          '''
          .dedented;
      if (GENERATE_SVG) animatedCss += rule;
      if (GENERATE_JS_SVG) jsAnimatedCss += rule;
      if (GENERATE_GIF) {
        for (final k in staticCss.keys) {
          staticCss[k] = staticCss[k]! + rule;
        }
      }
      continue;
    }

    final gidcss = groupid.replaceAll(':', '\\3a ');
    final rule = '''
        #$gidcss {
            stroke-width: ${strokeBorderWidth.toStringAsFixed(1)}px !important;
            stroke:       $strokeBorderColor !important;
        }
        '''
        .dedented;

    if (GENERATE_SVG) animatedCss += rule;
    if (GENERATE_JS_SVG) jsAnimatedCss += rule;
    if (GENERATE_GIF) {
      for (final k in staticCss.keys) {
        staticCss[k] = staticCss[k]! + rule;
      }
    }

    for (final p in g.findAllElements("path", namespace: namespaces['n'])) {
      final pathid = p.getAttribute('id') as String;
      final pathidcss = pathid.replaceAll(':', '\\3a ');

      XmlDocumentFragment addHref(String suffix, XmlDocumentFragment parent) {
        final builder = XmlBuilder();
        builder.element(
          'use',
          attributes: {'id': '$pathid-$suffix', 'xlink:href': '#$pathid'},
        );
        final ref = builder.buildFragment();
        parent.firstElementChild!.children.add(ref);
        return ref;
      }

      final String bgPathidcss = '$pathidcss-bg';
      final String animPathidcss = '$pathidcss-anim';
      final String brushPathidcss = '$pathidcss-brush';
      final String brushBorderPathidcss = '$pathidcss-brush-brd';

      final bgGroupElement = addHref('bg', bgGroup);
      final animGroupElement = addHref('anim', animGroup);
      XmlDocumentFragment? brushGroupElement;
      XmlDocumentFragment? brushBorderGroupElement;
      if (showBrush) {
        brushGroupElement = addHref('brush', brushGroup);
        brushBorderGroupElement = addHref('brush-brd', brushBrdGroup);
      }

      final pathname = pathid.replaceAll(RegExp(r'^kvg:'), '');
      final pathlen = _computePathLength(p.getAttribute('d') as String);
      final duration = strokeLengthToDuration(pathlen);
      final relativeDuration =
          duration * tottime / animationTime; // unscaled time

      if (GENERATE_JS_SVG) {
        jsAnimationElements.add(
          JsAnimationElement(
            bg: bgGroupElement,
            anim: animGroupElement,
            brush: brushGroupElement,
            brushBorder: brushBorderGroupElement,
            time: relativeDuration,
          ),
        );
      }

      final newelapsedlen = elapsedlen + pathlen;
      final newelapsedtime = elapsedtime + duration;
      final animStart = elapsedtime / tottime * 100;
      final animEnd = newelapsedtime / tottime * 100;

      if (GENERATE_SVG) {
        // animation stroke progression
        animatedCss += '''
            @keyframes strike-$pathname {
                0% { stroke-dashoffset: ${pathlen.toStringAsFixed(3)}; }
                ${animStart.toStringAsFixed(3)}% { stroke-dashoffset: ${pathlen.toStringAsFixed(3)}; }
                ${animEnd.toStringAsFixed(3)}% { stroke-dashoffset: 0; }
                100% { stroke-dashoffset: 0; }
            }
            @keyframes showhide-$pathname {
                ${animStart.toStringAsFixed(3)}% { visibility: hidden; }
                ${animEnd.toStringAsFixed(3)}% { stroke: $strokeFillingColor; }
            }
            #$animPathidcss {
                stroke-dasharray: ${pathlen.toStringAsFixed(3)} ${pathlen.toStringAsFixed(3)};
                stroke-dashoffset: 0;
                animation: strike-$pathname ${animationTime.toStringAsFixed(3)}s ${timingFunction.name} infinite,
                    showhide-$pathname ${animationTime.toStringAsFixed(3)}s step-start infinite;
            }
            '''
            .dedented;

        if (showBrush) {
          // brush element visibility
          animatedCss += '''
              @keyframes showhide-brush-$pathname {
                  ${animStart.toStringAsFixed(3)}% { visibility: hidden; }
                  ${animEnd.toStringAsFixed(3)}% { visibility: visible; }
                  100% { visibility: hidden; }
              }
              #$brushPathidcss, #$brushBorderPathidcss {
                  stroke-dasharray: 0 ${pathlen.toStringAsFixed(3)};
                  animation: strike-$pathname ${animationTime.toStringAsFixed(3)}s ${timingFunction.name} infinite,
                      showhide-brush-$pathname ${animationTime.toStringAsFixed(3)}s step-start infinite;
              }
              '''
              .dedented;
        }
      }

      if (GENERATE_JS_SVG) {
        jsAnimatedCss += '\n/* stroke $pathid */\n';

        // brush and background hidden by default
        if (showBrush) {
          jsAnimatedCss += '''
              #$brushPathidcss, #$brushBorderPathidcss, #$bgPathidcss {
                  visibility: hidden;
              }
              '''
              .dedented;
        }

        // hide stroke after current element
        const afterCurrent = '[class *= "current"]';
        jsAnimatedCss += '''
            $afterCurrent ~ #$animPathidcss {
                visibility: hidden;
            }
            $afterCurrent ~ #$bgPathidcss, #$bgPathidcss.animate {
                visibility: visible;
            }
            @keyframes strike-$pathname {
                0% { stroke-dashoffset: ${pathlen.toStringAsFixed(3)}; }
                100% { stroke-dashoffset: 0; }
            }
            #$animPathidcss.animate {
                stroke: $strokeFillingColor;
                stroke-dasharray: ${pathlen.toStringAsFixed(3)} ${pathlen.toStringAsFixed(3)};
                visibility: visible;
                animation: strike-$pathname ${relativeDuration.toStringAsFixed(3)}s ${timingFunction.name} forwards 1;
            }
            '''
            .dedented;
        if (showBrush) {
          jsAnimatedCss += '''
            @keyframes strike-brush-$pathname {
                0% { stroke-dashoffset: ${pathlen.toStringAsFixed(3)}; }
                100% { stroke-dashoffset: 0.4; }
            }
            #$brushPathidcss.animate.brush, #$brushBorderPathidcss.animate.brush {
                stroke-dasharray: 0 ${pathlen.toStringAsFixed(3)};
                visibility: visible;
                animation: strike-brush-$pathname ${relativeDuration.toStringAsFixed(3)}s ${timingFunction.name} forwards 1;
            }
            '''
              .dedented;
        }
      }

      if (GENERATE_GIF) {
        for (final k in staticCss.keys) {
          final time = k * GIF_FRAME_DURATION;
          final reltime = time * tottime / animationTime; // unscaled time

          staticCss[k] = staticCss[k]! + '\n/* stroke $pathid */\n';

          String rule = '';

          // animation
          if (reltime < elapsedtime) {
            // just hide everything
            rule += "#$animPathidcss";

            if (showBrush) {
              rule += ", #$brushPathidcss, #$brushBorderPathidcss";
            }

            staticCss[k] = staticCss[k]! +
                '''
                %$rule {
                    visibility: hidden;
                }
                '''
                    .dedented;
          } else if (reltime > newelapsedtime) {
            // just hide the brush, and bg
            rule += "#$bgPathidcss";

            if (showBrush) {
              rule += ", #$brushPathidcss, #$brushBorderPathidcss";
            }

            staticCss[k] = staticCss[k]! +
                '''
                $rule {
                    visibility: hidden;
                }
                '''
                    .dedented;
          } else {
            final intervalprop =
                ((reltime - elapsedtime) / (newelapsedtime - elapsedtime));
            final progression = timingFunction.func(intervalprop);

            staticCss[k] = staticCss[k]! +
                '''
                #$animPathidcss {
                    stroke-dasharray: ${pathlen.toStringAsFixed(3)} ${(pathlen + 0.002).toStringAsFixed(3)};
                    stroke-dashoffset: ${(pathlen * (1 - progression) + 0.0015).toStringAsFixed(4)};
                    stroke: $strokeFillingColor;
                }
                '''
                    .dedented;
            if (showBrush) {
              staticCss[k] = staticCss[k]! +
                  '''
                  #$brushPathidcss, #$brushBorderPathidcss {
                      stroke-dasharray: 0.001 ${(pathlen + 0.002).toStringAsFixed(3)};
                      stroke-dashoffset: ${(pathlen * (1 - progression) + 0.0015).toStringAsFixed(4)};
                  }
                  '''
                      .dedented;
            }
          }
        }
      }

      elapsedlen = newelapsedlen;
      elapsedtime = newelapsedtime;
    }
  }

  void addGroup(XmlDocumentFragment g) =>
      doc.root.firstElementChild?.children.add(g);

  // insert groups
  if (showBrush && !showBrushFrontBorder) addGroup(brushBrdGroup);
  addGroup(bgGroup);
  if (showBrush && showBrushFrontBorder) addGroup(brushBrdGroup);
  addGroup(animGroup);
  if (showBrush) addGroup(brushGroup);

  if (GENERATE_SVG) {
    print(animatedCss);
    final builder = XmlBuilder();
    final style = (builder
          ..element(
            'style',
            attributes: {'id': "style-Kanimaji", 'type': 'text/css'},
            nest: animatedCss,
          ))
        .buildFragment();
    doc.root.firstElementChild!.children.insert(0, style);
    File(outputFile).writeAsStringSync(doc.toXmlString(pretty: true));
    doc.root.children.removeAt(0);
    print('written $outputFile');
  }

  if (GENERATE_GIF) {
    // svgframefiles = []
    // pngframefiles = []
    // svgexport_data = []
    // for k in static_css:
    //     svgframefile = filename_noext_ascii + ("_frame%04d.svg"%k)
    //     pngframefile = filename_noext_ascii + ("_frame%04d.png"%k)
    //     svgframefiles.append(svgframefile)
    //     pngframefiles.append(pngframefile)
    //     svgexport_data.append({"input": [abspath(svgframefile)],
    //                            "output": [[abspath(pngframefile),
    //                                          "%d:%d"% (GIF_SIZE, GIF_SIZE)]]})

    //     style = E.style(static_css[k], id="style-Kanimaji")
    //     doc.getroot().insert(0, style)
    //     doc.write(svgframefile, pretty_print=True)
    //     doc.getroot().remove(style)
    //     print 'written %s' % svgframefile

    // // create json file
    // svgexport_datafile = filename_noext_ascii+"_export_data.json"
    // with open(svgexport_datafile,'w') as f:
    //     f.write(json.dumps(svgexport_data))
    // print 'created instructions %s' % svgexport_datafile

    // // run svgexport
    // cmdline = 'svgexport %s' % shescape(svgexport_datafile)
    // print cmdline
    // if os.system(cmdline) != 0:
    //     exit('Error running external command')

    // if DELETE_TEMPORARY_FILES:
    //     os.remove(svgexport_datafile)
    //     for f in svgframefiles:
    //         os.remove(f)

    // // generate GIF
    // giffile_tmp1 = filename_noext + '_anim_tmp1.gif'
    // giffile_tmp2 = filename_noext + '_anim_tmp2.gif'
    // giffile = filename_noext + '_anim.gif'
    // escpngframefiles = ' '.join(shescape(f) for f in pngframefiles[0:-1])

    // if GIF_BACKGROUND_COLOR == 'transparent':
    //     bgopts = '-dispose previous'
    // else:
    //     bgopts = "-background '%s' -alpha remove" % GIF_BACKGROUND_COLOR
    // cmdline = ("convert -delay %d %s -delay %d %s "+
    //             "%s -layers OptimizePlus %s") % (
    //             int(GIF_FRAME_DURATION*100),
    //             escpngframefiles,
    //             int(last_frame_delay*100),
    //             shescape(pngframefiles[-1]),
    //             bgopts,
    //             shescape(giffile_tmp1))
    // print(cmdline);
    // if os.system(cmdline) != 0:
    //     exit('Error running external command')

    // if DELETE_TEMPORARY_FILES:
    //     for f in pngframefiles:
    //         os.remove(f)
    //     print 'cleaned up.'

    // cmdline = ("convert %s \\( -clone 0--1 -background none "+
    //            "+append -quantize transparent -colors 63 "+
    //            "-unique-colors -write mpr:cmap +delete \\) "+
    //            "-map mpr:cmap %s") % (
    //             shescape(giffile_tmp1),
    //             shescape(giffile_tmp2))
    // print cmdline
    // if os.system(cmdline) != 0:
    //     exit('Error running external command')
    // if DELETE_TEMPORARY_FILES:
    //     os.remove(giffile_tmp1)

    // cmdline = ("gifsicle -O3 %s -o %s") % (
    //             shescape(giffile_tmp2),
    //             shescape(giffile))
    // print cmdline
    // if os.system(cmdline) != 0:
    //     exit('Error running external command')
    // if DELETE_TEMPORARY_FILES:
    //     os.remove(giffile_tmp2)
  }

  // if (GENERATE_JS_SVG) {
  //     final f0insert = [bg_g, anim_g];
  //     if (SHOW_BRUSH) f0insert += [brush_g, brush_brd_g];
  //     for g in f0insert:
  //         el = E.a()
  //         el.set("data-stroke","0")
  //         g.insert(0, el)

  //     for i in range(0, len(js_anim_els)):
  //         els = js_anim_els[i]
  //         for k in els:
  //             els[k].set("data-stroke",str(i+1))
  //         els["anim"].set("data-duration", str(js_anim_time[i]))

  //     doc.getroot().set('data-num-strokes', str(len(js_anim_els)))

  //     style = E.style(js_animated_css, id="style-Kanimaji")
  //     doc.getroot().insert(0, style)
  //     svgfile = filename_noext + '_js_anim.svg'
  //     doc.write(svgfile, pretty_print=True)
  //     doc.getroot().remove(style)
  //     print('written $svgfile');
  // }
}

void main(List<String> args) {
  // createAnimation('assets/kanjivg/kanji/0f9b1.svg');

  const kanji = '情報科学';
  final fileList = [];
  for (int k = 0; k < kanji.length; k++) {
    createAnimation(
      inputFile: 'assets/kanjivg/kanji/${kanji.codeUnits[k].toRadixString(16).padLeft(5, '0')}.svg',
      outputFile: '${k+1}.svg',
    ); 
    fileList.add('${k+1}.svg');
  }

  File('index.html').writeAsStringSync(
    '<html>' +
    fileList.map((e) => File(e).readAsStringSync().replaceAll(']>', '')).join('\n') +
    '</html>'
  );
  // createAnimation(
  //   inputFile: 'assets/kanjivg/kanji/060c5.svg',
  //   outputFile: 'test.svg',
  // );
}
