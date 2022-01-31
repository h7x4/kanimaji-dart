/// ignore_for_file: non_constant_identifier_names, avoid_print, unused_local_variable, dead_code, constant_identifier_names

import 'dart:io';
import 'dart:math' show min;

import '../svg/parser.dart';

import 'bezier_cubic.dart' as bezier_cubic;
import 'settings.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart';

double computePathLength(String path) =>
    parse_path(path).size(error: 1e-8).toDouble();

String shescape(path) => "'${path.replace(RegExp(r"(?=['\\\\])"), "\\\\")}'";

String dedent(String s) {
  final withoutEmptyLines =
      s.split('\n').where((l) => l.isNotEmpty).toList();
  final whitespaceAmounts = [
    for (final line in withoutEmptyLines)
      line.split('').takeWhile((c) => c == ' ').length
  ];
  final whitespaceToRemove = whitespaceAmounts.reduce(min);
  return withoutEmptyLines.map((l) => l.replaceRange(0, whitespaceToRemove, '')).join('\n');
}

// ease, ease-in, etc:
// https://developer.mozilla.org/en-US/docs/Web/CSS/timing-function#ease
const pt1 = bezier_cubic.Point(0, 0);
const easeCt1 = bezier_cubic.Point(0.25, 0.1);
const easeCt2 = bezier_cubic.Point(0.25, 1.0);
const easeInCt1 = bezier_cubic.Point(0.42, 0.0);
const easeInCt2 = bezier_cubic.Point(1.0, 1.0);
const easeInOutCt1 = bezier_cubic.Point(0.42, 0.0);
const easeInOutCt2 = bezier_cubic.Point(0.58, 1.0);
const easeOutCt1 = bezier_cubic.Point(0.0, 0.0);
const easeOutCt2 = bezier_cubic.Point(0.58, 1.0);
const pt2 = bezier_cubic.Point(1, 1);

double linear(x) => x;
double ease(x) => bezier_cubic.value(pt1, easeCt1, easeCt2, pt2, x);
double easeIn(x) => bezier_cubic.value(pt1, easeInCt1, easeInCt2, pt2, x);
double easeInOut(x) =>
    bezier_cubic.value(pt1, easeInOutCt1, easeInOutCt2, pt2, x);
double easeOut(x) => bezier_cubic.value(pt1, easeOutCt1, easeOutCt2, pt2, x);

const Map<String, double Function(double)> timingFunctions = {
  'linear': linear,
  'ease': ease,
  'ease-in': easeIn,
  'ease-in-out': easeInOut,
  'ease-out': easeOut
};

final myTimingFunction = timingFunctions[TIMING_FUNCTION]!;

// we will need this to deal with svg
const namespaces = {
  'n': 'http://www.w3.org/2000/svg',
  'xlink': 'http://www.w3.org/1999/xlink'
};
// etree.register_namespace("xlink","http://www.w3.org/1999/xlink")
// final parser = etree.XMLParser(remove_blank_text=true);

void createAnimation(String filename) {
  print('processing $filename');
  final String filenameNoext = filename.replaceAll(RegExp(r'\.[^\.]+$'), '');
  final String baseid = basename(filenameNoext);

  // load xml
  final XmlDocument doc = XmlDocument.parse(File(filename).readAsStringSync());

  // for xlink namespace introduction
  doc.rootElement.setAttribute('xmlns:xlink', namespaces['xlink']);
  doc.rootElement.setAttribute('xlink:used', '');

  // clear all extra elements this program may have previously added
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

  // create groups with a copies (references actually) of the paths
  XmlDocumentFragment pathCopyGroup(
      {required String id, required String color, required double width}) {
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
    color: STOKE_UNFILLED_COLOR,
    width: STOKE_UNFILLED_WIDTH,
  );
  final animGroup = pathCopyGroup(
    id: 'anim',
    color: STOKE_FILLED_COLOR,
    width: STOKE_FILLED_WIDTH,
  );

  late final XmlDocumentFragment brushGroup;
  late final XmlDocumentFragment brushBrdGroup;
  if (SHOW_BRUSH) {
    brushGroup = pathCopyGroup(
      id: 'brush',
      color: BRUSH_COLOR,
      width: BRUSH_WIDTH,
    );
    brushBrdGroup = pathCopyGroup(
      id: 'brush-brd',
      color: BRUSH_BORDER_COLOR,
      width: BRUSH_BORDER_WIDTH,
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
      final pathlen = computePathLength(p.getAttribute('d')!);
      final duration = stroke_length_to_duration(pathlen);
      totlen += pathlen;
      tottime += duration;
    }
  }

  double animationTime = time_rescale(tottime); // math.pow(3 * tottime, 2.0/3)
  tottime += WAIT_AFTER * tottime / animationTime;
  final double actualAnimationTime = animationTime;
  animationTime += WAIT_AFTER;

  final Map<int, String> staticCss = {};
  late String animatedCss;
  final jsAnimationElements = []; // collect the ids of animating elements
  final jsAnimationTimes = []; // the time set (as default) for each animation

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
  if (GENERATE_GIF) {
    // final static_css = {};
    final last_frame_index = actualAnimationTime ~/ GIF_FRAME_DURATION + 1;
    for (int i = 0; i < last_frame_index + 1; i++) {
      staticCss[i] = cssHeader;
    }
    final last_frame_delay =
        animationTime - last_frame_index * GIF_FRAME_DURATION;
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
      final String rule = dedent('''
          #${groupid.replaceAll(':', '\\3a ')} {
              display: none;
          }
          ''');
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
    final rule = dedent('''
        #$gidcss {
            stroke-width: ${STOKE_BORDER_WIDTH.toStringAsFixed(1)}px !important;
            stroke:       $STOKE_BORDER_COLOR !important;
        }
        ''');

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

      if (GENERATE_JS_SVG) jsAnimationElements.add({});

      void addHref(String suffix, XmlDocumentFragment element) {
        final builder = XmlBuilder();
        builder.element(
          'use',
          attributes: {'id': '$pathid-$suffix', 'xlink:href': '#$pathid'},
        );
        final ref = builder.buildFragment();
        element.firstElementChild!.children.add(ref);
        if (GENERATE_JS_SVG) jsAnimationElements.last[suffix] = ref;
      }

      final String bgPathidcss = '$pathidcss-bg';
      final String animPathidcss = '$pathidcss-anim';
      final String brushPathidcss = '$pathidcss-brush';
      final String brushBrdPathidcss = '$pathidcss-brush-brd';

      addHref('bg', bgGroup);
      addHref('anim', animGroup);

      if (SHOW_BRUSH) {
        addHref('brush', brushGroup);
        addHref('brush-brd', brushBrdGroup);
      }

      final pathname = pathid.replaceAll(RegExp(r'^kvg:'), '');
      final pathlen = computePathLength(p.getAttribute('d') as String);
      final duration = stroke_length_to_duration(pathlen);
      final relduration = duration * tottime / animationTime; // unscaled time

      if (GENERATE_JS_SVG) {
        jsAnimationTimes.add(relduration);
      }

      final newelapsedlen = elapsedlen + pathlen;
      final newelapsedtime = elapsedtime + duration;
      final animStart = elapsedtime / tottime * 100;
      final animEnd = newelapsedtime / tottime * 100;

      if (GENERATE_SVG) {
        // animation stroke progression
        animatedCss += dedent('''
            @keyframes strike-$pathname {
                0% { stroke-dashoffset: ${pathlen.toStringAsFixed(3)}; }
                ${animStart.toStringAsFixed(3)}% { stroke-dashoffset: ${pathlen.toStringAsFixed(3)}; }
                ${animEnd.toStringAsFixed(3)}% { stroke-dashoffset: 0; }
                100% { stroke-dashoffset: 0; }
            }
            @keyframes showhide-$pathname {
                ${animStart.toStringAsFixed(3)}% { visibility: hidden; }
                ${animEnd.toStringAsFixed(3)}% { stroke: $STOKE_FILLING_COLOR; }
            }
            #$animPathidcss {
                stroke-dasharray: ${pathlen.toStringAsFixed(3)} ${pathlen.toStringAsFixed(3)};
                stroke-dashoffset: 0;
                animation: strike-$pathname ${animationTime.toStringAsFixed(3)}s $TIMING_FUNCTION infinite,
                    showhide-$pathname ${animationTime.toStringAsFixed(3)}s step-start infinite;
            }
            ''');

        if (SHOW_BRUSH) {
          // brush element visibility
          animatedCss += dedent('''
              @keyframes showhide-brush-$pathname {
                  ${animStart.toStringAsFixed(3)}% { visibility: hidden; }
                  ${animEnd.toStringAsFixed(3)}% { visibility: visible; }
                  100% { visibility: hidden; }
              }
              #$brushPathidcss, #$brushBrdPathidcss {
                  stroke-dasharray: 0 ${pathlen.toStringAsFixed(3)};
                  animation: strike-$pathname ${animationTime.toStringAsFixed(3)}s $TIMING_FUNCTION infinite,
                      showhide-brush-$pathname ${animationTime.toStringAsFixed(3)}s step-start infinite;
              }
              ''');
        }
      }

      if (GENERATE_JS_SVG) {
        jsAnimatedCss += '\n/* stroke $pathid */';

        // brush and background hidden by default
        if (SHOW_BRUSH) {
          jsAnimatedCss += dedent('''
              #$brushPathidcss, #$brushBrdPathidcss, #$bgPathidcss {
                  visibility: hidden;
              }
              ''');
        }

        // hide stroke after current element
        const after_curr = '[class *= "current"]';
        jsAnimatedCss += dedent('''
            $after_curr ~ #$animPathidcss {
                visibility: hidden;
            }
            $after_curr ~ #$bgPathidcss, #$bgPathidcss.animate {
                visibility: visible;
            }
            @keyframes strike-$pathname {
                0% { stroke-dashoffset: ${pathlen.toStringAsFixed(3)}; }
                100% { stroke-dashoffset: 0; }
            }
            #$animPathidcss.animate {
                stroke: $STOKE_FILLING_COLOR;
                stroke-dasharray: ${pathlen.toStringAsFixed(3)} ${pathlen.toStringAsFixed(3)};
                visibility: visible;
                animation: strike-$pathname ${relduration.toStringAsFixed(3)}s $TIMING_FUNCTION forwards 1;
            }
            ''');
        if (SHOW_BRUSH) {
          jsAnimatedCss += dedent('''
            @keyframes strike-brush-$pathname {
                0% { stroke-dashoffset: ${pathlen.toStringAsFixed(3)}; }
                100% { stroke-dashoffset: 0.4; }
            }
            #$brushPathidcss.animate.brush, #$brushBrdPathidcss.animate.brush {
                stroke-dasharray: 0 ${pathlen.toStringAsFixed(3)};
                visibility: visible;
                animation: strike-brush-$pathname ${relduration.toStringAsFixed(3)}s $TIMING_FUNCTION forwards 1;
            }
            ''');
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

            if (SHOW_BRUSH) {
              rule += ", #$brushPathidcss, #$brushBrdPathidcss";
            }

            staticCss[k] = staticCss[k]! +
                dedent('''
                %$rule {
                    visibility: hidden;
                }
                ''');
          } else if (reltime > newelapsedtime) {
            // just hide the brush, and bg
            rule += "#$bgPathidcss";

            if (SHOW_BRUSH) {
              rule += ", #$brushPathidcss, #$brushBrdPathidcss";
            }

            staticCss[k] = staticCss[k]! +
                dedent('''
                $rule {
                    visibility: hidden;
                }
                ''');
          } else {
            final intervalprop =
                ((reltime - elapsedtime) / (newelapsedtime - elapsedtime));
            final progression = myTimingFunction(intervalprop);

            staticCss[k] = staticCss[k]! +
                dedent('''
                #$animPathidcss {
                    stroke-dasharray: ${pathlen.toStringAsFixed(3)} ${(pathlen + 0.002).toStringAsFixed(3)};
                    stroke-dashoffset: ${(pathlen * (1 - progression) + 0.0015).toStringAsFixed(4)};
                    stroke: $STOKE_FILLING_COLOR;
                }
                ''');
            if (SHOW_BRUSH) {
              staticCss[k] = staticCss[k]! +
                  dedent('''
                  #$brushPathidcss, #$brushBrdPathidcss {
                      stroke-dasharray: 0.001 ${(pathlen + 0.002).toStringAsFixed(3)};
                      stroke-dashoffset: ${(pathlen * (1 - progression) + 0.0015).toStringAsFixed(4)};
                  }
                  ''');
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
  if (SHOW_BRUSH && !SHOW_BRUSH_FRONT_BORDER) addGroup(brushBrdGroup);
  addGroup(bgGroup);
  if (SHOW_BRUSH && SHOW_BRUSH_FRONT_BORDER) addGroup(brushBrdGroup);
  addGroup(animGroup);
  if (SHOW_BRUSH) addGroup(brushGroup);

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
    final svgfile = '${filenameNoext}_anim.svg';
    File(svgfile).writeAsStringSync(doc.toXmlString(pretty: true));
    doc.root.children.removeAt(0);
    print('written $svgfile');
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
  if (!timingFunctions.keys.contains(TIMING_FUNCTION)) {
    throw 'Sorry, invalid timing function "$TIMING_FUNCTION"';
  }
  // createAnimation('assets/kanjivg/kanji/0f9b1.svg');
  createAnimation('assets/kanjivg/kanji/04f5c.svg');
}
