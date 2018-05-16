/*
# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
*/

#include "ruby.h"
#include "stdio.h"

#define TO_BIGNUM(x) (FIXNUM_P(x) ? rb_int2big(FIX2LONG(x)) : x)
#define BYTE_ALIGNED(x) (((x) % 8) == 0)

static const int endianness_check = 1;
static VALUE HOST_ENDIANNESS = Qnil;
static VALUE ZERO_STRING = Qnil;
static VALUE ASCII_8BIT_STRING = Qnil;

static VALUE MIN_INT8 = Qnil;
static VALUE MAX_INT8 = Qnil;
static VALUE MAX_UINT8 = Qnil;
static VALUE MIN_INT16 = Qnil;
static VALUE MAX_INT16 = Qnil;
static VALUE MAX_UINT16 = Qnil;
static VALUE MIN_INT32 = Qnil;
static VALUE MAX_INT32 = Qnil;
static VALUE MAX_UINT32 = Qnil;
static VALUE MIN_INT64 = Qnil;
static VALUE MAX_INT64 = Qnil;
static VALUE MAX_UINT64 = Qnil;

static VALUE mCosmos = Qnil;
static VALUE cBinaryAccessor = Qnil;
static VALUE cStructure = Qnil;
static VALUE cStructureItem = Qnil;

static ID id_method_to_s = 0;
static ID id_method_raise_buffer_error = 0;
static ID id_method_read_array = 0;
static ID id_method_force_encoding = 0;
static ID id_method_freeze = 0;
static ID id_method_slice = 0;
static ID id_method_reverse = 0;
static ID id_method_Integer = 0;
static ID id_method_Float = 0;
static ID id_method_kind_of = 0;

static ID id_ivar_buffer = 0;
static ID id_ivar_bit_offset = 0;
static ID id_ivar_bit_size = 0;
static ID id_ivar_array_size = 0;
static ID id_ivar_endianness = 0;
static ID id_ivar_data_type = 0;
static ID id_ivar_default_endianness = 0;
static ID id_ivar_item_class = 0;
static ID id_ivar_items = 0;
static ID id_ivar_sorted_items = 0;
static ID id_ivar_defined_length = 0;
static ID id_ivar_defined_length_bits = 0;
static ID id_ivar_pos_bit_size = 0;
static ID id_ivar_neg_bit_size = 0;
static ID id_ivar_fixed_size = 0;
static ID id_ivar_short_buffer_allowed = 0;
static ID id_ivar_mutex = 0;
static ID id_ivar_create_index = 0;

static ID id_const_ASCII_8BIT_STRING = 0;
static ID id_const_ZERO_STRING = 0;

static VALUE symbol_LITTLE_ENDIAN = Qnil;
static VALUE symbol_BIG_ENDIAN = Qnil;
static VALUE symbol_INT = Qnil;
static VALUE symbol_UINT = Qnil;
static VALUE symbol_FLOAT = Qnil;
static VALUE symbol_STRING = Qnil;
static VALUE symbol_BLOCK = Qnil;
static VALUE symbol_DERIVED = Qnil;
static VALUE symbol_read = Qnil;
static VALUE symbol_write = Qnil;
static VALUE symbol_TRUNCATE = Qnil;
static VALUE symbol_SATURATE = Qnil;
static VALUE symbol_ERROR = Qnil;
static VALUE symbol_ERROR_ALLOW_HEX = Qnil;

/*
 * Perform an left bit shift on a string
 */
static void left_shift_byte_array (unsigned char* array, int array_length, int shift)
{
  int current_index = 0;
  int previous_index = 0;
  unsigned char saved_bits = 0;
  unsigned char saved_bits_mask = (0xFF << (8 - shift));
  unsigned char sign_extension_remove_mask = ~(0xFF << shift);

  for (current_index = 0; current_index < array_length; current_index++)
  {
    /* Save bits that will be lost */
    saved_bits = ((array[current_index] & saved_bits_mask) >> (8 - shift)) & sign_extension_remove_mask;

    /* Perform shift on current byte */
    array[current_index] <<= shift;

    /* Add Saved bits to end of previous byte */
    if (current_index > 0)
    {
      array[previous_index] |= saved_bits;
    }

    /* Update previous index */
    previous_index = current_index;
  }
}

/*
 * Perform an unsigned right bit shift on a string
 */
static void unsigned_right_shift_byte_array (unsigned char* array, int array_length, int shift)
{
  int current_index = 0;
  int previous_index = 0;
  unsigned char saved_bits = 0;
  unsigned char saved_bits_mask = ~(0xFF << shift);
  unsigned char sign_extension_remove_mask = ~(0xFF << (8 - shift));

  for (current_index = array_length - 1; current_index >= 0; current_index--)
  {
    /* Save bits that will be lost */
    saved_bits = (array[current_index] & saved_bits_mask) << (8 - shift);

    /* Perform shift on current byte */
    array[current_index] = (array[current_index] >> shift) & sign_extension_remove_mask;

    /* Add Saved bits to beginning of previous byte */
    if (current_index != (array_length - 1))
    {
      array[previous_index] |= saved_bits;
    }

    /* Update previous index */
    previous_index = current_index;
  }
}

/*
 * Perform an signed right bit shift on a string
 */
static void signed_right_shift_byte_array (unsigned char* array, int array_length, int shift)
{
  unsigned char start_bits_mask = (0xFF << (8 - shift));
  int is_signed = (0x80 & array[0]);

  unsigned_right_shift_byte_array(array, array_length, shift);

  if (is_signed)
  {
    array[0] |= start_bits_mask;
  }
}

/*
 * Perform an unsigned bit shift on a string
 */
static void unsigned_shift_byte_array (unsigned char* array, int array_length, int shift)
{
  if (shift < 0)
  {
    left_shift_byte_array(array, array_length, -shift);
  }
  else if (shift > 0)
  {
    unsigned_right_shift_byte_array(array, array_length, shift);
  }
}

/*
 * Reverse the byte order in a string.
 */
static void reverse_bytes (unsigned char* array, int array_length)
{
  int first_index  = 0;
  int second_index = 0;
  unsigned char temp_byte = 0;

  for (first_index = 0; first_index < (array_length / 2); first_index++)
  {
    second_index = array_length - 1 - first_index;
    temp_byte = array[first_index];
    array[first_index] = array[second_index];
    array[second_index] = temp_byte;
  }
}

static void read_aligned_16(int lower_bound, int upper_bound, VALUE endianness, unsigned char *buffer, unsigned char *read_value) {
  if (endianness == HOST_ENDIANNESS)
  {
    read_value[1] = buffer[upper_bound];
    read_value[0] = buffer[lower_bound];
  }
  else
  {
    read_value[0] = buffer[upper_bound];
    read_value[1] = buffer[lower_bound];
  }
}

static void read_aligned_32(int lower_bound, int upper_bound, VALUE endianness, unsigned char *buffer, unsigned char *read_value) {
  if (endianness == HOST_ENDIANNESS)
  {
    read_value[3] = buffer[upper_bound];
    read_value[2] = buffer[upper_bound - 1];
    read_value[1] = buffer[lower_bound + 1];
    read_value[0] = buffer[lower_bound];
  }
  else
  {
    read_value[0] = buffer[upper_bound];
    read_value[1] = buffer[upper_bound - 1];
    read_value[2] = buffer[lower_bound + 1];
    read_value[3] = buffer[lower_bound];
  }
}

