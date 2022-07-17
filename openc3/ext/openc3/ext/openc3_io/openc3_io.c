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

static const int endianness_check = 1;
#define HOST_ENDIANNESS (*((char *)&endianness_check))
#define OPENC3_BIG_ENDIAN 0
#define OPENC3_LITTLE_ENDIAN 1

VALUE mOpenC3IO = Qnil;

static ID id_method_read = 0;

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
static VALUE read_length_bytes(int argc, VALUE *argv, VALUE self)
{
  int length_num_bytes = 0;
  int max_read_size = 0;
  unsigned char *string = NULL;
  long string_length = 0;
  unsigned short short_length = 0;
  unsigned char *length_ptr = NULL;
  volatile VALUE temp_string = Qnil;
  volatile VALUE temp_string_length = Qnil;
  volatile VALUE return_value = Qnil;
  volatile VALUE param_length_num_bytes = Qnil;
  volatile VALUE param_max_read_size = Qnil;

  switch (argc)
  {
  case 1:
    param_length_num_bytes = argv[0];
    param_max_read_size = Qnil;
    break;
  case 2:
    param_length_num_bytes = argv[0];
    param_max_read_size = argv[1];
    break;
  default:
    /* Invalid number of arguments given */
    rb_raise(rb_eArgError, "wrong number of arguments (%d for 1..2)", argc);
    break;
  };

  length_num_bytes = FIX2INT(param_length_num_bytes);

  /* Read bytes for string length */
  temp_string = rb_funcall(self, id_method_read, 1, param_length_num_bytes);
  if (NIL_P(temp_string) || (RSTRING_LEN(temp_string) != length_num_bytes))
  {
    return Qnil;
  }

  string = (unsigned char *)RSTRING_PTR(temp_string);
  switch (length_num_bytes)
  {
  case 1:
    string_length = (unsigned int)string[0];
    break;
  case 2:
    length_ptr = (unsigned char *)&short_length;
    if (HOST_ENDIANNESS == OPENC3_BIG_ENDIAN)
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
    length_ptr = (unsigned char *)&string_length;
    if (HOST_ENDIANNESS == OPENC3_BIG_ENDIAN)
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

  if (RTEST(param_max_read_size))
  {
    max_read_size = FIX2INT(param_max_read_size);
    if (string_length > max_read_size)
    {
      return Qnil;
    }
  }

  /* Read String */
  temp_string_length = UINT2NUM((unsigned int)string_length);
  return_value = rb_funcall(self, id_method_read, 1, temp_string_length);
  if (NIL_P(return_value) || (RSTRING_LEN(return_value) != string_length))
  {
    return Qnil;
  }

  return return_value;
}

/*
 * Initialize methods for OpenC3IO
 */
void Init_openc3_io(void)
{
  id_method_read = rb_intern("read");

  mOpenC3IO = rb_define_module("OpenC3IO");
  rb_define_method(mOpenC3IO, "read_length_bytes", read_length_bytes, -1);
}
