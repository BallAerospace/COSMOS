/*
# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
*/

#include "ruby.h"
#include "stdio.h"

#ifndef RFLOAT_VALUE
  #define RFLOAT_VALUE(v) (RFLOAT(v)->value)
#endif

/* Cosmos module reference */
VALUE mCosmos = Qnil;

/* LineClip class reference */
VALUE cLineClip = Qnil;

/* Reference to LineGraph class */
VALUE cLineGraph = Qnil;

/* Reference to other needed classes/modules */
static VALUE mQt = Qnil;
static VALUE cQtBase = Qnil;
static VALUE cQtWidget = Qnil;

/* Method Ids */
static ID id_method_to_f = 0;
static ID id_method_left = 0;
static ID id_method_right = 0;
static ID id_method_addLineColor = 0;
static ID id_method_addRectColorFill = 0;

/* Instance Variable Ids */
static ID id_ivar_x_max = 0;
static ID id_ivar_x_min = 0;
static ID id_ivar_x_scale = 0;
static ID id_ivar_graph_left_x = 0;
static ID id_ivar_left_y_max = 0;
static ID id_ivar_left_y_min = 0;
static ID id_ivar_left_y_scale = 0;
static ID id_ivar_right_y_max = 0;
static ID id_ivar_right_y_min = 0;
static ID id_ivar_right_y_scale = 0;
static ID id_ivar_graph_top_y = 0;
static ID id_ivar_lines = 0;
static ID id_ivar_show_lines = 0;
static ID id_ivar_point_size = 0;

/* Constant Ids */
static ID id_LEFT = 0;
static ID id_RIGHT = 0;

/* Enumeration of line position codes */
const long LINE_CLIP_OUTCODES_TOP = 0x1;
const long LINE_CLIP_OUTCODES_BOTTOM = 0x2;
const long LINE_CLIP_OUTCODES_RIGHT = 0x4;
const long LINE_CLIP_OUTCODES_LEFT = 0x8;

/*
 * This is part of the line clipping algorithm.  This function returns
 * a code that indicates where a point is in relation to the viewable area.
 */
static int cal_code (double x, double y, double xmin, double ymin, double xmax, double ymax) {
  int code = 0;

  if (y > ymax) {
    code |= LINE_CLIP_OUTCODES_TOP;
  } else if (y < ymin) {
    code |= LINE_CLIP_OUTCODES_BOTTOM;
  }

  if (x > xmax) {
    code |= LINE_CLIP_OUTCODES_RIGHT;
  } else if (x < xmin) {
    code |= LINE_CLIP_OUTCODES_LEFT;
  }

  return code;
}

/*
 * Internal function to perform clipping
 */
static VALUE line_clip_internal(double x0, double y0, double x1, double y1, double xmin, double ymin, double xmax, double ymax, double* result_x0, double* result_y0, double* result_x1, double* result_y1, volatile VALUE* result_clipped0, volatile VALUE* result_clipped1) {
  int code0 = 0;
  int code1 = 0;
  int codeout = 0;
  volatile VALUE accept = Qfalse;
  volatile VALUE done = Qfalse;
  volatile VALUE clipped0 = Qfalse;
  volatile VALUE clipped1 = Qfalse;
  double x = 0.0;
  double y = 0.0;

  code0 = cal_code(x0, y0, xmin, ymin, xmax, ymax);
  code1 = cal_code(x1, y1, xmin, ymin, xmax, ymax);

  while (1) {
    if ((code0 | code1) == 0) {
      /* Both points are within the viewable area.  The entire line can be
       * graphed. */
      accept = Qtrue;
      done = Qtrue;
    } else if ((code0 & code1) != 0) {
      /* The entire line is outside of the viewable area.  No part of the
       * line can be graphed. */
      accept = Qfalse;
      clipped0 = Qtrue;
      clipped1 = Qtrue;
      done = Qtrue;
    } else {
      /* Part of the line is inside the viewable area.  Figure out which part
       * of the line can be drawn. */
      x = 0.0;
      y = 0.0;

      if (code0 != 0) {
        codeout = code0;
        clipped0 = Qtrue;
      } else {
        codeout = code1;
        clipped1 = Qtrue;
      }

      if ((codeout & LINE_CLIP_OUTCODES_TOP) != 0) {
        x = x0 + (x1 - x0) * (ymax - y0) / (y1 - y0);
        y = ymax;
      } else if ((codeout & LINE_CLIP_OUTCODES_BOTTOM) != 0) {
        x = x0 + (x1 - x0) * (ymin - y0) / (y1 - y0);
        y = ymin;
      } else if ((codeout & LINE_CLIP_OUTCODES_RIGHT) != 0) {
        y = y0 + (y1 - y0) * (xmax - x0) / (x1 - x0);
        x = xmax;
      } else {
        y = y0 + (y1 - y0) * (xmin - x0) / (x1 - x0);
        x = xmin;
      }

      if (codeout == code0) {
        x0 = x;
        y0 = y;
        code0 = cal_code(x0, y0, xmin, ymin, xmax, ymax);
      } else {
        x1 = x;
        y1 = y;
        code1 = cal_code(x1, y1, xmin, ymin, xmax, ymax);
      }
    }

    if (done == Qtrue) {
      break;
    }
  }

  *result_x0 = x0;
  *result_y0 = y0;
  *result_x1 = x1;
  *result_y1 = y1;
  *result_clipped0 = clipped0;
  *result_clipped1 = clipped1;

  return accept;
}