static void read_aligned_64(int lower_bound, int upper_bound, VALUE endianness, unsigned char *buffer, unsigned char *read_value) {
  if (endianness == HOST_ENDIANNESS)
  {
    read_value[7] = buffer[upper_bound];
    read_value[6] = buffer[upper_bound - 1];
    read_value[5] = buffer[upper_bound - 2];
    read_value[4] = buffer[upper_bound - 3];
    read_value[3] = buffer[lower_bound + 3];
    read_value[2] = buffer[lower_bound + 2];
    read_value[1] = buffer[lower_bound + 1];
    read_value[0] = buffer[lower_bound];
  }
  else
  {
    read_value[0] = buffer[upper_bound];
    read_value[1] = buffer[upper_bound - 1];
    read_value[2] = buffer[upper_bound - 2];
    read_value[3] = buffer[upper_bound - 3];
    read_value[4] = buffer[lower_bound + 3];
    read_value[5] = buffer[lower_bound + 2];
    read_value[6] = buffer[lower_bound + 1];
    read_value[7] = buffer[lower_bound];
  }
}

static void read_bitfield(int lower_bound, int upper_bound, int bit_offset, int bit_size, int given_bit_offset, int given_bit_size, VALUE endianness, unsigned char* buffer, int buffer_length, unsigned char* read_value) {
  /* Local variables */
  int num_bytes = 0;
  int total_bits = 0;
  int start_bits = 0;
  int end_bits = 0;
  int temp_upper = 0;
  unsigned char end_mask = 0;

  /* Copy Data For Bitfield into read_value */
  if (endianness == symbol_LITTLE_ENDIAN)
  {
    /* Bitoffset always refers to the most significant bit of a bitfield */
    num_bytes = (((bit_offset % 8) + bit_size - 1) / 8) + 1;
    upper_bound = bit_offset / 8;
    lower_bound = upper_bound - num_bytes + 1;

    if (lower_bound < 0) {
      rb_raise(rb_eArgError, "LITTLE_ENDIAN bitfield with bit_offset %d and bit_size %d is invalid", given_bit_offset, given_bit_size);
    }

    memcpy(read_value, &buffer[lower_bound], num_bytes);
    reverse_bytes(read_value, num_bytes);
  }
  else
  {
    num_bytes = upper_bound - lower_bound + 1;
    memcpy(read_value, &buffer[lower_bound], num_bytes);
  }

  /* Determine temp upper bound */
  temp_upper = upper_bound - lower_bound;

  /* Handle Bitfield */
  total_bits = (temp_upper + 1) * 8;
  start_bits = bit_offset % 8;
  end_bits = total_bits - start_bits - bit_size;
  end_mask = 0xFF << end_bits;

  /* Mask off unwanted bits at end */
  read_value[temp_upper] &= end_mask;

  /* Shift off unwanted bits at beginning */
  unsigned_shift_byte_array(read_value, num_bytes, -start_bits);
}

static void write_bitfield(int lower_bound, int upper_bound, int bit_offset, int bit_size, int given_bit_offset, int given_bit_size, VALUE endianness, unsigned char* buffer, int buffer_length, unsigned char* write_value) {
  /* Local variables */
  int num_bytes = 0;
  int total_bits = 0;
  int start_bits = 0;
  int end_bits = 0;
  int temp_upper = 0;
  unsigned char start_mask = 0;
  unsigned char end_mask = 0;

  if (endianness == symbol_LITTLE_ENDIAN)
  {
    /* Bitoffset always refers to the most significant bit of a bitfield */
    num_bytes = (((bit_offset % 8) + bit_size - 1) / 8) + 1;
    upper_bound = bit_offset / 8;
    lower_bound = upper_bound - num_bytes + 1;

    if (lower_bound < 0) {
      rb_raise(rb_eArgError, "LITTLE_ENDIAN bitfield with bit_offset %d and bit_size %d is invalid", given_bit_offset, given_bit_size);
    }
  }
  else
  {
    num_bytes = upper_bound - lower_bound + 1;
  }

  /* Determine temp upper bound */
  temp_upper = upper_bound - lower_bound;

  /* Handle Bitfield */
  total_bits = (temp_upper + 1) * 8;
  start_bits = bit_offset % 8;
  start_mask = 0xFF << (8 - start_bits);
  end_bits = total_bits - start_bits - bit_size;
  end_mask = 0xFF >> (8 - end_bits);

  /* Shift to the right position */
  unsigned_shift_byte_array(write_value, num_bytes, start_bits);

  if (endianness == symbol_LITTLE_ENDIAN)
  {
    /* Mask in wanted bits at beginning */
    write_value[0] |= buffer[upper_bound] & start_mask;

    /* Mask in wanted bits at the end */
    write_value[temp_upper] |= buffer[lower_bound] & end_mask;

    reverse_bytes(write_value, num_bytes);
  }
  else
  {
    /* Mask in wanted bits at beginning */
    write_value[0] |= buffer[lower_bound] & start_mask;

    /* Mask in wanted bits at the end */
    write_value[temp_upper] |= buffer[upper_bound] & end_mask;
  }

  /* Write the bytes into the buffer */
  memcpy(&buffer[lower_bound], write_value, num_bytes);
}

/* Check the bit size and bit offset for problems. Recalulate the bit offset
 * and return back through the passed in pointer. */
static void check_bit_offset_and_size(VALUE self, VALUE type_param, VALUE bit_offset_param, VALUE bit_size_param, VALUE data_type_param, VALUE buffer_param, int *new_bit_offset)
{
  int bit_offset = NUM2INT(bit_offset_param);
  int bit_size = NUM2INT(bit_size_param);

  if ((bit_size <= 0) && (data_type_param != symbol_STRING) && (data_type_param != symbol_BLOCK)) {
    rb_raise(rb_eArgError, "bit_size %d must be positive for data types other than :STRING and :BLOCK", bit_size);
  }

  if ((bit_size <= 0) && (bit_offset < 0)) {
    rb_raise(rb_eArgError, "negative or zero bit_sizes (%d) cannot be given with negative bit_offsets (%d)", bit_size, bit_offset);
  }

  if (bit_offset < 0) {
    bit_offset = ((RSTRING_LEN(buffer_param)* 8) + bit_offset);
    if (bit_offset < 0) {
      rb_funcall(self, id_method_raise_buffer_error, 5, type_param, buffer_param, data_type_param, bit_offset_param, bit_size_param);
    }
  }

  *new_bit_offset = bit_offset;
}

/* Returns true if the bit_size is 8, 16, 32, or 64 */
static int even_bit_size(int bit_size)
{
  return ((bit_size == 8) || (bit_size == 16) || (bit_size == 32) || (bit_size == 64));
}

/* Calculate the bounds of the string to access the item based on the bit_offset and bit_size.
 * Also determine if the buffer size is sufficient. */
static int check_bounds_and_buffer_size(int bit_offset, int bit_size, int buffer_length, VALUE endianness, VALUE data_type, int *lower_bound, int *upper_bound)
{
  int result = 1; /* Assume ok */

  /* Define bounds of string to access this item */
  *lower_bound = bit_offset / 8;
  *upper_bound = (bit_offset + bit_size - 1) / 8;

  /* Sanity check buffer size */
  if (*upper_bound >= buffer_length) {
    /* If it's not the special case of little endian bit field then we fail and return 0 */
    if (!( (endianness == symbol_LITTLE_ENDIAN) &&
           ((data_type == symbol_INT) || (data_type == symbol_UINT)) &&
           /* Not byte aligned with an even bit size */
           (!( (BYTE_ALIGNED(bit_offset)) && (even_bit_size(bit_size)) )) &&
           (*lower_bound < buffer_length)
       )) {
      result = 0;
    }
  }
  return result;
}

