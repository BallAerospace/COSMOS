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

#include "../structure/structure.c"

static VALUE cPacket = Qnil;
static VALUE cPacketItem = Qnil;

static ID id_method_class = 0;
static ID id_method_target_name_equals = 0;
static ID id_method_packet_name_equals = 0;
static ID id_method_description_equals = 0;
static ID id_method_upcase = 0;
static ID id_method_clone = 0;
static ID id_method_clear = 0;

static ID id_ivar_id_items = 0;
static ID id_ivar_received_time = 0;
static ID id_ivar_received_count = 0;
static ID id_ivar_hazardous = 0;
static ID id_ivar_hazardous_description = 0;
static ID id_ivar_given_values = 0;
static ID id_ivar_limits_items = 0;
static ID id_ivar_processors = 0;
static ID id_ivar_stale = 0;
static ID id_ivar_limits_change_callback = 0;
static ID id_ivar_read_conversion_cache = 0;
static ID id_ivar_raw = 0;
static ID id_ivar_messages_disabled = 0;
static ID id_ivar_meta = 0;
static ID id_ivar_hidden = 0;
static ID id_ivar_disabled = 0;
static ID id_ivar_target_name = 0;
static ID id_ivar_packet_name = 0;
static ID id_ivar_description = 0;
static ID id_ivar_stored = 0;
static ID id_ivar_extra = 0;

/* Sets the target name this packet is associated with. Unidentified packets
 * will have target name set to nil.
 *
 * @param target_name [String] Name of the target this packet is associated with */
static VALUE target_name_equals(VALUE self, VALUE target_name) {
  if (RTEST(target_name)) {
    if (rb_funcall(target_name, id_method_class, 0) != rb_cString) {
      rb_raise(rb_eArgError, "target_name must be a String but is a %s", RSTRING_PTR(rb_funcall(rb_funcall(target_name, id_method_class, 0), id_method_to_s, 0)));
    }
    rb_ivar_set(self, id_ivar_target_name, rb_funcall(rb_funcall(target_name, id_method_upcase, 0), id_method_freeze, 0));
  } else {
    rb_ivar_set(self, id_ivar_target_name, Qnil);
  }
  return rb_ivar_get(self, id_ivar_target_name);
}

/* Sets the packet name. Unidentified packets will have packet name set to
 * nil.
 *
 * @param packet_name [String] Name of the packet */
static VALUE packet_name_equals(VALUE self, VALUE packet_name) {
  if (RTEST(packet_name)) {
    if (rb_funcall(packet_name, id_method_class, 0) != rb_cString) {
      rb_raise(rb_eArgError, "packet_name must be a String but is a %s", RSTRING_PTR(rb_funcall(rb_funcall(packet_name, id_method_class, 0), id_method_to_s, 0)));
    }
    rb_ivar_set(self, id_ivar_packet_name, rb_funcall(rb_funcall(packet_name, id_method_upcase, 0), id_method_freeze, 0));
  } else {
    rb_ivar_set(self, id_ivar_packet_name, Qnil);
  }
  return rb_ivar_get(self, id_ivar_packet_name);
}

/* Sets the description of the packet
 *
 * @param description [String] Description of the packet */
static VALUE description_equals(VALUE self, VALUE description) {
  if (RTEST(description)) {
    if (rb_funcall(description, id_method_class, 0) != rb_cString) {
      rb_raise(rb_eArgError, "description must be a String but is a %s", RSTRING_PTR(rb_funcall(rb_funcall(description, id_method_class, 0), id_method_to_s, 0)));
    }
    rb_ivar_set(self, id_ivar_description, rb_funcall(rb_funcall(description, id_method_clone, 0), id_method_freeze, 0));
  } else {
    rb_ivar_set(self, id_ivar_description, Qnil);
  }
  return rb_ivar_get(self, id_ivar_description);
}

/* Sets the received time of the packet
 *
 * @param received_time [Time] Time this packet was received */
