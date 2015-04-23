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
VALUE cTelemetry;
VALUE cSystem;

static ID id_ivar_config = 0;
static ID id_method_telemetry = 0;
static ID id_method_read = 0;
static ID id_method_to_s = 0;
static ID id_method_intern = 0;
static ID id_method_get_item = 0;
static ID id_method_upcase = 0;
static ID id_method_newest_packet = 0;
static ID id_method_limits = 0;
static ID id_method_state = 0;
static ID id_method_limits_set = 0;
static ID id_method_values = 0;
static VALUE symbol_CONVERTED = Qnil;

/*
 * @param target_name [String] The target name
 *@return [Hash<packet_name=>Packet>] Hash of the telemetry packets for the given
 *  target name keyed by the packet name
 */
static VALUE packets(VALUE self, VALUE target_name) {
  VALUE target_packets = Qnil;
  VALUE upcase_target_name = Qnil;
  VALUE telemetry = Qnil;

  upcase_target_name = rb_funcall(target_name, id_method_to_s, 0);
  upcase_target_name = rb_funcall(upcase_target_name, id_method_upcase, 0);
  telemetry = rb_funcall(rb_ivar_get(self, id_ivar_config), id_method_telemetry, 0);
  target_packets = rb_hash_aref(telemetry, upcase_target_name);

  if (!(RTEST(target_packets))) {
    rb_raise(rb_eRuntimeError, "Telemetry target '%s' does not exist", RSTRING_PTR(upcase_target_name));
  }

  return target_packets;
}

/*
 * @param target_name [String] The target name
 * @param packet_name [String] The packet name. Must be a defined packet name
 *   and not 'LATEST'.
 *@return [Packet] The telemetry packet for the given target and packet name
 */
static VALUE packet(VALUE self, VALUE target_name, VALUE packet_name)
{
  VALUE packet = Qnil;
  VALUE target_packets = Qnil;
  VALUE upcase_target_name = Qnil;
  VALUE upcase_packet_name = Qnil;

  target_packets = packets(self, target_name);

  upcase_packet_name = rb_funcall(packet_name, id_method_to_s, 0);
  upcase_packet_name = rb_funcall(upcase_packet_name, id_method_upcase, 0);
  packet = rb_hash_aref(target_packets, upcase_packet_name);
  if (!(RTEST(packet))) {
    upcase_target_name = rb_funcall(target_name, id_method_to_s, 0);
    upcase_target_name = rb_funcall(upcase_target_name, id_method_upcase, 0);
    rb_raise(rb_eRuntimeError, "Telemetry packet '%s %s' does not exist", RSTRING_PTR(upcase_target_name), RSTRING_PTR(upcase_packet_name));
  }

  return packet;
}

/*
 * @param target_name (see #packet)
 * @param packet_name [String] The packet name. 'LATEST' can also be given
 *    to specify the last received (or defined if no packets have been
 *    received) packet within the given target that contains the
 *    item_name.
 * @param item_name [String] The item name
 * @return [Packet, PacketItem] The packet and the packet item
 */
static VALUE packet_and_item(VALUE self, VALUE target_name, VALUE packet_name, VALUE item_name)
{
  VALUE upcase_packet_name = Qnil;
  VALUE return_packet = Qnil;
  VALUE item = Qnil;
  VALUE return_value = Qnil;
  char * string_packet_name = NULL;

  upcase_packet_name = rb_funcall(packet_name, id_method_upcase, 0);
  string_packet_name = RSTRING_PTR(upcase_packet_name);
  if (strcmp(string_packet_name, "LATEST") == 0)
  {
    return_packet = rb_funcall(self, id_method_newest_packet, 2, target_name, item_name);
  }
  else
  {
    return_packet = packet(self, target_name, packet_name);
  }

  item = rb_funcall(return_packet, id_method_get_item, 1, item_name);

  return_value = rb_ary_new();
  rb_ary_push(return_value, return_packet);
  rb_ary_push(return_value, item);
  return return_value;
}

/*
 * Return a telemetry value from a packet.
 *
 * @param target_name (see #packet_and_item)
 * @param packet_name (see #packet_and_item)
 * @param item_name (see #packet_and_item)
 * @param value_type [Symbol] How to convert the item before returning.
 * Must be one of {Packet::VALUE_TYPES}
 * @return The value. :FORMATTED and :WITH_UNITS values are always returned
 * as Strings. :RAW values will match their data_type. :CONVERTED values
 * can be any type.
 */
static VALUE value(int argc, VALUE* argv, VALUE self)
{
  VALUE target_name = Qnil;
  VALUE packet_name = Qnil;
  VALUE item_name = Qnil;
  VALUE value_type = Qnil;
  VALUE result = Qnil;
  VALUE packet = Qnil;

  switch (argc)
  {
    case 3:
      target_name = argv[0];
      packet_name = argv[1];
      item_name = argv[2];
      value_type = symbol_CONVERTED;
      break;
    case 4:
      target_name = argv[0];
      packet_name = argv[1];
      item_name = argv[2];
      value_type = argv[3];
      break;
    default:
      /* Invalid number of arguments given */
      rb_raise(rb_eArgError, "wrong number of arguments (%d for 3..4)", argc);
      break;
  };

  result = packet_and_item(self, target_name, packet_name, item_name);
  packet = rb_ary_entry(result, 0);
  return rb_funcall(packet, id_method_read, 2, item_name, value_type);
}

