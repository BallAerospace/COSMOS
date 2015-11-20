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

static const int endianness_check = 1;
#define HOST_ENDIANNESS (*((char *) &endianness_check))
#define COSMOS_BIG_ENDIAN 0
#define COSMOS_LITTLE_ENDIAN 1

VALUE mCosmosIO = Qnil;

static ID id_method_read         = 0;

/* Reads a length field and then return the String resulting from reading the
  * number of bytes the length field indicates
  *
  * For example:
  *   io = StringIO.new
  *   # where io is "\x02\x01\x02\x03\x04...."
  *   result = io.read_length_bytes(1)
  *   # result will be "\x01x02" because the length field was given
  *   # to be 1 byte. We read 1 byte which is a 2. So we then read two
  *   # bytes and return.
  *
  * @param length_num_bytes [Integer] Number of bytes in the length field
  * @return [String] A String of "length field" number of bytes
  */
static VALUE read_length_bytes(VALUE self, VALUE param_length_num_bytes)
{
  int length_num_bytes = FIX2INT(param_length_num_bytes);
  unsigned char* string = NULL;
  long string_length = 0;
  unsigned short short_length = 0;
  unsigned char* length_ptr = NULL;
  volatile VALUE temp_string = Qnil;
  volatile VALUE temp_string_length = Qnil;
  volatile VALUE return_value = Qnil;

  /* Read bytes for string length */
  temp_string = rb_funcall(self, id_method_read, 1, param_length_num_bytes);
  if (NIL_P(temp_string) || (RSTRING_LEN(temp_string) != length_num_bytes))
  {
    return Qnil;
  }

  string = (unsigned char*) RSTRING_PTR(temp_string);
  switch (length_num_bytes)
  {
    case 1:
      string_length = (unsigned int) string[0];
      break;
    case 2:
      length_ptr = (unsigned char*) &short_length;
      if (HOST_ENDIANNESS == COSMOS_BIG_ENDIAN)
      {
        length_ptr[1] = string[1];
        length_ptr[0] = string[0];
      }
      else
      {
        length_ptr[0] = string[1];
        length_ptr[1] = string[0];
      }
      string_length = short_length;
      break;
    case 4:
      length_ptr = (unsigned char*) &string_length;
      if (HOST_ENDIANNESS == COSMOS_BIG_ENDIAN)
      {
        length_ptr[3] = string[3];
        length_ptr[2] = string[2];
        length_ptr[1] = string[1];
        length_ptr[0] = string[0];
      }
      else
      {
        length_ptr[0] = string[3];
        length_ptr[1] = string[2];
        length_ptr[2] = string[1];
        length_ptr[3] = string[0];
      }
      break;
    default:
      return Qnil;
      break;
  };

  /* Read String */
  temp_string_length = UINT2NUM(string_length);
  return_value = rb_funcall(self, id_method_read, 1, temp_string_length);
  if (NIL_P(return_value) || (RSTRING_LEN(return_value) != string_length))
  {
    return Qnil;
  }

  return return_value;
}

/*
 * Initialize methods for CosmosIO
 */
void Init_cosmos_io (void)
{
  id_method_read = rb_intern("read");

  mCosmosIO = rb_define_module("CosmosIO");
  rb_define_method(mCosmosIO, "read_length_bytes", read_length_bytes, 1);
}