static VALUE received_time_equals(VALUE self, VALUE received_time) {
  volatile VALUE read_conversion_cache = rb_ivar_get(self, id_ivar_read_conversion_cache);
  if (RTEST(received_time)) {
    if (rb_funcall(received_time, id_method_class, 0) != rb_cTime) {
      rb_raise(rb_eArgError, "received_time must be a Time but is a %s", RSTRING_PTR(rb_funcall(rb_funcall(received_time, id_method_class, 0), id_method_to_s, 0)));
    }
    rb_ivar_set(self, id_ivar_received_time, rb_funcall(rb_funcall(received_time, id_method_clone, 0), id_method_freeze, 0));
  } else {
    rb_ivar_set(self, id_ivar_received_time, Qnil);
  }
  if (RTEST(read_conversion_cache)) {
    rb_funcall(read_conversion_cache, id_method_clear, 0);
  }
  return rb_ivar_get(self, id_ivar_received_time);
}

/* Sets the received count of the packet
 *
 * @param received_count [Integer] Number of times this packet has been
 *   received */
static VALUE received_count_equals(VALUE self, VALUE received_count) {
  volatile VALUE read_conversion_cache = rb_ivar_get(self, id_ivar_read_conversion_cache);
#ifdef RUBY_INTEGER_UNIFICATION /* Ruby 2.4.0 unified Fixnum and Bignum into Integer. This check allows the code to build pre- and post-2.4.0. */
  if (rb_funcall(received_count, id_method_class, 0) != rb_cInteger) {
    rb_raise(rb_eArgError, "received_count must be an Integer but is a %s", RSTRING_PTR(rb_funcall(rb_funcall(received_count, id_method_class, 0), id_method_to_s, 0)));
  }
#else
  if ((rb_funcall(received_count, id_method_class, 0) != rb_cFixnum) && (rb_funcall(received_count, id_method_class, 0) != rb_cBignum)) {
    rb_raise(rb_eArgError, "received_count must be an Integer but is a %s", RSTRING_PTR(rb_funcall(rb_funcall(received_count, id_method_class, 0), id_method_to_s, 0)));
  }
#endif
  rb_ivar_set(self, id_ivar_received_count, received_count);
  if (RTEST(read_conversion_cache)) {
    rb_funcall(read_conversion_cache, id_method_clear, 0);
  }
  return rb_ivar_get(self, id_ivar_received_count);
}

/* Creates a new packet by initalizing the attributes.
 *
 * @param target_name [String] Name of the target this packet is associated with
 * @param packet_name [String] Name of the packet
 * @param default_endianness [Symbol] One of {BinaryAccessor::ENDIANNESS}
 * @param description [String] Description of the packet
 * @param buffer [String] String buffer to hold the packet data
 * @param item_class [Class] Class used to instantiate items (Must be a
 *   subclass of PacketItem)
 */
