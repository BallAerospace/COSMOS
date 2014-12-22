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
#include <assert.h>

VALUE mCosmos;

/* Reference to LowFragmentationArray class */
VALUE cLowFragmentationArray = Qnil;

#define ARY_DEFAULT_SIZE 16
#define ARY_MAX_SIZE (LONG_MAX / (int)sizeof(VALUE))
#define FL_SET_EMBED(a) do { \
    assert(!ARY_SHARED_P(a)); \
    assert(!OBJ_FROZEN(a)); \
    FL_SET(a, RARRAY_EMBED_FLAG); \
} while (0)
#define FL_UNSET_EMBED(ary) FL_UNSET(ary, RARRAY_EMBED_FLAG|RARRAY_EMBED_LEN_MASK)
#define RARRAY_SHARED_ROOT_FLAG FL_USER5
#define ARY_SHARED_ROOT_P(ary) (FL_TEST(ary, RARRAY_SHARED_ROOT_FLAG))
#define ARY_SHARED_P(ary) \
    (assert(!FL_TEST(ary, ELTS_SHARED) || !FL_TEST(ary, RARRAY_EMBED_FLAG)), \
     FL_TEST(ary,ELTS_SHARED)!=0)
#define ARY_EMBED_P(ary) \
    (assert(!FL_TEST(ary, ELTS_SHARED) || !FL_TEST(ary, RARRAY_EMBED_FLAG)), \
     FL_TEST(ary, RARRAY_EMBED_FLAG)!=0)
#define ARY_SET_PTR(ary, p) do { \
    assert(!ARY_EMBED_P(ary)); \
    assert(!OBJ_FROZEN(ary)); \
    RARRAY(ary)->as.heap.ptr = (p); \
} while (0)
#define ARY_SET_EMBED_LEN(ary, n) do { \
    long tmp_n = n; \
    assert(ARY_EMBED_P(ary)); \
    assert(!OBJ_FROZEN(ary)); \
    RBASIC(ary)->flags &= ~RARRAY_EMBED_LEN_MASK; \
    RBASIC(ary)->flags |= (tmp_n) << RARRAY_EMBED_LEN_SHIFT; \
} while (0)
#define ARY_SET_HEAP_LEN(ary, n) do { \
    assert(!ARY_EMBED_P(ary)); \
    RARRAY(ary)->as.heap.len = n; \
} while (0)
#define ARY_SET_LEN(ary, n) do { \
    if (ARY_EMBED_P(ary)) { \
        ARY_SET_EMBED_LEN(ary, n); \
    } \
    else { \
        ARY_SET_HEAP_LEN(ary, n); \
    } \
    assert(RARRAY_LEN(ary) == n); \
} while (0)
#define ARY_CAPA(ary) (ARY_EMBED_P(ary) ? RARRAY_EMBED_LEN_MAX : \
		       ARY_SHARED_ROOT_P(ary) ? RARRAY_LEN(ary) : RARRAY(ary)->as.heap.aux.capa)
#define ARY_SET_CAPA(ary, n) do { \
    assert(!ARY_EMBED_P(ary)); \
    assert(!ARY_SHARED_P(ary)); \
    assert(!OBJ_FROZEN(ary)); \
    RARRAY(ary)->as.heap.aux.capa = (n); \
} while (0)

/*
 * Allocates memory for a new array
 * Note: Implementation almost exactly the same
 * as Ruby 1.9.2 p0 (have to copy because static)
 */
static VALUE my_ary_alloc (VALUE klass)
{
  NEWOBJ(ary, struct RArray);
  OBJSETUP((VALUE)ary, klass, T_ARRAY);
  FL_SET_EMBED((VALUE)ary);
  ARY_SET_EMBED_LEN((VALUE)ary, 0);

  return (VALUE)ary;
}

/*
 * Creates a new array of the original class type
 * Note: Implementation almost exactly the same as
 * Ruby 1.9.2 p0
 */
static VALUE my_ary_new (VALUE klass, long capa)
{
  VALUE ary;

  if (capa < 0)
  {
    rb_raise(rb_eArgError, "negative array size (or size too big)");
  }
  if (capa > ARY_MAX_SIZE)
  {
    rb_raise(rb_eArgError, "array size too big");
  }
  ary = my_ary_alloc(klass);
  if (capa > RARRAY_EMBED_LEN_MAX)
  {
    FL_UNSET_EMBED(ary);
    ARY_SET_PTR(ary, ALLOC_N(VALUE, capa));
    ARY_SET_CAPA(ary, capa);
    ARY_SET_HEAP_LEN(ary, 0);
  }

  return ary;
}