/*
 * Reads binary data of any data type from a buffer
 *
 * @param bit_offset [Integer] Bit offset to the start of the item. A
 *   negative number means to offset from the end of the buffer.
 * @param bit_size [Integer] Size of the item in bits
 * @param data_type [Symbol] {DATA_TYPES}
 * @param buffer [String] Binary string buffer to read from
 * @param endianness [Symbol] {ENDIANNESS}
 * @return [Integer] value read from the buffer
 */
static VALUE binary_accessor_read(VALUE self, VALUE param_bit_offset, VALUE param_bit_size, VALUE param_data_type, VALUE param_buffer, VALUE param_endianness)
{
  /* Convert Parameters to C Data Types */
  int bit_offset = FIX2INT(param_bit_offset);
  int bit_size = FIX2INT(param_bit_size);

  /* Local Variables */
  int given_bit_offset = bit_offset;
  int given_bit_size = bit_size;
  signed char signed_char_value = 0;
  unsigned char unsigned_char_value = 0;
  signed short signed_short_value = 0;
  unsigned short unsigned_short_value = 0;
  signed int signed_int_value = 0;
  signed long signed_long_value = 0;
  unsigned int unsigned_int_value = 0;
  signed long long signed_long_long_value = 0;
  unsigned long long unsigned_long_long_value = 0;
  unsigned char* unsigned_char_array = NULL;
  int array_length = 0;
  char* string = NULL;
  int string_length = 0;
  float float_value = 0.0;
  double double_value = 0.0;
  int shift_needed = 0;
  int shift_count = 0;
  int index = 0;
  int num_bits = 0;
  int num_bytes = 0;
  int num_words = 0;
  int upper_bound = 0;
  int lower_bound = 0;
  volatile VALUE temp_value = Qnil;
  volatile VALUE return_value = Qnil;

  unsigned char* buffer = NULL;
  long buffer_length = 0;

  Check_Type(param_buffer, T_STRING);
  buffer = (unsigned char*) RSTRING_PTR(param_buffer);
  buffer_length = RSTRING_LEN(param_buffer);

  check_bit_offset_and_size(self, symbol_read, param_bit_offset, param_bit_size,
      param_data_type, param_buffer, &bit_offset);

  /* If passed a negative bit size with strings or blocks
   * recalculate based on the buffer length */
  if ((bit_size <= 0) && ((param_data_type == symbol_STRING) || (param_data_type == symbol_BLOCK))) {
    bit_size = (((int)buffer_length * 8) - bit_offset + bit_size);
    if (bit_size == 0) {
      return rb_str_new2("");
    } else if (bit_size < 0) {
      rb_funcall(self, id_method_raise_buffer_error, 5, symbol_read, param_buffer, param_data_type, param_bit_offset, param_bit_size);
    }
  }

  if (!check_bounds_and_buffer_size(bit_offset, bit_size, buffer_length, param_endianness, param_data_type, &lower_bound, &upper_bound))
  {
    rb_funcall(self, id_method_raise_buffer_error, 5, symbol_read, param_buffer, param_data_type, param_bit_offset, param_bit_size);
  }

  if ((param_data_type == symbol_STRING) || (param_data_type == symbol_BLOCK)) {
    /*#######################################
     *# Handle :STRING and :BLOCK data types
     *#######################################*/

    if (BYTE_ALIGNED(bit_offset)) {
      string_length = upper_bound - lower_bound + 1;
      string = malloc(string_length + 1);
      memcpy(string, buffer + lower_bound, string_length);
      string[string_length] = 0;
      if (param_data_type == symbol_STRING) {
        return_value = rb_str_new2(string);
      } else /* param_data_type == symbol_BLOCK */ {
        return_value = rb_str_new(string, string_length);
      }
      free(string);
    } else {
      rb_raise(rb_eArgError, "bit_offset %d is not byte aligned for data_type %s", given_bit_offset, RSTRING_PTR(rb_funcall(param_data_type, id_method_to_s, 0)));
    }

  } else if (param_data_type == symbol_INT) {
    /*###################################
     *# Handle :INT data type
     *###################################*/

    if ((BYTE_ALIGNED(bit_offset)) && (even_bit_size(bit_size)))
    {
      /*###########################################################
       *# Handle byte-aligned 8, 16, 32, and 64 bit :INT
       *###########################################################*/

      switch (bit_size) {
        case 8:
          signed_char_value = *((signed char*) &buffer[lower_bound]);
          return_value = INT2FIX(signed_char_value);
          break;
        case 16:
          read_aligned_16(lower_bound, upper_bound, param_endianness, buffer, (unsigned char*) &signed_short_value);
          return_value = INT2FIX(signed_short_value);
          break;
        case 32:
          read_aligned_32(lower_bound, upper_bound, param_endianness, buffer, (unsigned char*) &signed_int_value);
          return_value = INT2NUM(signed_int_value);
          break;
        case 64:
          read_aligned_64(lower_bound, upper_bound, param_endianness, buffer, (unsigned char*) &signed_long_long_value);
          return_value = LL2NUM(signed_long_long_value);
          break;
      }
    } else {
      string_length = ((bit_size - 1)/ 8) + 1;
      array_length = string_length + 4; /* Required number of bytes plus slack */
      unsigned_char_array = (unsigned char*) malloc(array_length);
      read_bitfield(lower_bound, upper_bound, bit_offset, bit_size, given_bit_offset, given_bit_size, param_endianness, buffer, (int)buffer_length, unsigned_char_array);

      num_words = ((string_length - 1) / 4) + 1;
      num_bytes = num_words * 4;
      num_bits = num_bytes * 8;
      shift_needed = num_bits - bit_size;
      shift_count = shift_needed / 8;
      shift_needed = shift_needed % 8;

      if (bit_size > 1) {
        for (index = 0; index < shift_count; index++) {
          signed_right_shift_byte_array(unsigned_char_array, num_bytes, 8);
        }

        if (shift_needed > 0) {
          signed_right_shift_byte_array(unsigned_char_array, num_bytes, shift_needed);
        }
      } else {
        for (index = 0; index < shift_count; index++) {
          unsigned_right_shift_byte_array(unsigned_char_array, num_bytes, 8);
        }

        if (shift_needed > 0) {
          unsigned_right_shift_byte_array(unsigned_char_array, num_bytes, shift_needed);
        }
      }

      if (HOST_ENDIANNESS == symbol_LITTLE_ENDIAN) {
        for (index = 0; index < num_bytes; index += 4) {
          reverse_bytes(&(unsigned_char_array[index]), 4);
        }
      }

      if (bit_size <= 31) {
        return_value = INT2FIX(*((int*) unsigned_char_array));
      } else if (bit_size == 32) {
        return_value = INT2NUM(*((int*) unsigned_char_array));
      } else {
        return_value = rb_int2big(*((int*) unsigned_char_array));
        temp_value = INT2FIX(32);
        for (index = 4; index < num_bytes; index += 4) {
          return_value = rb_big_lshift(return_value, temp_value);
          if (FIXNUM_P(return_value)) {
            signed_long_value = FIX2LONG(return_value);
            return_value = rb_int2big(signed_long_value);
          }
          return_value = rb_big_plus(return_value, UINT2NUM(*((unsigned int*) &(unsigned_char_array[index]))));
          if (FIXNUM_P(return_value)) {
            signed_long_value = FIX2LONG(return_value);
            return_value = rb_int2big(signed_long_value);
          }
        }
        return_value = rb_big_norm(return_value);
      }

      free(unsigned_char_array);
    }

  } else if (param_data_type == symbol_UINT) {
    /*###################################
     *# Handle :UINT data type
     *###################################*/

    if ((BYTE_ALIGNED(bit_offset)) && (even_bit_size(bit_size)))
    {
      /*###########################################################
       *# Handle byte-aligned 8, 16, 32, and 64 bit :UINT
       *###########################################################*/

      switch (bit_size) {
        case 8:
          unsigned_char_value = buffer[lower_bound];
          return_value = INT2FIX(unsigned_char_value);
          break;
        case 16:
          read_aligned_16(lower_bound, upper_bound, param_endianness, buffer, (unsigned char*) &unsigned_short_value);
          return_value = INT2FIX(unsigned_short_value);
          break;
        case 32:
          read_aligned_32(lower_bound, upper_bound, param_endianness, buffer, (unsigned char*) &unsigned_int_value);
          return_value = UINT2NUM(unsigned_int_value);
          break;
        case 64:
          read_aligned_64(lower_bound, upper_bound, param_endianness, buffer, (unsigned char*) &unsigned_long_long_value);
          return_value = ULL2NUM(unsigned_long_long_value);
          break;
      }
    } else {
      string_length = ((bit_size - 1)/ 8) + 1;
      array_length = string_length + 4; /* Required number of bytes plus slack */
      unsigned_char_array = (unsigned char*) malloc(array_length);
      read_bitfield(lower_bound, upper_bound, bit_offset, bit_size, given_bit_offset, given_bit_size, param_endianness, buffer, (int)buffer_length, unsigned_char_array);

      num_words = ((string_length - 1) / 4) + 1;
      num_bytes = num_words * 4;
      num_bits = num_bytes * 8;
      shift_needed = num_bits - bit_size;
      shift_count = shift_needed / 8;
      shift_needed = shift_needed % 8;

      for (index = 0; index < shift_count; index++) {
        unsigned_right_shift_byte_array(unsigned_char_array, num_bytes, 8);
      }

      if (shift_needed > 0) {
        unsigned_right_shift_byte_array(unsigned_char_array, num_bytes, shift_needed);
      }

      if (HOST_ENDIANNESS == symbol_LITTLE_ENDIAN) {
        for (index = 0; index < num_bytes; index += 4) {
          reverse_bytes(&(unsigned_char_array[index]), 4);
        }
      }

      if (bit_size <= 30) {
        return_value = INT2FIX(*((int*) unsigned_char_array));
      } else if (bit_size <= 32) {
        return_value = UINT2NUM(*((unsigned int*) unsigned_char_array));
      } else {
        return_value = rb_uint2big(*((unsigned int*) unsigned_char_array));
        temp_value = INT2FIX(32);
        for (index = 4; index < num_bytes; index += 4) {
          return_value = rb_big_lshift(return_value, temp_value);
          if (FIXNUM_P(return_value)) {
            signed_long_value = FIX2LONG(return_value);
            return_value = rb_int2big(signed_long_value);
          }
          return_value = rb_big_plus(return_value, UINT2NUM(*((unsigned int*) &(unsigned_char_array[index]))));
          if (FIXNUM_P(return_value)) {
            signed_long_value = FIX2LONG(return_value);
            return_value = rb_int2big(signed_long_value);
          }
        }
        return_value = rb_big_norm(return_value);
      }

      free(unsigned_char_array);
    }

  } else if (param_data_type == symbol_FLOAT) {
    /*##########################
     *# Handle :FLOAT data type
     *##########################*/

    if (BYTE_ALIGNED(bit_offset)) {
      switch (bit_size) {
        case 32:
          read_aligned_32(lower_bound, upper_bound, param_endianness, buffer, (unsigned char*) &float_value);
          return_value = rb_float_new(float_value);
          break;

        case 64:
          read_aligned_64(lower_bound, upper_bound, param_endianness, buffer, (unsigned char*) &double_value);
          return_value = rb_float_new(double_value);
          break;

        default:
          rb_raise(rb_eArgError, "bit_size is %d but must be 32 or 64 for data_type %s", given_bit_size, RSTRING_PTR(rb_funcall(param_data_type, id_method_to_s, 0)));
          break;
      };
    } else {
      rb_raise(rb_eArgError, "bit_offset %d is not byte aligned for data_type %s", given_bit_offset, RSTRING_PTR(rb_funcall(param_data_type, id_method_to_s, 0)));
    }

  } else {
    /*############################
     *# Handle Unknown data types
     *############################*/

    rb_raise(rb_eArgError, "data_type %s is not recognized", RSTRING_PTR(rb_funcall(param_data_type, id_method_to_s, 0)));
  }

  return return_value;
}