/*
 * This is a line-clipping algorithm.  It takes two points and a viewable
 * area.  It returns the part of the line that is within the viewable area.
 * If no part of the line is viewable, it returns nil
 */
static VALUE line_clip(VALUE self, VALUE x0, VALUE y0, VALUE x1, VALUE y1, VALUE xmin, VALUE ymin, VALUE xmax, VALUE ymax) {
  volatile VALUE result = Qnil;
  volatile VALUE result_clipped0 = Qnil;
  volatile VALUE result_clipped1 = Qnil;
  volatile VALUE return_value = Qnil;
  double double_x0 = 0.0;
  double double_y0 = 0.0;
  double double_x1 = 0.0;
  double double_y1 = 0.0;
  double double_xmin = 0.0;
  double double_ymin = 0.0;
  double double_xmax = 0.0;
  double double_ymax = 0.0;
  double result_x0 = 0.0;
  double result_y0 = 0.0;
  double result_x1 = 0.0;
  double result_y1 = 0.0;

  double_x0 = RFLOAT_VALUE(rb_funcall(x0, id_method_to_f, 0));
  double_y0 = RFLOAT_VALUE(rb_funcall(y0, id_method_to_f, 0));
  double_x1 = RFLOAT_VALUE(rb_funcall(x1, id_method_to_f, 0));
  double_y1 = RFLOAT_VALUE(rb_funcall(y1, id_method_to_f, 0));
  double_xmin = RFLOAT_VALUE(rb_funcall(xmin, id_method_to_f, 0));
  double_ymin = RFLOAT_VALUE(rb_funcall(ymin, id_method_to_f, 0));
  double_xmax = RFLOAT_VALUE(rb_funcall(xmax, id_method_to_f, 0));
  double_ymax = RFLOAT_VALUE(rb_funcall(ymax, id_method_to_f, 0));

  result = line_clip_internal(double_x0, double_y0, double_x1, double_y1, double_xmin, double_ymin, double_xmax, double_ymax, &result_x0, &result_y0, &result_x1, &result_y1, &result_clipped0, &result_clipped1);

  if (result == Qtrue)
  {
    return_value = rb_ary_new2(6);
    rb_ary_push(return_value, rb_float_new(result_x0));
    rb_ary_push(return_value, rb_float_new(result_y0));
    rb_ary_push(return_value, rb_float_new(result_x1));
    rb_ary_push(return_value, rb_float_new(result_y1));
    rb_ary_push(return_value, result_clipped0);
    rb_ary_push(return_value, result_clipped1);
  }

  return return_value;
}

/*
 * rounds a double to the nearest integer
 */
static long round_nearest (double value) {
  return ((long) (value + 0.5));
}

/*
 * scale_value_to_graph_y internal
 */
static long scale_value_to_graph_y_internal (double y, double y_max, double y_scale, long graph_top_y) {
  return (round_nearest((y_max - y) * y_scale) + graph_top_y);
}

/*
 * This function converts a y value to a y coordinate on the graph
 */
