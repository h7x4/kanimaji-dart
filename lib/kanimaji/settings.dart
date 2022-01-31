import 'dart:math';

// *_BORDER_WIDTH is the width INCLUDING the border.
const STOKE_BORDER_WIDTH = 4.5;
const STOKE_BORDER_COLOR = "#666";
const STOKE_UNFILLED_COLOR = "#eee";
const double STOKE_UNFILLED_WIDTH = 3;
const STOKE_FILLING_COLOR = "#f00";
const STOKE_FILLED_COLOR = "#000";
const double STOKE_FILLED_WIDTH = 3.1;

// brush settings
const SHOW_BRUSH = true;
const SHOW_BRUSH_FRONT_BORDER = true;
const BRUSH_COLOR = "#f00";
const double BRUSH_WIDTH = 5.5;
const BRUSH_BORDER_COLOR = "#666";
const double BRUSH_BORDER_WIDTH = 7;

const WAIT_AFTER = 1.5;

// gif settings
const DELETE_TEMPORARY_FILES = false;
const GIF_SIZE = 150;
const GIF_FRAME_DURATION = 0.04;
const GIF_BACKGROUND_COLOR = '#ddf';
// set to true to allow transparent background, much bigger file!
const GIF_ALLOW_TRANSPARENT = false;

// edit here to decide what will be generated
const GENERATE_SVG = true;
const GENERATE_JS_SVG = true;
const GENERATE_GIF = true;

// sqrt, ie a stroke 4 times the length is drawn
// at twice the speed, in twice the time.
double stroke_length_to_duration(double length) => sqrt(length) / 8;

// global time rescale, let's make animation a bit
// faster when there are many strokes.
double time_rescale(interval) => pow(2 * interval, 2.0 / 3).toDouble();

// Possibilities are linear, ease, ease-in, ease-in-out, ease-out, see
//   https://developer.mozilla.org/en-US/docs/Web/CSS/timing-function
// for more info.
const TIMING_FUNCTION = "ease-in-out";

//
// colorful debug settings
//
// STOKE_BORDER_COLOR   = "#00f"
// STOKE_UNFILLED_COLOR = "#ff0"
// STOKE_FILLING_COLOR  = "#f00"
// STOKE_FILLED_COLOR   = "#000"
// BRUSH_COLOR = "#0ff"
// BRUSH_BORDER_COLOR = "#0f0"