static VALUE check_overflow(VALUE value, int bit_size, VALUE data_type, VALUE overflow)
{
  volatile VALUE hex_max_value = Qnil;
  volatile VALUE max_value = Qnil;
  volatile VALUE min_value = INT2NUM(0); /* Default for UINT cases */

  switch (bit_size) {
    case 8:
      hex_max_value = MAX_UINT8;
      if (data_type == symbol_INT) {
        min_value = MIN_INT8;
        max_value = MAX_INT8;
      } else {
        max_value = MAX_UINT8;
      }
      break;
    case 16:
      hex_max_value = MAX_UINT16;
      if (data_type == symbol_INT) {
        min_value = MIN_INT16;
        max_value = MAX_INT16;
      } else {
        max_value = MAX_UINT16;
      }
      break;
    case 32:
      hex_max_value = MAX_UINT32;
      if (data_type == symbol_INT) {
        min_value = MIN_INT32;
        max_value = MAX_INT32;
      } else {
        max_value = MAX_UINT32;
      }
      break;
    case 64:
      hex_max_value = MAX_UINT64;
      if (data_type == symbol_INT) {
        min_value = MIN_INT64;
        max_value = MAX_INT64;
      } else {
        max_value = MAX_UINT64;
      }
      break;
    default: /* Bitfield */
      if (data_type == symbol_INT) {
        /* Note signed integers must allow up to the maximum unsigned value to support values given in hex */
        if (bit_size > 1) {
          max_value = rb_big_pow(TO_BIGNUM(INT2NUM(2)), INT2NUM(bit_size - 1));
          /* min_value = -(2 ** bit_size - 1) */
          min_value = rb_big_minus(TO_BIGNUM(INT2NUM(0)), max_value);
          /* max_value = (2 ** bit_size - 1) - 1 */
          max_value = rb_big_minus(TO_BIGNUM(max_value), INT2NUM(1));
          /* hex_max_value = (2 ** bit_size) - 1 */
          hex_max_value = rb_big_pow(TO_BIGNUM(INT2NUM(2)), INT2NUM(bit_size));
          hex_max_value = rb_big_minus(TO_BIGNUM(hex_max_value), INT2NUM(1));
        } else { /* 1-bit signed */
          min_value = INT2NUM(-1);
          max_value = INT2NUM(1);
          hex_max_value = INT2NUM(1);
        }
      } else {
        max_value = rb_big_pow(TO_BIGNUM(INT2NUM(2)), INT2NUM(bit_size));
        max_value = rb_big_minus(TO_BIGNUM(max_value), INT2NUM(1));
        hex_max_value = max_value;
      }
      break;
  }
  /* Convert all to Bignum objects so we can do the math the same way */
  value = TO_BIGNUM(value);
  min_value = TO_BIGNUM(min_value);
  max_value = TO_BIGNUM(max_value);
  hex_max_value = TO_BIGNUM(hex_max_value);

  if (overflow == symbol_TRUNCATE) {
    /* Note this will always convert to unsigned equivalent for signed integers */
    value = rb_big_modulo(value, TO_BIGNUM(rb_big_plus(hex_max_value, INT2NUM(1))));
  } else {
    if (rb_big_cmp(value, max_value) == INT2FIX(1)) {
      if (overflow == symbol_SATURATE) {
        value = max_value;
      } else {
        if ((overflow == symbol_ERROR) || (rb_big_cmp(value, hex_max_value) == INT2FIX(1))) {
          rb_raise(rb_eArgError, "value of %s invalid for %d-bit %s",
              RSTRING_PTR(rb_funcall(value, id_method_to_s, 0)),
              bit_size,
              RSTRING_PTR(rb_funcall(data_type, id_method_to_s, 0)));
        }
      }
    } else if (rb_big_cmp(value, min_value) == INT2FIX(-1)) {
      if (overflow == symbol_SATURATE) {
        value = min_value;
      } else {
        rb_raise(rb_eArgError, "value of %s invalid for %d-bit %s",
              RSTRING_PTR(rb_funcall(value, id_method_to_s, 0)),
              bit_size,
              RSTRING_PTR(rb_funcall(data_type, id_method_to_s, 0)));
      }
    }
  }

  return rb_big_norm(value);
}

