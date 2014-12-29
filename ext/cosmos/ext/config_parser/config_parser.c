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

VALUE mCosmos;
VALUE cConfigParser;

static ID id_cvar_progress_callback = 0;
static ID id_ivar_line_number = 0;
static ID id_ivar_keyword = 0;
static ID id_ivar_parameters = 0;
static ID id_ivar_line = 0;
static ID id_method_readline = 0;
static ID id_method_close = 0;
static ID id_method_pos = 0;
static ID id_method_call = 0;
static ID id_method_scan = 0;
static ID id_method_strip = 0;
static ID id_method_to_s = 0;
static ID id_method_upcase = 0;

/*
 * Removes quotes from the given string if present.
 *
 *   "'quoted string'".remove_quotes #=> "quoted string"
 */
static VALUE string_remove_quotes(VALUE self)
{
  long length = RSTRING_LEN(self);
  char* ptr = RSTRING_PTR(self);
  char first_char = 0;
  char last_char = 0;

  if (length < 2) {
    return self;
  }

  first_char = ptr[0];
  if ((first_char != 34) && (first_char != 39)) {
    return self;
  }

  last_char = ptr[length - 1];
  if (last_char != first_char) {
    return self;
  }

  return rb_str_new(ptr + 1, length - 2);
}

/*
 * Method to read a line from the config file.
 * This is a seperate method so that it can be protected.
 */
static VALUE config_parser_readline(VALUE io)
{
  return rb_funcall(io, id_method_readline, 0);
}

/*
 * Iterates over each line of the io object and yields the keyword and parameters
 */