/*
 * Allocates space for an array but leaves the array length at 0
 */
static VALUE initialize (VALUE self, VALUE size)
{
  rb_call_super(1, &size);
  ARY_SET_LEN(self, 0);
  return self;
}

/*
 * Extract array range
 */
static VALUE my_ary_subseq (VALUE ary, long beg, long len)
{
  VALUE klass = Qnil;
  VALUE ary2  = Qnil;

  if (beg > RARRAY_LEN(ary))
  {
    return Qnil;
  }
  if (beg < 0 || len < 0)
  {
    return Qnil;
  }

  if (RARRAY_LEN(ary) < len || RARRAY_LEN(ary) < beg + len)
  {
    len = RARRAY_LEN(ary) - beg;
  }
  klass = rb_obj_class(ary);
  if (len == 0)
  {
    return my_ary_new(klass, 0);
  }

  ary2 = my_ary_new(klass, len);
  MEMCPY(RARRAY_PTR(ary2), RARRAY_PTR(ary) + beg, VALUE, len);
  ARY_SET_LEN(ary2, len);

  return ary2;
}

/*
 * Array reference - creates new memory for range rather than shared object
 * Note: Almost exactly the same as the implementation from
 * Ruby 1.9.2 p0
 */
static VALUE ary_aref(int argc, VALUE *argv, VALUE ary)
{
  VALUE arg;
  long beg, len;

  if (argc == 2)
  {
    beg = NUM2LONG(argv[0]);
    len = NUM2LONG(argv[1]);
    if (beg < 0)
    {
      beg += RARRAY_LEN(ary);
    }
    return my_ary_subseq(ary, beg, len);
  }
  if (argc != 1)
  {
    rb_scan_args(argc, argv, "11", 0, 0);
  }
  arg = argv[0];
  /* special case - speeding up */
  if (FIXNUM_P(arg))
  {
    return rb_ary_entry(ary, FIX2LONG(arg));
  }
  /* check if idx is Range */
  switch (rb_range_beg_len(arg, &beg, &len, RARRAY_LEN(ary), 0))
  {
    case Qfalse:
      break;
    case Qnil:
      return Qnil;
    default:
      return my_ary_subseq(ary, beg, len);
  }
  return rb_ary_entry(ary, NUM2LONG(arg));
}

/*
 * Removes values before an index and shifts old values down
 * without fragmenting memory by reallocating memory.
 */
static VALUE remove_before_bang (VALUE self, VALUE index)
{
  int int_index = FIX2INT(index);
  long new_length = 0;

  if (int_index < 0)
  {
    int_index += RARRAY_LEN(self);
    if (int_index < 0)
    {
      return self;
    }
  }

  if (RARRAY_LEN(self) > int_index)
  {
    MEMMOVE(RARRAY_PTR(self), RARRAY_PTR(self) + int_index, VALUE, RARRAY_LEN(self) - int_index);
    new_length = RARRAY_LEN(self) - int_index;
    ARY_SET_LEN(self, new_length);
  }
  else
  {
    ARY_SET_LEN(self, 0);
  }

  return self;
}

/*
 * Returns the size of memory allocated for the array
 */
static VALUE capacity (VALUE self)
{
  return LONG2NUM(ARY_CAPA(self));
}

/*
 * Returns the array's pointer
 */
static VALUE pointer (VALUE self)
{
  return LONG2NUM((long) RARRAY_PTR(self));
}

/*
 * Initialize methods for C LowFragmentationArray
 */
void Init_low_fragmentation_array (void)
{
  mCosmos = rb_define_module("Cosmos");
  cLowFragmentationArray = rb_define_class_under(mCosmos, "LowFragmentationArray", rb_cArray);
  rb_define_method(cLowFragmentationArray, "initialize", initialize, 1);
  rb_define_method(cLowFragmentationArray, "[]", ary_aref, -1);
  rb_define_method(cLowFragmentationArray, "remove_before!", remove_before_bang, 1);
  rb_define_method(cLowFragmentationArray, "capacity", capacity, 0);
  rb_define_method(cLowFragmentationArray, "pointer", pointer, 0);
}