/*
 * Writes binary data of any data type to a buffer
 *
 * @param bit_offset [Integer] Bit offset to the start of the item. A
 *   negative number means to offset from the end of the buffer.
 * @param bit_size [Integer] Size of the item in bits
 * @param data_type [Symbol] {DATA_TYPES}
 * @param buffer [String] Binary string buffer to read from
 * @param endianness [Symbol] {ENDIANNESS}
 * @return [Integer] value read from the buffer
 */
static VALUE binary_accessor_write(VALUE self, VALUE value, VALUE param_bit_offset, VALUE param_bit_size, VALUE param_data_type, VALUE param_buffer, VALUE param_endianness, VALUE param_overflow)
{
  /* Convert Parameters to C Data Types */
  int bit_offset = NUM2INT(param_bit_offset);
  int bit_size = NUM2INT(param_bit_size);
  /* Local Variables */
  int given_bit_offset = bit_offset;
  int given_bit_size = bit_size;
  int upper_bound = 0;
  int lower_bound = 0;
  int end_bytes = 0;
  int old_upper_bound = 0;
  int byte_size = 0;

  unsigned long long c_value = 0;
  float float_value = 0.0;
  double double_value = 0.0;

  unsigned char* buffer = NULL;
  long buffer_length = 0;
  long value_length = 0;
  volatile VALUE temp_shift = Qnil;
  volatile VALUE temp_mask = Qnil;
  volatile VALUE temp_result = Qnil;

  int string_length = 0;
  unsigned char* unsigned_char_array = NULL;
  int array_length = 0;
  int shift_needed = 0;
  int shift_count = 0;
  int index = 0;
  int num_bits = 0;
  int num_bytes = 0;
  int num_words = 0;

  Check_Type(param_buffer, T_STRING);
  buffer = (unsigned char*) RSTRING_PTR(param_buffer);
  buffer_length = RSTRING_LEN(param_buffer);

  check_bit_offset_and_size(self, symbol_write, param_bit_offset, param_bit_size,
      param_data_type, param_buffer, &bit_offset);

  /* If passed a negative bit size with strings or blocks
   * recalculate based on the value length in bytes */
  if ((bit_size <= 0) && ((param_data_type == symbol_STRING) || (param_data_type == symbol_BLOCK))) {
    if (!RB_TYPE_P(value, T_STRING)) {
      value = rb_funcall(value, id_method_to_s, 0);
    }
    bit_size = RSTRING_LEN(value) * 8;
  }

  if ((!check_bounds_and_buffer_size(bit_offset, bit_size, buffer_length, param_endianness, param_data_type, &lower_bound, &upper_bound)) && (given_bit_size > 0))
  {
    rb_funcall(self, id_method_raise_buffer_error, 5, symbol_write, param_buffer, param_data_type, param_bit_offset, param_bit_size);
  }

  /* Check overflow type */
  if ((param_overflow != symbol_TRUNCATE) &&
      (param_overflow != symbol_SATURATE) &&
      (param_overflow != symbol_ERROR) &&
      (param_overflow != symbol_ERROR_ALLOW_HEX)) {
    rb_raise(rb_eArgError, "unknown overflow type %s", RSTRING_PTR(rb_funcall(param_overflow, id_method_to_s, 0)));
  }

  if ((param_data_type == symbol_STRING) || (param_data_type == symbol_BLOCK)) {
    /*#######################################
     *# Handle :STRING and :BLOCK data types
     *#######################################*/
    /* Force value to be a string */
    if (!RB_TYPE_P(value, T_STRING)) {
      value = rb_funcall(value, id_method_to_s, 0);
    }

    if (BYTE_ALIGNED(bit_offset)) {
      value_length = RSTRING_LEN(value);

      if (given_bit_size <= 0) {
        end_bytes = -(given_bit_size / 8);
        old_upper_bound = buffer_length - 1 - end_bytes;
        /* Lower bound + end_bytes can never be more than 1 byte outside of the given buffer */
        if ((lower_bound + end_bytes) > buffer_length)
        {
          rb_funcall(self, id_method_raise_buffer_error, 5, symbol_write, param_buffer, param_data_type, param_bit_offset, param_bit_size);
        }

        if (old_upper_bound < lower_bound) {
          /* String was completely empty */
          if (end_bytes > 0) {
            /* Preserve bytes at end of buffer */
            rb_str_concat(param_buffer, rb_str_times(ZERO_STRING, INT2FIX(value_length)));
            buffer = (unsigned char*) RSTRING_PTR(param_buffer);
            memmove((buffer + lower_bound + value_length), (buffer + lower_bound), end_bytes);
          }
        } else if (bit_size == 0) {
          /* Remove entire string */
          rb_str_update(param_buffer, lower_bound, old_upper_bound - lower_bound + 1, rb_str_new2(""));
        } else if (upper_bound < old_upper_bound) {
          /* Remove extra bytes from old string */
          rb_str_update(param_buffer, upper_bound + 1, old_upper_bound - upper_bound, rb_str_new2(""));
        } else if ((upper_bound > old_upper_bound) && (end_bytes > 0)) {
          /* Preserve bytes at end of buffer */
          rb_str_concat(param_buffer, rb_str_times(ZERO_STRING, INT2FIX(upper_bound - old_upper_bound)));
          buffer = (unsigned char*) RSTRING_PTR(param_buffer);
          memmove((buffer + upper_bound + 1), (buffer + old_upper_bound + 1), end_bytes);
        }
      } else {
        byte_size = bit_size / 8;
        if (value_length < byte_size) {
          /* Pad the requested size with zeros.
           * Tell Ruby we are going to be modifying the buffer with a memset */
          rb_str_modify(param_buffer);
          memset(RSTRING_PTR(param_buffer) + lower_bound + value_length, 0, byte_size - value_length);
        } else if (value_length > byte_size) {
          if (param_overflow == symbol_TRUNCATE) {
            /* Resize the value to fit the field */
            rb_str_update(value, byte_size, RSTRING_LEN(value) - byte_size, rb_str_new2(""));
          } else {
            rb_raise(rb_eArgError, "value of %d bytes does not fit into %d bytes for data_type %s", (int)value_length, byte_size, RSTRING_PTR(rb_funcall(param_data_type, id_method_to_s, 0)));
          }
        }
      }
      if (bit_size != 0) {
        rb_str_update(param_buffer, lower_bound, RSTRING_LEN(value), value);
      }
    } else {
      rb_raise(rb_eArgError, "bit_offset %d is not byte aligned for data_type %s", given_bit_offset, RSTRING_PTR(rb_funcall(param_data_type, id_method_to_s, 0)));
    }

  } else if ((param_data_type == symbol_INT) || (param_data_type == symbol_UINT)) {
    /*###################################
     *# Handle :INT data type
     *###################################*/
    value = rb_funcall(rb_mKernel, id_method_Integer, 1, value);

    if ((BYTE_ALIGNED(bit_offset)) && (even_bit_size(bit_size)))
    {
      /*###########################################################
       *# Handle byte-aligned 8, 16, 32, and 64 bit
       *###########################################################*/

      value = check_overflow(value, bit_size, param_data_type, param_overflow);
      switch (bit_size) {
        case 8:
          c_value = NUM2CHR(value);
          break;
        case 16:
          c_value = NUM2USHORT(value);
          break;
        case 32:
          c_value = NUM2UINT(value);
          break;
        case 64:
          c_value = NUM2ULL(value);
          break;
      }
      /* If the passed endianess doesn't match the host we reverse the bytes.
       * Then shift the result over so it's at the bottom of the long long value. */
      if (param_endianness != HOST_ENDIANNESS) {
        reverse_bytes((unsigned char *)&c_value, 8);
        c_value = (c_value >> (64 - bit_size));
      }
      /* Tell Ruby we are going to be modifying the buffer with a memcpy */
      rb_str_modify(param_buffer);
      memcpy((RSTRING_PTR(param_buffer) + lower_bound), &c_value, bit_size / 8);

    } else {
      /*###########################################################
       *# Handle bit fields
       *###########################################################*/
      value = check_overflow(value, bit_size, param_data_type, param_overflow);

      string_length = ((bit_size - 1)/ 8) + 1;
      array_length = string_length + 4; /* Required number of bytes plus slack */
      unsigned_char_array = (unsigned char*) malloc(array_length);

      num_words = ((string_length - 1) / 4) + 1;
      num_bytes = num_words * 4;
      num_bits = num_bytes * 8;
      shift_needed = num_bits - bit_size;
      shift_count = shift_needed / 8;
      shift_needed = shift_needed % 8;

      /* Convert value into array of bytes */
      if (bit_size <= 30) {
        *((int *)unsigned_char_array) = FIX2INT(value);
      } else if (bit_size <= 32) {
        *((unsigned int *)unsigned_char_array) = NUM2UINT(value);
      } else {
        temp_mask = UINT2NUM(0xFFFFFFFF);
        temp_shift = INT2FIX(32);
        temp_result = rb_big_and(TO_BIGNUM(value), temp_mask);
        /* Work around bug where rb_big_and will return Qfalse if given a first parameter of 0 */
        if (temp_result == Qfalse) { temp_result = INT2FIX(0); }
        *((unsigned int *)&(unsigned_char_array[num_bytes - 4])) = NUM2UINT(temp_result);
        for (index = num_bytes - 8; index >= 0; index -= 4) {
          value = rb_big_rshift(TO_BIGNUM(value), temp_shift);
          temp_result = rb_big_and(TO_BIGNUM(value), temp_mask);
          /* Work around bug where rb_big_and will return Qfalse if given a first parameter of 0 */
          if (temp_result == Qfalse) { temp_result = INT2FIX(0); }
          *((unsigned int *)&(unsigned_char_array[index])) = NUM2UINT(temp_result);
        }
      }

      if (HOST_ENDIANNESS == symbol_LITTLE_ENDIAN) {
        for (index = 0; index < num_bytes; index += 4) {
          reverse_bytes(&(unsigned_char_array[index]), 4);
        }
      }

      for (index = 0; index < shift_count; index++) {
        left_shift_byte_array(unsigned_char_array, num_bytes, 8);
      }

      if (shift_needed > 0) {
        left_shift_byte_array(unsigned_char_array, num_bytes, shift_needed);
      }

      rb_str_modify(param_buffer);
      write_bitfield(lower_bound, upper_bound, bit_offset, bit_size, given_bit_offset, given_bit_size, param_endianness, (unsigned char*) RSTRING_PTR(param_buffer), (int)buffer_length, unsigned_char_array);

      free(unsigned_char_array);
    }

  } else if (param_data_type == symbol_FLOAT) {
    /*##########################
     *# Handle :FLOAT data type
     *##########################*/
    value = rb_funcall(rb_mKernel, id_method_Float, 1, value);

    if (BYTE_ALIGNED(bit_offset)) {
      switch (bit_size) {
        case 32:
          float_value = (float)RFLOAT_VALUE(value);
          if (param_endianness != HOST_ENDIANNESS) {
            reverse_bytes((unsigned char *)&float_value, 4);
          }
          rb_str_modify(param_buffer);
          memcpy((RSTRING_PTR(param_buffer) + lower_bound), &float_value, 4);
          break;

        case 64:
          double_value = RFLOAT_VALUE(value);
          if (param_endianness != HOST_ENDIANNESS) {
            reverse_bytes((unsigned char *)&double_value, 8);
          }
          rb_str_modify(param_buffer);
          memcpy((RSTRING_PTR(param_buffer) + lower_bound), &double_value, 8);
          break;

        default:
          rb_raise(rb_eArgError, "bit_size is %d but must be 32 or 64 for data_type %s", given_bit_size, RSTRING_PTR(rb_funcall(param_data_type, id_method_to_s, 0)));
          break;
      };
    } else {
      rb_raise(rb_eArgError, "bit_offset %d is not byte aligned for data_type %s", given_bit_offset, RSTRING_PTR(rb_funcall(param_data_type, id_method_to_s, 0)));
    }

  } else {
    /*############################
     *# Handle Unknown data types
     *############################*/

    rb_raise(rb_eArgError, "data_type %s is not recognized", RSTRING_PTR(rb_funcall(param_data_type, id_method_to_s, 0)));
  }

  return value;
}