static VALUE parse_loop(VALUE self, VALUE io, VALUE yield_non_keyword_lines, VALUE remove_quotes, VALUE size, VALUE rx) {
  int line_number = 0;
  int result = 0;
  long length = 0;
  int index = 0;
  double float_pos = 0.0;
  double float_size = NUM2DBL(size);
  VALUE progress_callback = rb_cvar_get(cConfigParser, id_cvar_progress_callback);
  VALUE line = Qnil;
  VALUE data = Qnil;
  VALUE line_continuation = Qfalse;
  VALUE string = Qnil;
  VALUE array = rb_ary_new();
  VALUE first_item = Qnil;
  VALUE ivar_keyword = Qnil;
  VALUE ivar_parameters = rb_ary_new();
  VALUE ivar_line =Qnil;

  rb_ivar_set(self, id_ivar_line_number, INT2FIX(0));
  rb_ivar_set(self, id_ivar_keyword, ivar_keyword);
  rb_ivar_set(self, id_ivar_parameters, ivar_parameters);
  rb_ivar_set(self, id_ivar_line, ivar_line);

  while (1) {
    line_number += 1;
    rb_ivar_set(self, id_ivar_line_number, INT2FIX(line_number));

    if (RTEST(progress_callback) && ((line_number % 10) == 0)) {
      if (float_size > 0.0) {
        float_pos = NUM2DBL(rb_funcall(io, id_method_pos, 0));
        rb_funcall(progress_callback, id_method_call, 1, rb_float_new(float_pos / float_size));
      }
    }

    line = rb_protect(config_parser_readline, io, &result);
    if (result) {
      rb_set_errinfo(Qnil);
      break;
    }
    line = rb_funcall(line, id_method_strip, 0);
    data = rb_funcall(line, id_method_scan, 1, rx);
    first_item = rb_funcall(rb_ary_entry(data, 0), id_method_to_s, 0);

    if (RTEST(line_continuation)) {
      rb_str_concat(ivar_line, line);
      /* Carry over keyword and parameters */
    } else {
      ivar_line = line;
      rb_ivar_set(self, id_ivar_line, ivar_line);
      if ((RSTRING_LEN(first_item) == 0) || (RSTRING_PTR(first_item)[0] == '#')) {
        ivar_keyword = Qnil;
      } else {
        ivar_keyword = rb_funcall(first_item, id_method_upcase, 0);
      }
      rb_ivar_set(self, id_ivar_keyword, ivar_keyword);
      ivar_parameters = rb_ary_new();
      rb_ivar_set(self, id_ivar_parameters, ivar_parameters);
    }

    /* Ignore comments and blank lines */
    if (ivar_keyword == Qnil) {
      if ((RTEST(yield_non_keyword_lines)) && (!(RTEST(line_continuation)))) {
        rb_ary_clear(array);
        rb_ary_push(array, ivar_keyword);
        rb_ary_push(array, ivar_parameters);
        rb_yield(array);
      }
      continue;
    }

    if (RTEST(line_continuation)) {
      if (RTEST(remove_quotes)) {
        rb_ary_push(ivar_parameters, string_remove_quotes(first_item));
      } else {
        rb_ary_push(ivar_parameters, first_item);
      }
      line_continuation = Qfalse;
    }

    length = RARRAY_LEN(data);
    if (length > 1) {
      for (index = 1; index < length; index++) {
        string = rb_ary_entry(data, index);

        /*
            * Don't process trailing comments such as:
            * KEYWORD PARAM #This is a comment
            * But still process Ruby string interpolations such as:
            * KEYWORD PARAM #{var}
            */
        if ((RSTRING_LEN(string) > 0) && (RSTRING_PTR(string)[0] == '#')) {
          if (!((RSTRING_LEN(string) > 1) && (RSTRING_PTR(string)[1] == '{'))) {
            break;
          }
        }

        /*
            * If the string is simply '&' and its the last string then its a line continuation so break the loop
            */
        if ((RSTRING_LEN(string) == 1) && (RSTRING_PTR(string)[0] == '&') && (index == (length - 1))) {
          line_continuation = Qtrue;
          continue;
        }

        line_continuation = Qfalse;
        if (RTEST(remove_quotes)) {
          rb_ary_push(ivar_parameters, string_remove_quotes(string));
        } else {
          rb_ary_push(ivar_parameters, string);
        }
      }
    }

    /*
       * If we detected a line continuation while going through all the
       * strings on the line then we strip off the continuation character and
       * return to the top of the loop to continue processing the line.
       */
    if (RTEST(line_continuation)) {
      /* Strip the continuation character */
      if (RSTRING_LEN(ivar_line) >= 1) {
         ivar_line = rb_str_new(RSTRING_PTR(ivar_line), RSTRING_LEN(ivar_line) - 1);
      } else {
         ivar_line = rb_str_new2("");
      }
      rb_ivar_set(self, id_ivar_line, ivar_line);
      continue;
    }

    rb_ary_clear(array);
    rb_ary_push(array, ivar_keyword);
    rb_ary_push(array, ivar_parameters);
    rb_yield(array);
  }

  if (RTEST(progress_callback)) {
    rb_funcall(progress_callback, id_method_call, 1, rb_float_new(1.0));
  }

  return Qnil;
}

/*
 * Initialize methods for ConfigParser
 */
void Init_config_parser (void)
{
  id_cvar_progress_callback = rb_intern("@@progress_callback");
  id_ivar_line_number = rb_intern("@line_number");
  id_ivar_keyword = rb_intern("@keyword");
  id_ivar_parameters = rb_intern("@parameters");
  id_ivar_line = rb_intern("@line");
  id_method_readline = rb_intern("readline");
  id_method_close = rb_intern("close");
  id_method_pos = rb_intern("pos");
  id_method_call = rb_intern("call");
  id_method_scan = rb_intern("scan");
  id_method_strip = rb_intern("strip");
  id_method_to_s = rb_intern("to_s");
  id_method_upcase = rb_intern("upcase");

  mCosmos = rb_define_module("Cosmos");

  cConfigParser = rb_define_class_under(mCosmos, "ConfigParser", rb_cObject);
  rb_define_method(cConfigParser, "parse_loop", parse_loop, 5);
}