static VALUE packet_initialize(int argc, VALUE* argv, VALUE self) {
  volatile VALUE target_name = Qnil;
  volatile VALUE packet_name = Qnil;
  volatile VALUE default_endianness = Qnil;
  volatile VALUE description = Qnil;
  volatile VALUE buffer = Qnil;
  volatile VALUE item_class = Qnil;
  volatile VALUE super_args[3] = {Qnil, Qnil, Qnil};

  switch (argc)
  {
    case 2:
      target_name = argv[0];
      packet_name = argv[1];
      default_endianness = symbol_BIG_ENDIAN;
      description = Qnil;
      buffer = rb_str_new2("");
      item_class = cPacketItem;
      break;
    case 3:
      target_name = argv[0];
      packet_name = argv[1];
      default_endianness = argv[2];
      description = Qnil;
      buffer = rb_str_new2("");
      item_class = cPacketItem;
      break;
    case 4:
      target_name = argv[0];
      packet_name = argv[1];
      default_endianness = argv[2];
      description = argv[3];
      buffer = rb_str_new2("");
      item_class = cPacketItem;
      break;
    case 5:
      target_name = argv[0];
      packet_name = argv[1];
      default_endianness = argv[2];
      description = argv[3];
      buffer = argv[4];
      item_class = cPacketItem;
      break;
    case 6:
      target_name = argv[0];
      packet_name = argv[1];
      default_endianness = argv[2];
      description = argv[3];
      buffer = argv[4];
      item_class = argv[5];
      break;
    default:
      /* Invalid number of arguments given */
      rb_raise(rb_eArgError, "wrong number of arguments (%d for 2..6)", argc);
      break;
  };

  super_args[0] = default_endianness;
  super_args[1] = buffer;
  super_args[2] = item_class;
  rb_call_super(3, (VALUE*) super_args);
  target_name_equals(self, target_name);
  packet_name_equals(self, packet_name);
  description_equals(self, description);
  rb_ivar_set(self, id_ivar_received_time, Qnil);
  rb_ivar_set(self, id_ivar_received_count, INT2FIX(0));
  rb_ivar_set(self, id_ivar_id_items, Qnil);
  rb_ivar_set(self, id_ivar_hazardous, Qfalse);
  rb_ivar_set(self, id_ivar_hazardous_description, Qnil);
  rb_ivar_set(self, id_ivar_given_values, Qnil);
  rb_ivar_set(self, id_ivar_limits_items, Qnil);
  rb_ivar_set(self, id_ivar_processors, Qnil);
  rb_ivar_set(self, id_ivar_stale, Qtrue);
  rb_ivar_set(self, id_ivar_limits_change_callback, Qnil);
  rb_ivar_set(self, id_ivar_read_conversion_cache, Qnil);
  rb_ivar_set(self, id_ivar_raw, Qnil);
  rb_ivar_set(self, id_ivar_messages_disabled, Qfalse);
  rb_ivar_set(self, id_ivar_meta, Qnil);
  rb_ivar_set(self, id_ivar_hidden, Qfalse);
  rb_ivar_set(self, id_ivar_disabled, Qfalse);
  rb_ivar_set(self, id_ivar_stored, Qfalse);
  rb_ivar_set(self, id_ivar_extra, Qnil);

  return self;
}

/*
 * Initialize all Packet methods
 */
void Init_packet (void)
{
  Init_structure();

  id_method_class = rb_intern("class");
  id_method_target_name_equals = rb_intern("target_name=");
  id_method_packet_name_equals = rb_intern("packet_name=");
  id_method_description_equals = rb_intern("description=");
  id_method_upcase = rb_intern("upcase");
  id_method_clone = rb_intern("clone");
  id_method_clear = rb_intern("clear");

  id_ivar_id_items = rb_intern("@id_items");
  id_ivar_received_time = rb_intern("@received_time");
  id_ivar_received_count = rb_intern("@received_count");
  id_ivar_hazardous = rb_intern("@hazardous");
  id_ivar_hazardous_description = rb_intern("@hazardous_description");
  id_ivar_given_values = rb_intern("@given_values");
  id_ivar_limits_items = rb_intern("@limits_items");
  id_ivar_processors = rb_intern("@processors");
  id_ivar_stale = rb_intern("@stale");
  id_ivar_limits_change_callback = rb_intern("@limits_change_callback");
  id_ivar_read_conversion_cache = rb_intern("@read_conversion_cache");
  id_ivar_raw = rb_intern("@raw");
  id_ivar_messages_disabled = rb_intern("@messages_disabled");
  id_ivar_meta = rb_intern("@meta");
  id_ivar_hidden = rb_intern("@hidden");
  id_ivar_disabled = rb_intern("@disabled");
  id_ivar_target_name = rb_intern("@target_name");
  id_ivar_packet_name = rb_intern("@packet_name");
  id_ivar_description = rb_intern("@description");
  id_ivar_stored = rb_intern("@stored");
  id_ivar_extra = rb_intern("@extra");

  cPacket = rb_define_class_under(mCosmos, "Packet", cStructure);
  rb_define_method(cPacket, "initialize", packet_initialize, -1);
  rb_define_method(cPacket, "packet_name=", packet_name_equals, 1);
  rb_define_method(cPacket, "target_name=", target_name_equals, 1);
  rb_define_method(cPacket, "description=", description_equals, 1);
  rb_define_method(cPacket, "received_time=", received_time_equals, 1);
  rb_define_method(cPacket, "received_count=", received_count_equals, 1);

  cPacketItem = rb_define_class_under(mCosmos, "PacketItem", cStructureItem);
}
