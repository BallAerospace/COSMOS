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

VALUE mCosmos = Qnil;
VALUE cBufferedFile = Qnil;
static ID id_ivar_buffer = 0;
static ID id_ivar_buffer_index = 0;
static ID id_method_clear = 0;
static ID id_method_slice_bang = 0;
static ID id_method_to_s = 0;
static ID id_method_pos = 0;
static ID id_const_BUFFER_SIZE = 0;
static ID id_const_ALL_RANGE = 0;
static VALUE BUFFERED_FILE_SEEK_SET = Qnil;
static VALUE BUFFERED_FILE_SEEK_CUR = Qnil;

#define BUFFER_SIZE (1024 * 16)

/* Initialize the BufferedFile.  Takes the same args as File */
static VALUE buffered_file_initialize(int argc, VALUE *argv, VALUE self)
{
  rb_call_super(argc, argv);
  rb_ivar_set(self, id_ivar_buffer, rb_str_new2(""));
  rb_ivar_set(self, id_ivar_buffer_index, INT2FIX(0));
  return self;
}

/* Read using an internal buffer to avoid system calls */
static VALUE buffered_file_read(VALUE self, VALUE arg_length)
{
  long length = FIX2INT(arg_length);
  volatile VALUE buffer = rb_ivar_get(self, id_ivar_buffer);
  long buffer_length = RSTRING_LEN(buffer);
  long buffer_index = FIX2INT(rb_ivar_get(self, id_ivar_buffer_index));
  volatile VALUE result = Qnil;
  volatile VALUE super_arg = Qnil;

  if (length <= (buffer_length - buffer_index))
  {
    /* Return part of the buffer without having to go to the OS */
    result = rb_str_substr(buffer, buffer_index, length);
    buffer_index += length;
    rb_ivar_set(self, id_ivar_buffer_index, INT2FIX(buffer_index));
    return result;
  }
  else if (length > BUFFER_SIZE)
  {
    /* Reading more than our buffer */
    if (buffer_length > 0)
    {
      if (buffer_index > 0)
      {
        rb_funcall(buffer, id_method_slice_bang, 1, rb_range_new(INT2FIX(0), INT2FIX(buffer_index - 1), Qfalse));
        buffer_length = RSTRING_LEN(buffer);
        buffer_index = 0;
        rb_ivar_set(self, id_ivar_buffer_index, INT2FIX(0));
      }
      super_arg = INT2FIX(length - buffer_length);
      rb_str_append(buffer, rb_funcall(rb_call_super(1, (VALUE *)&super_arg), id_method_to_s, 0));
      return rb_funcall(buffer, id_method_slice_bang, 1, rb_const_get(cBufferedFile, id_const_ALL_RANGE));
    }
    else
    {
      return rb_call_super(1, &arg_length);
    }
  }
  else
  {
    /* Read into the buffer */
    if (buffer_index > 0)
    {
      rb_funcall(buffer, id_method_slice_bang, 1, rb_range_new(INT2FIX(0), INT2FIX(buffer_index - 1), Qfalse));
      buffer_length = RSTRING_LEN(buffer);
      buffer_index = 0;
      rb_ivar_set(self, id_ivar_buffer_index, INT2FIX(0));
    }
    super_arg = INT2FIX(BUFFER_SIZE - buffer_length);
    rb_str_append(buffer, rb_funcall(rb_call_super(1, (VALUE *)&super_arg), id_method_to_s, 0));
    buffer_length = RSTRING_LEN(buffer);
    if (buffer_length <= 0)
    {
      return Qnil;
    }

    if (length <= buffer_length)
    {
      result = rb_str_substr(buffer, buffer_index, length);
      buffer_index += length;
      rb_ivar_set(self, id_ivar_buffer_index, INT2FIX(buffer_index));
      return result;
    }
    else
    {
      return rb_funcall(buffer, id_method_slice_bang, 1, rb_const_get(cBufferedFile, id_const_ALL_RANGE));
    }
  }
}

/* Get the current file position */
static VALUE buffered_file_pos(VALUE self)
{
  volatile VALUE parent_pos = rb_call_super(0, NULL);
  long long ll_pos = NUM2LL(parent_pos);
  long buffer_length = RSTRING_LEN(rb_ivar_get(self, id_ivar_buffer));
  long buffer_index = FIX2INT(rb_ivar_get(self, id_ivar_buffer_index));
  return LL2NUM(ll_pos - (long long)(buffer_length - buffer_index));
}

/* Seek to a given file position */
static VALUE buffered_file_seek(int argc, VALUE *argv, VALUE self)
{
  volatile VALUE amount = Qnil;
  volatile VALUE whence = Qnil;
  long buffer_index = 0;
  volatile VALUE super_args[2] = {Qnil, Qnil};

  switch (argc)
  {
  case 1:
    amount = argv[0];
    whence = BUFFERED_FILE_SEEK_SET;
    break;

  case 2:
    amount = argv[0];
    whence = argv[1];
    break;

  default:
    /* Invalid number of arguments given - let super handle */
    return rb_call_super(argc, argv);
  };

  if (whence == BUFFERED_FILE_SEEK_CUR)
  {
    buffer_index = FIX2INT(rb_ivar_get(self, id_ivar_buffer_index)) + FIX2INT(amount);
    if ((buffer_index >= 0) && (buffer_index < RSTRING_LEN(rb_ivar_get(self, id_ivar_buffer))))
    {
      rb_ivar_set(self, id_ivar_buffer_index, INT2FIX(buffer_index));
      return INT2FIX(0);
    }
    super_args[0] = rb_funcall(self, id_method_pos, 0);
    super_args[1] = BUFFERED_FILE_SEEK_SET;
    rb_call_super(2, (VALUE *)super_args);
  }

  rb_funcall(rb_ivar_get(self, id_ivar_buffer), id_method_clear, 0);
  rb_ivar_set(self, id_ivar_buffer_index, INT2FIX(0));
  return rb_call_super(argc, argv);
}

/*
 * Initialize methods for BufferedFile
 */
void Init_buffered_file(void)
{
  id_ivar_buffer = rb_intern("@buffer");
  id_ivar_buffer_index = rb_intern("@buffer_index");
  id_method_clear = rb_intern("clear");
  id_method_slice_bang = rb_intern("slice!");
  id_method_to_s = rb_intern("to_s");
  id_method_pos = rb_intern("pos");
  id_const_BUFFER_SIZE = rb_intern("BUFFER_SIZE");
  id_const_ALL_RANGE = rb_intern("ALL_RANGE");
  BUFFERED_FILE_SEEK_SET = rb_const_get(rb_cIO, rb_intern("SEEK_SET"));
  BUFFERED_FILE_SEEK_CUR = rb_const_get(rb_cIO, rb_intern("SEEK_CUR"));

  mCosmos = rb_define_module("Cosmos");
  cBufferedFile = rb_define_class_under(mCosmos, "BufferedFile", rb_cFile);
  rb_const_set(cBufferedFile, id_const_BUFFER_SIZE, INT2FIX(BUFFER_SIZE));
  rb_const_set(cBufferedFile, id_const_ALL_RANGE, rb_range_new(INT2FIX(0), INT2FIX(-1), Qfalse));

  rb_define_method(cBufferedFile, "initialize", buffered_file_initialize, -1);
  rb_define_method(cBufferedFile, "read", buffered_file_read, 1);
  rb_define_method(cBufferedFile, "seek", buffered_file_seek, -1);
  rb_define_method(cBufferedFile, "pos", buffered_file_pos, 0);
}