/*
 * Reads the specified list of items and returns their values and limits
 * state.
 *
 * @param item_array [Array<Array(String String String)>] An array
 *   consisting of [target name, packet name, item name]
 * @param value_types [Symbol|Array<Symbol>] How to convert the items before
 *   returning. A single symbol of {Packet::VALUE_TYPES}
 *   can be passed which will convert all items the same way. Or
 *   an array of symbols can be passed to control how each item is
 *   converted.
 * @return [Array, Array, Array] The first array contains the item values, the
 *   second their limits state, and the third the limits settings which includes
 *   red, yellow, and green (if given) limits values.
 */
static VALUE values_and_limits_states(int argc, VALUE* argv, VALUE self) {
  VALUE item_array = Qnil;
  VALUE value_types = Qnil;
  VALUE items = Qnil;
  VALUE states = Qnil;
  VALUE settings = Qnil;
  VALUE entry = Qnil;
  VALUE target_name = Qnil;
  VALUE packet_name = Qnil;
  VALUE item_name = Qnil;
  VALUE value_type = Qnil;
  VALUE result = Qnil;
  VALUE return_value = Qnil;
  VALUE limits = Qnil;
  VALUE limits_set = Qnil;
  VALUE limits_values = Qnil;
  VALUE limits_settings = Qnil;
  long length = 0;
  long value_types_length = 0;
  int index = 0;

  switch (argc) {
    case 1:
      item_array = argv[0];
      value_types = symbol_CONVERTED;
      break;
    case 2:
      item_array = argv[0];
      value_types = argv[1];
      break;
    default:
      /* Invalid number of arguments given */
      rb_raise(rb_eArgError, "wrong number of arguments (%d for 1..2)", argc);
      break;
  };

  items = rb_ary_new();
  /* Verify items is a nested array */
  entry = rb_ary_entry(item_array, index);
  if (TYPE(entry) != T_ARRAY) {
    rb_raise(rb_eArgError, "item_array must be a nested array consisting of [[tgt,pkt,item],[tgt,pkt,item],...]");
  }
  states = rb_ary_new();
  settings = rb_ary_new();
  limits_set = rb_funcall(cSystem, id_method_limits_set, 0);
  length = RARRAY_LEN(item_array);
  if (TYPE(value_types) == T_ARRAY) {
    value_types_length = RARRAY_LEN(value_types);
    if (length != value_types_length) {
      rb_raise(rb_eArgError, "Passed %ld items but only %ld value types", length, value_types_length);
    }

    for (index = 0; index < length; index++) {
      entry = rb_ary_entry(item_array, index);
      target_name = rb_ary_entry(entry, 0);
      packet_name = rb_ary_entry(entry, 1);
      item_name = rb_ary_entry(entry, 2);
      value_type = rb_ary_entry(value_types, index);
      value_type = rb_funcall(value_type, id_method_intern, 0);

      result = packet_and_item(self, target_name, packet_name, item_name);
      rb_ary_push(items, rb_funcall(rb_ary_entry(result, 0), id_method_read, 2, item_name, value_type));
      limits = rb_funcall(rb_ary_entry(result, 1), id_method_limits, 0);
      rb_ary_push(states, rb_funcall(limits, id_method_state, 0));
      limits_values = rb_funcall(limits, id_method_values, 0);
      if (RTEST(limits_values)) {
        limits_settings = rb_hash_aref(limits_values, limits_set);
      } else {
        limits_settings = Qnil;
      }
      rb_ary_push(settings, limits_settings);
    }
  } else {
    value_type = rb_funcall(value_types, id_method_intern, 0);
    for (index = 0; index < length; index++) {
      entry = rb_ary_entry(item_array, index);
      target_name = rb_ary_entry(entry, 0);
      packet_name = rb_ary_entry(entry, 1);
      item_name = rb_ary_entry(entry, 2);

      result = packet_and_item(self, target_name, packet_name, item_name);
      rb_ary_push(items, rb_funcall(rb_ary_entry(result, 0), id_method_read, 2, item_name, value_type));
      limits = rb_funcall(rb_ary_entry(result, 1), id_method_limits, 0);
      rb_ary_push(states, rb_funcall(limits, id_method_state, 0));
      limits_values = rb_funcall(limits, id_method_values, 0);
      if (RTEST(limits_values)) {
        limits_settings = rb_hash_aref(limits_values, limits_set);
      } else {
        limits_settings = Qnil;
      }
      rb_ary_push(settings, limits_settings);
    }
  }

  return_value = rb_ary_new2(3);
  rb_ary_push(return_value, items);
  rb_ary_push(return_value, states);
  rb_ary_push(return_value, settings);
  return return_value;
}

/*
 * Initialize methods for Telemetry
 */
void Init_telemetry (void)
{
  id_ivar_config = rb_intern("@config");
  id_method_telemetry = rb_intern("telemetry");
  id_method_read = rb_intern("read");
  id_method_to_s = rb_intern("to_s");
  id_method_intern = rb_intern("intern");
  id_method_get_item = rb_intern("get_item");
  id_method_upcase = rb_intern("upcase");
  id_method_newest_packet = rb_intern("newest_packet");
  id_method_limits = rb_intern("limits");
  id_method_state = rb_intern("state");
  id_method_limits_set = rb_intern("limits_set");
  id_method_values = rb_intern("values");
  symbol_CONVERTED = ID2SYM(rb_intern("CONVERTED"));

  mCosmos = rb_define_module("Cosmos");
  cTelemetry = rb_define_class_under(mCosmos, "Telemetry", rb_cObject);
  rb_define_method(cTelemetry, "packets", packets, 1);
  rb_define_method(cTelemetry, "packet", packet, 2);
  rb_define_method(cTelemetry, "packet_and_item", packet_and_item, 3);
  rb_define_method(cTelemetry, "value", value, -1);
  rb_define_method(cTelemetry, "values_and_limits_states", values_and_limits_states, -1);

  cSystem = rb_define_class_under(mCosmos, "System", rb_cObject);
}
