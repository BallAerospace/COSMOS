/*
# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
*/

#include "ruby.h"
#include "stdio.h"

static ID id_method_greater_than = 0;
static ID id_method_less_than = 0;

/*
 * Returns the maximum value and its index
 */
static VALUE max_with_index (VALUE self)
{
  int index = 0;
  long array_length = RARRAY_LEN(self);
  int maximum_index = 0;
  VALUE value = Qnil;
  VALUE maximum = Qnil;
  VALUE return_value = Qnil;

  if (array_length > 0)
  {
    maximum = rb_ary_entry(self, 0);
    maximum_index = 0;

    for (index = 1; index < array_length; index++)
    {
      value = rb_ary_entry(self, index);

      if (rb_funcall(value, id_method_greater_than, 1, maximum) == Qtrue)
      {
        maximum = value;
        maximum_index = index;
      }
    }
  }

  return_value = rb_ary_new2(2);
  rb_ary_push(return_value, maximum);
  if (NIL_P(maximum))
  {
    rb_ary_push(return_value, Qnil);
  }
  else
  {
    rb_ary_push(return_value, INT2FIX(maximum_index));
  }
  return return_value;
}

/*
 * Returns the minimum value and its index
 */
static VALUE min_with_index (VALUE self)
{
  int index = 0;
  long array_length = RARRAY_LEN(self);
  int minimum_index = 0;
  VALUE value = Qnil;
  VALUE minimum = Qnil;
  VALUE return_value = Qnil;

  if (array_length > 0)
  {
    minimum = rb_ary_entry(self, 0);
    minimum_index = 0;

    for (index = 1; index < array_length; index++)
    {
      value = rb_ary_entry(self, index);

      if (rb_funcall(value, id_method_less_than, 1, minimum) == Qtrue)
      {
        minimum = value;
        minimum_index = index;
      }
    }
  }

  return_value = rb_ary_new2(2);
  rb_ary_push(return_value, minimum);
  if (NIL_P(minimum))
  {
    rb_ary_push(return_value, Qnil);
  }
  else
  {
    rb_ary_push(return_value, INT2FIX(minimum_index));
  }
  return return_value;
}

/*
 * Initialize methods for Array Core Ext
 */
void Init_array (void)
{
  id_method_greater_than = rb_intern(">");
  id_method_less_than = rb_intern("<");

  rb_define_method(rb_cArray,  "max_with_index", max_with_index, 0);
  rb_define_method(rb_cArray,  "min_with_index", min_with_index, 0);
}
