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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder
*/

#include "ruby.h"
#include "stdio.h"

VALUE mCosmos;
VALUE cCrc;
VALUE cCrc16;
VALUE cCrc32;
VALUE cCrc64;

static ID id_ivar_seed = 0;
static ID id_ivar_xor = 0;
static ID id_ivar_reflect = 0;
static ID id_ivar_table = 0;

static const unsigned char BIT_REVERSE_TABLE[] =
    {
        0x00, 0x80, 0x40, 0xC0, 0x20, 0xA0, 0x60, 0xE0, 0x10, 0x90, 0x50, 0xD0, 0x30, 0xB0, 0x70, 0xF0,
        0x08, 0x88, 0x48, 0xC8, 0x28, 0xA8, 0x68, 0xE8, 0x18, 0x98, 0x58, 0xD8, 0x38, 0xB8, 0x78, 0xF8,
        0x04, 0x84, 0x44, 0xC4, 0x24, 0xA4, 0x64, 0xE4, 0x14, 0x94, 0x54, 0xD4, 0x34, 0xB4, 0x74, 0xF4,
        0x0C, 0x8C, 0x4C, 0xCC, 0x2C, 0xAC, 0x6C, 0xEC, 0x1C, 0x9C, 0x5C, 0xDC, 0x3C, 0xBC, 0x7C, 0xFC,
        0x02, 0x82, 0x42, 0xC2, 0x22, 0xA2, 0x62, 0xE2, 0x12, 0x92, 0x52, 0xD2, 0x32, 0xB2, 0x72, 0xF2,
        0x0A, 0x8A, 0x4A, 0xCA, 0x2A, 0xAA, 0x6A, 0xEA, 0x1A, 0x9A, 0x5A, 0xDA, 0x3A, 0xBA, 0x7A, 0xFA,
        0x06, 0x86, 0x46, 0xC6, 0x26, 0xA6, 0x66, 0xE6, 0x16, 0x96, 0x56, 0xD6, 0x36, 0xB6, 0x76, 0xF6,
        0x0E, 0x8E, 0x4E, 0xCE, 0x2E, 0xAE, 0x6E, 0xEE, 0x1E, 0x9E, 0x5E, 0xDE, 0x3E, 0xBE, 0x7E, 0xFE,
        0x01, 0x81, 0x41, 0xC1, 0x21, 0xA1, 0x61, 0xE1, 0x11, 0x91, 0x51, 0xD1, 0x31, 0xB1, 0x71, 0xF1,
        0x09, 0x89, 0x49, 0xC9, 0x29, 0xA9, 0x69, 0xE9, 0x19, 0x99, 0x59, 0xD9, 0x39, 0xB9, 0x79, 0xF9,
        0x05, 0x85, 0x45, 0xC5, 0x25, 0xA5, 0x65, 0xE5, 0x15, 0x95, 0x55, 0xD5, 0x35, 0xB5, 0x75, 0xF5,
        0x0D, 0x8D, 0x4D, 0xCD, 0x2D, 0xAD, 0x6D, 0xED, 0x1D, 0x9D, 0x5D, 0xDD, 0x3D, 0xBD, 0x7D, 0xFD,
        0x03, 0x83, 0x43, 0xC3, 0x23, 0xA3, 0x63, 0xE3, 0x13, 0x93, 0x53, 0xD3, 0x33, 0xB3, 0x73, 0xF3,
        0x0B, 0x8B, 0x4B, 0xCB, 0x2B, 0xAB, 0x6B, 0xEB, 0x1B, 0x9B, 0x5B, 0xDB, 0x3B, 0xBB, 0x7B, 0xFB,
        0x07, 0x87, 0x47, 0xC7, 0x27, 0xA7, 0x67, 0xE7, 0x17, 0x97, 0x57, 0xD7, 0x37, 0xB7, 0x77, 0xF7,
        0x0F, 0x8F, 0x4F, 0xCF, 0x2F, 0xAF, 0x6F, 0xEF, 0x1F, 0x9F, 0x5F, 0xDF, 0x3F, 0xBF, 0x7F, 0xFF};

/*
 * Bit Reverse an unsigned char
 */
static unsigned char bit_reverse_8(unsigned char value)
{
  return BIT_REVERSE_TABLE[value];
}

/*
 * Bit Reverse an unsigned short
 */
static unsigned short bit_reverse_16(unsigned short value)
{
  return (BIT_REVERSE_TABLE[value & 0xff] << 8) |
         (BIT_REVERSE_TABLE[(value >> 8) & 0xff]);
}

/*
 * Bit Reverse an unsigned int
 */