static VALUE scale_value_to_graph_y(int argc, VALUE* argv, VALUE self) {
  volatile VALUE y = Qnil;
  ID id_axis = 0;
  long long_graph_top_y = 0;
  double double_y = 0.0;
  double double_y_max = 0.0;
  double double_y_scale = 0.0;

  switch (argc) {
    case 1:
      y = argv[0];
      id_axis = id_LEFT;
      break;
    case 2:
      y = argv[0];
      id_axis = SYM2ID(argv[1]);
      break;
    default:
      /* Invalid number of arguments given */
      rb_raise(rb_eArgError, "wrong number of arguments (%d for 1..2)", argc);
      break;
  };

  long_graph_top_y = FIX2INT(rb_ivar_get(self, id_ivar_graph_top_y));
  double_y = RFLOAT_VALUE(rb_funcall(y, id_method_to_f, 0));

  if (id_axis == id_LEFT) {
    double_y_max = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_left_y_max),   id_method_to_f, 0));
    double_y_scale = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_left_y_scale), id_method_to_f, 0));
  } else /* id_axis == id_RIGHT */ {
    double_y_max = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_right_y_max),   id_method_to_f, 0));
    double_y_scale = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_right_y_scale), id_method_to_f, 0));
  }

  return INT2FIX(scale_value_to_graph_y_internal(double_y, double_y_max, double_y_scale, long_graph_top_y));
}

/*
 * Internal function converts an x value to an x coordinate on the graph
 */
static long scale_value_to_graph_x_internal (double x, double x_min, double x_scale, long graph_left_x) {
  return (round_nearest((x - x_min) * x_scale) + graph_left_x);
}

/*
 * This function converts an x value to an x coordinate on the graph
 */
static VALUE scale_value_to_graph_x(VALUE self, VALUE x) {
  long long_graph_left_x = 0;
  double double_x = 0.0;
  double double_x_min = 0.0;
  double double_x_scale = 0.0;

  long_graph_left_x = FIX2INT(rb_ivar_get(self, id_ivar_graph_left_x));
  double_x = RFLOAT_VALUE(rb_funcall(x, id_method_to_f, 0));
  double_x_min = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_x_min), id_method_to_f, 0));
  double_x_scale = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_x_scale), id_method_to_f, 0));

  return INT2FIX(scale_value_to_graph_x_internal(double_x, double_x_min, double_x_scale, long_graph_left_x));
}

/*
 * Internal version to draw a line
 */
static void draw_line_internal(VALUE dc, double x1, double y1, double x2, double y2, double x_min, double y_min, double x_max, double y_max, double x_scale, double y_scale, long graph_left_x, long graph_top_y, ID id_axis, VALUE show_line, VALUE point_size, VALUE color) {
  volatile VALUE result = Qnil;
  volatile VALUE clipped1 = Qnil;
  volatile VALUE clipped2 = Qnil;
  long x1_scaled = 0;
  long y1_scaled = 0;
  long x2_scaled = 0;
  long y2_scaled = 0;
  double clipped_x1 = 0.0;
  double clipped_y1 = 0.0;
  double clipped_x2 = 0.0;
  double clipped_y2 = 0.0;

  /* Calculate potentially clipped version of line */
  result = line_clip_internal(x1, y1, x2, y2, x_min, y_min, x_max, y_max, &clipped_x1, &clipped_y1, &clipped_x2, &clipped_y2, &clipped1, &clipped2);

  if (result == Qtrue) /* Line is visible so draw it */ {
    /* Scale to graph coordinates */
    x1_scaled = scale_value_to_graph_x_internal(clipped_x1, x_min, x_scale, graph_left_x);
    y1_scaled = scale_value_to_graph_y_internal(clipped_y1, y_max, y_scale, graph_top_y);
    x2_scaled = scale_value_to_graph_x_internal(clipped_x2, x_min, x_scale, graph_left_x);
    y2_scaled = scale_value_to_graph_y_internal(clipped_y2, y_max, y_scale, graph_top_y);

    /* Draw the line */
    if (RTEST(show_line)) {
      rb_funcall(dc, id_method_addLineColor, 5, INT2FIX(x1_scaled), INT2FIX(y1_scaled), INT2FIX(x2_scaled), INT2FIX(y2_scaled), color);
    }

    /* Draw point at line */
    if (FIX2INT(point_size) > 0) {
      /* Only show point if second point wasn't clipped */
      if (!RTEST(clipped2)) {
        rb_funcall(dc, id_method_addRectColorFill, 5, INT2FIX(x2_scaled - 2), INT2FIX(y2_scaled - 2), point_size, point_size, color);
      }
    }
  }
}