/*
 * Returns the actual length as an integer.
 *
 *   get_int_length(self) #=> 324
 */
static int get_int_length(VALUE self)
{
  volatile VALUE buffer = rb_ivar_get(self, id_ivar_buffer);
  if (RTEST(buffer)) {
    return (int)RSTRING_LEN(buffer);
  } else {
    return 0;
  }
}

/*
 * Returns the actual structure length.
 *
 *   structure.length #=> 324
 */
static VALUE structure_length(VALUE self) {
  return INT2FIX(get_int_length(self));
}

static VALUE read_item_internal(VALUE self, VALUE item, VALUE buffer) {
  volatile VALUE bit_offset = Qnil;
  volatile VALUE bit_size = Qnil;
  volatile VALUE data_type = Qnil;
  volatile VALUE array_size = Qnil;
  volatile VALUE endianness = Qnil;

  data_type = rb_ivar_get(item, id_ivar_data_type);
  if (data_type == symbol_DERIVED) {
    return Qnil;
  }

  if (RTEST(buffer)) {
    bit_offset = rb_ivar_get(item, id_ivar_bit_offset);
    bit_size = rb_ivar_get(item, id_ivar_bit_size);
    array_size = rb_ivar_get(item, id_ivar_array_size);
    endianness = rb_ivar_get(item, id_ivar_endianness);
    if (RTEST(array_size)) {
      return rb_funcall(cBinaryAccessor, id_method_read_array, 6, bit_offset, bit_size, data_type, array_size, buffer, endianness);
    } else {
      return binary_accessor_read(cBinaryAccessor, bit_offset, bit_size, data_type, buffer, endianness);
    }
  } else {
    rb_raise(rb_eRuntimeError, "No buffer given to read_item");
  }
}

/*
 * Read an item in the structure
 *
 * @param item [StructureItem] Instance of StructureItem or one of its subclasses
 * @param value_type [Symbol] Not used. Subclasses should overload this
 *   parameter to check whether to perform conversions on the item.
 * @param buffer [String] The binary buffer to read the item from
 * @return Value based on the item definition. This could be a string, integer,
 *   float, or array of values.
 */