static unsigned int bit_reverse_32(unsigned int value)
{
  return (BIT_REVERSE_TABLE[value & 0xff] << 24) |
         (BIT_REVERSE_TABLE[(value >> 8) & 0xff] << 16) |
         (BIT_REVERSE_TABLE[(value >> 16) & 0xff] << 8) |
         (BIT_REVERSE_TABLE[(value >> 24) & 0xff]);
}

/*
 * Bit Reverse an unsigned long long
 */
static unsigned long long bit_reverse_64(unsigned long long value)
{
  return ((unsigned long long)BIT_REVERSE_TABLE[value & 0x00000000000000ffULL] << 56) |
         ((unsigned long long)BIT_REVERSE_TABLE[(value >> 8) & 0x00000000000000ffULL] << 48) |
         ((unsigned long long)BIT_REVERSE_TABLE[(value >> 16) & 0x00000000000000ffULL] << 40) |
         ((unsigned long long)BIT_REVERSE_TABLE[(value >> 24) & 0x00000000000000ffULL] << 32) |
         ((unsigned long long)BIT_REVERSE_TABLE[(value >> 32) & 0x00000000000000ffULL] << 24) |
         ((unsigned long long)BIT_REVERSE_TABLE[(value >> 40) & 0x00000000000000ffULL] << 16) |
         ((unsigned long long)BIT_REVERSE_TABLE[(value >> 48) & 0x00000000000000ffULL] << 8) |
         ((unsigned long long)BIT_REVERSE_TABLE[(value >> 56) & 0x00000000000000ffULL]);
}

/*
 * Calculate a 16-bit CRC
 */
static VALUE crc16_calculate(int argc, VALUE *argv, VALUE self)
{
  volatile VALUE param_data = Qnil;
  volatile VALUE param_seed = Qnil;
  unsigned char *data = NULL;
  unsigned short *table = NULL;
  int i = 0;
  long length = 0;
  unsigned short crc = 0;

  switch (argc)
  {
  case 1:
    Check_Type(argv[0], T_STRING);
    param_data = argv[0];
    param_seed = rb_ivar_get(self, id_ivar_seed);
    break;
  case 2:
    Check_Type(argv[0], T_STRING);
    param_data = argv[0];
    if (argv[1] == Qnil)
    {
      param_seed = rb_ivar_get(self, id_ivar_seed);
    }
    else
    {
      param_seed = argv[1];
    }
    break;
  default:
    /* Invalid number of arguments given */
    rb_raise(rb_eArgError, "wrong number of arguments (%d for 1..2)", argc);
    break;
  };

  crc = NUM2UINT(param_seed);
  data = (unsigned char *)RSTRING_PTR(param_data);
  length = RSTRING_LEN(param_data);
  table = (unsigned short *)RSTRING_PTR(rb_ivar_get(self, id_ivar_table));

  if (RTEST(rb_ivar_get(self, id_ivar_reflect)))
  {
    for (i = 0; i < length; i++)
    {
      crc = (crc << 8) ^ table[(crc >> 8) ^ bit_reverse_8(data[i])];
    }

    if (RTEST(rb_ivar_get(self, id_ivar_xor)))
    {
      return UINT2NUM(bit_reverse_16(crc ^ 0xFFFF));
    }
    else
    {
      return UINT2NUM(bit_reverse_16(crc));
    }
  }
  else
  {
    for (i = 0; i < length; i++)
    {
      crc = (crc << 8) ^ table[(crc >> 8) ^ data[i]];
    }

    if (RTEST(rb_ivar_get(self, id_ivar_xor)))
    {
      return UINT2NUM(crc ^ 0xFFFF);
    }
    else
    {
      return UINT2NUM(crc);
    }
  }
}

/*
 * Calculate a 32-bit CRC
 */