/*
 * Draws a line between two points that is clipped to fit the visible graph if necessary
 */
static VALUE draw_line(VALUE self, VALUE dc, VALUE x1, VALUE y1, VALUE x2, VALUE y2, VALUE show_line, VALUE point_size, VALUE axis, VALUE color) {
  long long_graph_left_x = 0;
  long long_graph_top_y = 0;
  ID id_axis = 0;
  double double_x1 = 0.0;
  double double_y1 = 0.0;
  double double_x2 = 0.0;
  double double_y2 = 0.0;
  double double_x_min = 0.0;
  double double_y_min = 0.0;
  double double_x_max = 0.0;
  double double_y_max = 0.0;
  double double_x_scale = 0.0;
  double double_y_scale = 0.0;

  id_axis = SYM2ID(axis);
  double_x_max = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_x_max), id_method_to_f, 0));
  double_x_min = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_x_min), id_method_to_f, 0));
  double_x1 = RFLOAT_VALUE(rb_funcall(x1, id_method_to_f, 0));
  double_y1 = RFLOAT_VALUE(rb_funcall(y1, id_method_to_f, 0));
  double_x2 = RFLOAT_VALUE(rb_funcall(x2, id_method_to_f, 0));
  double_y2 = RFLOAT_VALUE(rb_funcall(y2, id_method_to_f, 0));
  double_x_scale = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_x_scale), id_method_to_f, 0));
  long_graph_left_x = FIX2INT(rb_ivar_get(self, id_ivar_graph_left_x));
  long_graph_top_y = FIX2INT(rb_ivar_get(self, id_ivar_graph_top_y));

  if (id_axis == id_LEFT) {
    double_y_max = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_left_y_max), id_method_to_f, 0));
    double_y_min = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_left_y_min), id_method_to_f, 0));
    double_y_scale = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_left_y_scale), id_method_to_f, 0));
  } else /* id_axis == id_RIGHT */ {
    double_y_max = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_right_y_max), id_method_to_f, 0));
    double_y_min = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_right_y_min), id_method_to_f, 0));
    double_y_scale = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_right_y_scale), id_method_to_f, 0));
  }

  draw_line_internal(dc, double_x1, double_y1, double_x2, double_y2, double_x_min, double_y_min, double_x_max, double_y_max, double_x_scale, double_y_scale, long_graph_left_x, long_graph_top_y, id_axis, show_line, point_size, color);

  return Qnil;
}

/*
 * Draws all lines for the given axis
 */