static VALUE read_item(int argc, VALUE* argv, VALUE self)
{
  volatile VALUE item = Qnil;
  volatile VALUE buffer = Qnil;

  switch (argc)
  {
    case 1:
    case 2:
      item = argv[0];
      buffer = rb_ivar_get(self, id_ivar_buffer);
      break;
    case 3:
      item = argv[0];
      buffer = argv[2];
      break;
    default:
      /* Invalid number of arguments given */
      rb_raise(rb_eArgError, "wrong number of arguments (%d for 1..3)", argc);
      break;
  };

  return read_item_internal(self, item, buffer);
}

/*
 * Comparison Operator based on bit_offset. This means that StructureItems
 * with different names or bit sizes are equal if they have the same bit
 * offset.
 */
static VALUE structure_item_spaceship(VALUE self, VALUE other_item) {
  int bit_offset = 0;
  int other_bit_offset = 0;
  int bit_size = 0;
  int other_bit_size = 0;
  int create_index = 0;
  int other_create_index = 0;
  int have_create_index = 0;
  volatile VALUE v_create_index = Qnil;
  volatile VALUE v_other_create_index = Qnil;

  if (!RTEST(rb_funcall(other_item, id_method_kind_of, 1, cStructureItem))) {
    return Qnil;
  }

  bit_offset = FIX2INT(rb_ivar_get(self, id_ivar_bit_offset));
  other_bit_offset = FIX2INT(rb_ivar_get(other_item, id_ivar_bit_offset));

  v_create_index = rb_ivar_get(self, id_ivar_create_index);
  v_other_create_index = rb_ivar_get(other_item, id_ivar_create_index);
  if (RTEST(v_create_index) && RTEST(v_other_create_index)) {
    create_index = FIX2INT(v_create_index);
    other_create_index = FIX2INT(v_other_create_index);
    have_create_index = 1;
  }

  /* Handle same bit offset case */
  if ((bit_offset == 0) && (other_bit_offset == 0)) {
    /* Both bit_offsets are 0 so sort by bit_size
      * This allows derived items with bit_size of 0 to be listed first
      * Compare based on bit size */
    bit_size = FIX2INT(rb_ivar_get(self, id_ivar_bit_size));
    other_bit_size = FIX2INT(rb_ivar_get(other_item, id_ivar_bit_size));
    if (bit_size == other_bit_size) {
      if (have_create_index) {
        if (create_index <= other_create_index) {
          return INT2FIX(-1);
        } else {
          return INT2FIX(1);
        }
      } else {
        return INT2FIX(0);
      }
    } if (bit_size < other_bit_size) {
      return INT2FIX(-1);
    } else {
      return INT2FIX(1);
    }
  }

  /* Handle different bit offsets */
  if (((bit_offset >= 0) && (other_bit_offset >= 0)) || ((bit_offset < 0) && (other_bit_offset < 0))) {
    /* Both Have Same Sign */
    if (bit_offset == other_bit_offset) {
      if (have_create_index) {
        if (create_index <= other_create_index) {
          return INT2FIX(-1);
        } else {
          return INT2FIX(1);
        }
      } else {
        return INT2FIX(0);
      }
    } else if (bit_offset < other_bit_offset) {
      return INT2FIX(-1);
    } else {
      return INT2FIX(1);
    }
  } else {
    /* Different Signs */
    if (bit_offset == other_bit_offset) {
      if (have_create_index) {
        if (create_index <= other_create_index) {
          return INT2FIX(-1);
        } else {
          return INT2FIX(1);
        }
      } else {
        return INT2FIX(0);
      }
    } else if (bit_offset < other_bit_offset) {
      return INT2FIX(1);
    } else {
      return INT2FIX(-1);
    }
  }
}

/* Structure constructor
 *
 * @param default_endianness [Symbol] Must be one of
 *   {BinaryAccessor::ENDIANNESS}. By default it uses
 *   BinaryAccessor::HOST_ENDIANNESS to determine the endianness of the host platform.
 * @param buffer [String] Buffer used to store the structure
 * @param item_class [Class] Class used to instantiate new structure items.
 *   Must be StructureItem or one of its subclasses.
 */
static VALUE structure_initialize(int argc, VALUE* argv, VALUE self) {
  volatile VALUE default_endianness = Qnil;
  volatile VALUE buffer = Qnil;
  volatile VALUE item_class = Qnil;

  switch (argc)
  {
    case 0:
      default_endianness = HOST_ENDIANNESS;
      buffer = rb_str_new2("");
      item_class = cStructureItem;
      break;
    case 1:
      default_endianness = argv[0];
      buffer = rb_str_new2("");
      item_class = cStructureItem;
      break;
    case 2:
      default_endianness = argv[0];
      buffer = argv[1];
      item_class = cStructureItem;
      break;
    case 3:
      default_endianness = argv[0];
      buffer = argv[1];
      item_class = argv[2];
      break;
    default:
      /* Invalid number of arguments given */
      rb_raise(rb_eArgError, "wrong number of arguments (%d for 0..3)", argc);
      break;
  };

  if ((default_endianness == symbol_BIG_ENDIAN) || (default_endianness == symbol_LITTLE_ENDIAN)) {
    rb_ivar_set(self, id_ivar_default_endianness, default_endianness);
    if (RTEST(buffer)) {
      Check_Type(buffer, T_STRING);
      rb_funcall(buffer, id_method_force_encoding, 1, ASCII_8BIT_STRING);
      rb_ivar_set(self, id_ivar_buffer, buffer);
    } else {
      rb_ivar_set(self, id_ivar_buffer, Qnil);
    }
    rb_ivar_set(self, id_ivar_item_class, item_class);
    rb_ivar_set(self, id_ivar_items, rb_hash_new());
    rb_ivar_set(self, id_ivar_sorted_items, rb_ary_new());
    rb_ivar_set(self, id_ivar_defined_length, INT2FIX(0));
    rb_ivar_set(self, id_ivar_defined_length_bits, INT2FIX(0));
    rb_ivar_set(self, id_ivar_pos_bit_size, INT2FIX(0));
    rb_ivar_set(self, id_ivar_neg_bit_size, INT2FIX(0));
    rb_ivar_set(self, id_ivar_fixed_size, Qtrue);
    rb_ivar_set(self, id_ivar_short_buffer_allowed, Qfalse);
    rb_ivar_set(self, id_ivar_mutex, Qnil);
  } else {
    rb_raise(rb_eArgError, "Unrecognized endianness: %s - Must be :BIG_ENDIAN or :LITTLE_ENDIAN", RSTRING_PTR(rb_funcall(default_endianness, id_method_to_s, 0)));
  }

  return self;
}

/*
 * Resize the buffer at least the defined length of the structure
 */
static VALUE resize_buffer(VALUE self)
{
  volatile VALUE buffer = rb_ivar_get(self, id_ivar_buffer);
  if (RTEST(buffer)) {
    volatile VALUE value_defined_length = rb_ivar_get(self, id_ivar_defined_length);
    long defined_length = FIX2INT(value_defined_length);
    long current_length = RSTRING_LEN(buffer);

    /* Extend data size */
    if (current_length < defined_length)
    {
      rb_str_concat(buffer, rb_str_times(ZERO_STRING, INT2FIX(defined_length - current_length)));
    }
  }

  return self;
}

/*
 * Initialize all Packet methods
 */