static VALUE crc32_calculate(int argc, VALUE *argv, VALUE self)
{
  volatile VALUE param_data = Qnil;
  volatile VALUE param_seed = Qnil;
  unsigned char *data = NULL;
  unsigned int *table = NULL;
  int i = 0;
  long length = 0;
  unsigned int crc = 0;

  switch (argc)
  {
  case 1:
    Check_Type(argv[0], T_STRING);
    param_data = argv[0];
    param_seed = rb_ivar_get(self, id_ivar_seed);
    break;
  case 2:
    Check_Type(argv[0], T_STRING);
    param_data = argv[0];
    if (argv[1] == Qnil)
    {
      param_seed = rb_ivar_get(self, id_ivar_seed);
    }
    else
    {
      param_seed = argv[1];
    }
    break;
  default:
    /* Invalid number of arguments given */
    rb_raise(rb_eArgError, "wrong number of arguments (%d for 1..2)", argc);
    break;
  };

  crc = NUM2UINT(param_seed);
  data = (unsigned char *)RSTRING_PTR(param_data);
  length = RSTRING_LEN(param_data);
  table = (unsigned int *)RSTRING_PTR(rb_ivar_get(self, id_ivar_table));

  if (RTEST(rb_ivar_get(self, id_ivar_reflect)))
  {
    for (i = 0; i < length; i++)
    {
      crc = (crc << 8) ^ table[((crc >> 24) ^ bit_reverse_8(data[i])) & 0x000000FF];
    }

    if (RTEST(rb_ivar_get(self, id_ivar_xor)))
    {
      return UINT2NUM(bit_reverse_32(crc ^ 0xFFFFFFFF));
    }
    else
    {
      return UINT2NUM(bit_reverse_32(crc));
    }
  }
  else
  {
    for (i = 0; i < length; i++)
    {
      crc = (crc << 8) ^ table[((crc >> 24) ^ data[i]) & 0x000000FF];
    }

    if (RTEST(rb_ivar_get(self, id_ivar_xor)))
    {
      return UINT2NUM(crc ^ 0xFFFFFFFF);
    }
    else
    {
      return UINT2NUM(crc);
    }
  }
}

/*
 * Calculate a 64-bit CRC
 */
static VALUE crc64_calculate(int argc, VALUE *argv, VALUE self)
{
  volatile VALUE param_data = Qnil;
  volatile VALUE param_seed = Qnil;
  unsigned char *data = NULL;
  unsigned long long *table = NULL;
  int i = 0;
  long length = 0;
  unsigned long long crc = 0;

  switch (argc)
  {
  case 1:
    Check_Type(argv[0], T_STRING);
    param_data = argv[0];
    param_seed = rb_ivar_get(self, id_ivar_seed);
    break;
  case 2:
    Check_Type(argv[0], T_STRING);
    param_data = argv[0];
    if (argv[1] == Qnil)
    {
      param_seed = rb_ivar_get(self, id_ivar_seed);
    }
    else
    {
      param_seed = argv[1];
    }
    break;
  default:
    /* Invalid number of arguments given */
    rb_raise(rb_eArgError, "wrong number of arguments (%d for 1..2)", argc);
    break;
  };

  crc = NUM2ULL(param_seed);
  data = (unsigned char *)RSTRING_PTR(param_data);
  length = RSTRING_LEN(param_data);
  table = (unsigned long long *)RSTRING_PTR(rb_ivar_get(self, id_ivar_table));

  if (RTEST(rb_ivar_get(self, id_ivar_reflect)))
  {
    for (i = 0; i < length; i++)
    {
      crc = (crc << 8) ^ table[((crc >> 56) ^ bit_reverse_8(data[i])) & 0x00000000000000FFULL];
    }

    if (RTEST(rb_ivar_get(self, id_ivar_xor)))
    {
      return ULL2NUM(bit_reverse_64(crc ^ 0xFFFFFFFFFFFFFFFFULL));
    }
    else
    {
      return ULL2NUM(bit_reverse_64(crc));
    }
  }
  else
  {
    for (i = 0; i < length; i++)
    {
      crc = (crc << 8) ^ table[((crc >> 56) ^ data[i]) & 0x00000000000000FFULL];
    }

    if (RTEST(rb_ivar_get(self, id_ivar_xor)))
    {
      return ULL2NUM(crc ^ 0xFFFFFFFFFFFFFFFFULL);
    }
    else
    {
      return ULL2NUM(crc);
    }
  }
}

/*
 * Initialize methods for Crc
 */
void Init_crc()
{
  id_ivar_seed = rb_intern("@seed");
  id_ivar_xor = rb_intern("@xor");
  id_ivar_reflect = rb_intern("@reflect");
  id_ivar_table = rb_intern("@table");

  mCosmos = rb_define_module("Cosmos");

  cCrc = rb_define_class_under(mCosmos, "Crc", rb_cObject);

  cCrc16 = rb_define_class_under(mCosmos, "Crc16", cCrc);
  rb_define_method(cCrc16, "calc", crc16_calculate, -1);

  cCrc32 = rb_define_class_under(mCosmos, "Crc32", cCrc);
  rb_define_method(cCrc32, "calc", crc32_calculate, -1);

  cCrc64 = rb_define_class_under(mCosmos, "Crc64", cCrc);
  rb_define_method(cCrc64, "calc", crc64_calculate, -1);
}
