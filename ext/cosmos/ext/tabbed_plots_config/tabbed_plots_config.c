/*
# Copyright 2021 Ball Aerospace & Technologies Corp.
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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
*/

#include "ruby.h"
#include "stdio.h"

VALUE mCosmos;
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

  mCosmos = rb_define_module("Cosmos");
  cTabbedPlotsConfig = rb_define_class_under(mCosmos, "TabbedPlotsConfig", rb_cObject);
  rb_define_method(cTabbedPlotsConfig, "process_packet_in_each_data_object", process_packet_in_each_data_object, 3);
}