void Init_structure (void)
{
  int zero = 0;
  volatile VALUE zero_string = Qnil;
  volatile VALUE ascii_8bit_string = Qnil;

  mCosmos = rb_define_module("Cosmos");
  cBinaryAccessor = rb_define_class_under(mCosmos, "BinaryAccessor", rb_cObject);

  id_method_to_s = rb_intern("to_s");
  id_method_raise_buffer_error = rb_intern("raise_buffer_error");
  id_method_read_array = rb_intern("read_array");
  id_method_force_encoding = rb_intern("force_encoding");
  id_method_freeze = rb_intern("freeze");
  id_method_slice = rb_intern("slice");
  id_method_reverse = rb_intern("reverse");
  id_method_Integer = rb_intern("Integer");
  id_method_Float = rb_intern("Float");
  id_method_kind_of = rb_intern("kind_of?");

  MIN_INT8 = INT2NUM(-128);
  MAX_INT8 = INT2NUM(127);
  MAX_UINT8 = INT2NUM(255);
  MIN_INT16 = INT2NUM(-32768);
  MAX_INT16 = INT2NUM(32767);
  MAX_UINT16 = INT2NUM(65535);
  MIN_INT32  = rb_big_pow(TO_BIGNUM(INT2NUM(2)), INT2NUM(31));
  MIN_INT32  = rb_big_minus(TO_BIGNUM(INT2NUM(0)), MIN_INT32);
  MAX_INT32  = rb_big_pow(TO_BIGNUM(INT2NUM(2)), INT2NUM(31));
  MAX_INT32  = rb_big_minus(TO_BIGNUM(MAX_INT32), INT2NUM(1));
  MAX_UINT32 = rb_big_pow(TO_BIGNUM(INT2NUM(2)), INT2NUM(32));
  MAX_UINT32 = rb_big_minus(TO_BIGNUM(MAX_UINT32), INT2NUM(1));
  MIN_INT64  = rb_big_pow(TO_BIGNUM(INT2NUM(2)), INT2NUM(63));
  MIN_INT64  = rb_big_minus(TO_BIGNUM(INT2NUM(0)), MIN_INT64);
  MAX_INT64  = rb_big_pow(TO_BIGNUM(INT2NUM(2)), INT2NUM(63));
  MAX_INT64  = rb_big_minus(TO_BIGNUM(MAX_INT64), INT2NUM(1));
  MAX_UINT64 = rb_big_pow(TO_BIGNUM(INT2NUM(2)), INT2NUM(64));
  MAX_UINT64 = rb_big_minus(TO_BIGNUM(MAX_UINT64), INT2NUM(1));
  rb_define_const(cBinaryAccessor, "MIN_INT8", MIN_INT8);
  rb_define_const(cBinaryAccessor, "MAX_INT8", MAX_INT8);
  rb_define_const(cBinaryAccessor, "MAX_UINT8", MAX_UINT8);
  rb_define_const(cBinaryAccessor, "MIN_INT16", MIN_INT16);
  rb_define_const(cBinaryAccessor, "MAX_INT16", MAX_INT16);
  rb_define_const(cBinaryAccessor, "MAX_UINT16", MAX_UINT16);
  rb_define_const(cBinaryAccessor, "MIN_INT32", MIN_INT32);
  rb_define_const(cBinaryAccessor, "MAX_INT32", MAX_INT32);
  rb_define_const(cBinaryAccessor, "MAX_UINT32", MAX_UINT32);
  rb_define_const(cBinaryAccessor, "MIN_INT64", MIN_INT64);
  rb_define_const(cBinaryAccessor, "MAX_INT64", MAX_INT64);
  rb_define_const(cBinaryAccessor, "MAX_UINT64", MAX_UINT64);

  id_ivar_buffer = rb_intern("@buffer");
  id_ivar_bit_offset = rb_intern("@bit_offset");
  id_ivar_bit_size = rb_intern("@bit_size");
  id_ivar_array_size = rb_intern("@array_size");
  id_ivar_endianness = rb_intern("@endianness");
  id_ivar_data_type = rb_intern("@data_type");
  id_ivar_default_endianness = rb_intern("@default_endianness");
  id_ivar_item_class = rb_intern("@item_class");
  id_ivar_items = rb_intern("@items");
  id_ivar_sorted_items = rb_intern("@sorted_items");
  id_ivar_defined_length = rb_intern("@defined_length");
  id_ivar_defined_length_bits = rb_intern("@defined_length_bits");
  id_ivar_pos_bit_size = rb_intern("@pos_bit_size");
  id_ivar_neg_bit_size = rb_intern("@neg_bit_size");
  id_ivar_fixed_size = rb_intern("@fixed_size");
  id_ivar_short_buffer_allowed = rb_intern("@short_buffer_allowed");
  id_ivar_mutex = rb_intern("@mutex");
  id_ivar_create_index = rb_intern("@create_index");

  symbol_LITTLE_ENDIAN = ID2SYM(rb_intern("LITTLE_ENDIAN"));
  symbol_BIG_ENDIAN = ID2SYM(rb_intern("BIG_ENDIAN"));
  symbol_INT = ID2SYM(rb_intern("INT"));
  symbol_UINT = ID2SYM(rb_intern("UINT"));
  symbol_FLOAT = ID2SYM(rb_intern("FLOAT"));
  symbol_STRING = ID2SYM(rb_intern("STRING"));
  symbol_BLOCK = ID2SYM(rb_intern("BLOCK"));
  symbol_DERIVED = ID2SYM(rb_intern("DERIVED"));
  symbol_read = ID2SYM(rb_intern("read"));
  symbol_write = ID2SYM(rb_intern("write"));
  symbol_TRUNCATE = ID2SYM(rb_intern("TRUNCATE"));
  symbol_SATURATE = ID2SYM(rb_intern("SATURATE"));
  symbol_ERROR = ID2SYM(rb_intern("ERROR"));
  symbol_ERROR_ALLOW_HEX = ID2SYM(rb_intern("ERROR_ALLOW_HEX"));

  if ((*((char *) &endianness_check)) == 1) {
    HOST_ENDIANNESS = symbol_LITTLE_ENDIAN;
  } else {
    HOST_ENDIANNESS = symbol_BIG_ENDIAN;
  }

  rb_define_singleton_method(cBinaryAccessor, "read", binary_accessor_read, 5);
  rb_define_singleton_method(cBinaryAccessor, "write", binary_accessor_write, 7);

  cStructure = rb_define_class_under(mCosmos, "Structure", rb_cObject);
  id_const_ZERO_STRING = rb_intern("ZERO_STRING");
  zero_string = rb_str_new((char*) &zero, 1);
  rb_funcall(zero_string, id_method_freeze, 0);
  rb_const_set(cStructure, id_const_ZERO_STRING, zero_string);
  ZERO_STRING = rb_const_get(cStructure, id_const_ZERO_STRING);
  id_const_ASCII_8BIT_STRING = rb_intern("ASCII_8BIT_STRING");
  ascii_8bit_string = rb_str_new2("ASCII-8BIT");
  rb_funcall(ascii_8bit_string, id_method_freeze, 0);
  rb_const_set(cStructure, id_const_ASCII_8BIT_STRING, ascii_8bit_string);
  ASCII_8BIT_STRING = rb_const_get(cStructure, id_const_ASCII_8BIT_STRING);
  rb_define_method(cStructure, "initialize", structure_initialize, -1);
  rb_define_method(cStructure, "length", structure_length, 0);
  rb_define_method(cStructure, "read_item", read_item, -1);
  rb_define_method(cStructure, "resize_buffer", resize_buffer, 0);

  cStructureItem = rb_define_class_under(mCosmos, "StructureItem", rb_cObject);
  rb_define_method(cStructureItem, "<=>", structure_item_spaceship, 1);
}