static VALUE draw_lines (VALUE self, VALUE dc, VALUE axis) {
  long long_graph_left_x = 0;
  long long_graph_top_y = 0;
  long num_lines = 0;
  long line_index = 0;
  long line_length = 0;
  long point_index = 0;
  ID id_axis = 0;
  volatile VALUE lines = Qnil;
  volatile VALUE line = Qnil;
  volatile VALUE x_values = Qnil;
  volatile VALUE y_values = Qnil;
  volatile VALUE color = Qnil;
  volatile VALUE show_lines = Qnil;
  volatile VALUE point_size = Qnil;
  double double_x1 = 0.0;
  double double_y1 = 0.0;
  double double_x2 = 0.0;
  double double_y2 = 0.0;
  double double_x_min = 0.0;
  double double_y_min = 0.0;
  double double_x_max = 0.0;
  double double_y_max = 0.0;
  double double_x_scale = 0.0;
  double double_y_scale = 0.0;

  id_axis = SYM2ID(axis);
  double_x_max = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_x_max), id_method_to_f, 0));
  double_x_min = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_x_min), id_method_to_f, 0));
  double_x_scale = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_x_scale), id_method_to_f, 0));
  long_graph_left_x = FIX2INT(rb_ivar_get(self, id_ivar_graph_left_x));
  long_graph_top_y = FIX2INT(rb_ivar_get(self, id_ivar_graph_top_y));

  if (id_axis == id_LEFT) {
    lines = rb_funcall(rb_ivar_get(self, id_ivar_lines), id_method_left, 0);
    double_y_max = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_left_y_max), id_method_to_f, 0));
    double_y_min = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_left_y_min), id_method_to_f, 0));
    double_y_scale = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_left_y_scale), id_method_to_f, 0));
  } else {
    lines = rb_funcall(rb_ivar_get(self, id_ivar_lines), id_method_right, 0);
    double_y_max = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_right_y_max), id_method_to_f, 0));
    double_y_min = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_right_y_min), id_method_to_f, 0));
    double_y_scale = RFLOAT_VALUE(rb_funcall(rb_ivar_get(self, id_ivar_right_y_scale), id_method_to_f, 0));
  }

  show_lines = rb_ivar_get(self, id_ivar_show_lines);
  point_size = rb_ivar_get(self, id_ivar_point_size);

  num_lines = RARRAY_LEN(lines);
  for (line_index = 0; line_index < num_lines; line_index++) {
    line = rb_ary_entry(lines, line_index);
    x_values = rb_ary_entry(line, 0);
    y_values = rb_ary_entry(line, 1);
    color = rb_ary_entry(line, 6);

    /* Get the first point of the line */
    double_x1 = RFLOAT_VALUE(rb_ary_entry(x_values, 0));
    double_y1 = RFLOAT_VALUE(rb_ary_entry(y_values, 0));

    /* Loop over each data point of the line */
    line_length = RARRAY_LEN(x_values);
    for (point_index = 0; point_index < line_length; point_index++) {
      double_x2 = RFLOAT_VALUE(rb_ary_entry(x_values, point_index));
      double_y2 = RFLOAT_VALUE(rb_ary_entry(y_values, point_index));

      draw_line_internal(dc, double_x1, double_y1, double_x2, double_y2, double_x_min, double_y_min, double_x_max, double_y_max, double_x_scale, double_y_scale, long_graph_left_x, long_graph_top_y, id_axis, show_lines, point_size, color);

      double_x1 = double_x2;
      double_y1 = double_y2;
    }
  }

  return Qnil;
}

/*
 * Initialize methods for C LineGraph
 */
void Init_line_graph (void)
{
  rb_require("cosmos");
  mQt = rb_define_module("Qt");
  cQtBase = rb_define_class_under(mQt, "Base", rb_cObject);
  cQtWidget = rb_define_class_under(mQt, "Widget", cQtBase);

  id_method_left = rb_intern("left");
  id_method_right = rb_intern("right");
  id_method_to_f = rb_intern("to_f");
  id_method_addLineColor = rb_intern("addLineColor");
  id_method_addRectColorFill = rb_intern("addRectColorFill");
  id_ivar_x_max = rb_intern("@x_max");
  id_ivar_x_min = rb_intern("@x_min");
  id_ivar_x_scale = rb_intern("@x_scale");
  id_ivar_graph_left_x = rb_intern("@graph_left_x");
  id_ivar_graph_top_y = rb_intern("@graph_top_y");
  id_ivar_left_y_max = rb_intern("@left_y_max");
  id_ivar_left_y_min = rb_intern("@left_y_min");
  id_ivar_left_y_scale = rb_intern("@left_y_scale");
  id_ivar_right_y_max = rb_intern("@right_y_max");
  id_ivar_right_y_min = rb_intern("@right_y_min");
  id_ivar_right_y_scale = rb_intern("@right_y_scale");
  id_ivar_lines = rb_intern("@lines");
  id_ivar_show_lines = rb_intern("@show_lines");
  id_ivar_point_size = rb_intern("@point_size");
  id_LEFT = rb_intern("LEFT");
  id_RIGHT = rb_intern("RIGHT");

  mCosmos = rb_define_module("Cosmos");
  cLineClip = rb_define_class_under(mCosmos, "LineClip", rb_cObject);
  rb_define_singleton_method(cLineClip, "line_clip", line_clip, 8);

  cLineGraph = rb_define_class_under(mCosmos, "LineGraph", cQtWidget);
  rb_define_method(cLineGraph, "scale_value_to_graph_x", scale_value_to_graph_x,  1);
  rb_define_method(cLineGraph, "scale_value_to_graph_y", scale_value_to_graph_y, -1);
  rb_define_method(cLineGraph, "draw_line", draw_line, 9);
  rb_define_method(cLineGraph, "draw_lines", draw_lines, 2);
}
