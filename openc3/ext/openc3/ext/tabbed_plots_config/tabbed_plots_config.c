/*
# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
*/

/*
# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved
*/

#include "ruby.h"
#include "stdio.h"

VALUE mOpenC3;
VALUE cTabbedPlotsConfig;

static ID id_method_process_packet = 0;

/*
 * Optimization method to move each call to C code
 */
static VALUE process_packet_in_each_data_object(VALUE self, VALUE data_objects, VALUE packet, VALUE packet_count)
{
  int index = 0;
  long length = 0;
  volatile VALUE data_object = Qnil;

  length = RARRAY_LEN(data_objects);
  if (length > 0)
  {
    for (index = 0; index < length; index++)
    {
      data_object = rb_ary_entry(data_objects, index);
      rb_funcall(data_object, id_method_process_packet, 2, packet, packet_count);
    }
  }

  return Qnil;
}

/*
 * Initialize methods for TabbedPlotsConfig
 */
void Init_tabbed_plots_config(void)
{
  id_method_process_packet = rb_intern("process_packet");

  mOpenC3 = rb_define_module("OpenC3");
  cTabbedPlotsConfig = rb_define_class_under(mOpenC3, "TabbedPlotsConfig", rb_cObject);
  rb_define_method(cTabbedPlotsConfig, "process_packet_in_each_data_object", process_packet_in_each_data_object, 3);
}
