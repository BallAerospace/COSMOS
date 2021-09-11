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
#include "math.h"

#ifndef RFLOAT_VALUE
  #define RFLOAT_VALUE(v) (RFLOAT(v)->value)
#endif

VALUE mCosmos;
VALUE cConversion;
VALUE cPolynomialConversion;

static ID id_ivar_coeffs = 0;
static ID id_method_to_f = 0;

/*
 * Calling this method performs a polynomial conversion on the given value.
 *
 *   conversion.call(1, packet) #=> 2.5
 */
static VALUE polynomial_conversion_call(VALUE self, VALUE value, VALUE myself, VALUE buffer)
{
  int index = 0;
  double converted = 0.0;
  double raised_to_power = 1.0;

  volatile VALUE coeffs = rb_ivar_get(self, id_ivar_coeffs);
  long coeffs_length = RARRAY_LEN(coeffs);
  double double_value = RFLOAT_VALUE(rb_funcall(value, id_method_to_f, 0));

  /* Handle C0 */
  double coeff = RFLOAT_VALUE(rb_ary_entry(coeffs, 0));
  converted += coeff;

  /* Handle Coefficients raised to a power */
  for (index = 1; index < coeffs_length; index++)
  {
    raised_to_power *= double_value;
    coeff = RFLOAT_VALUE(rb_ary_entry(coeffs, index));
    converted += (coeff * raised_to_power);
  }

  return rb_float_new(converted);
}

/*
 * Initialize methods for PolynomialConversion
 */
void Init_polynomial_conversion (void)
{
  id_ivar_coeffs = rb_intern("@coeffs");
  id_method_to_f = rb_intern("to_f");

  mCosmos = rb_define_module("Cosmos");
  rb_require("cosmos/conversions/conversion");
  cConversion = rb_const_get(mCosmos, rb_intern("Conversion"));
  cPolynomialConversion = rb_define_class_under(mCosmos, "PolynomialConversion", cConversion);
  rb_define_method(cPolynomialConversion, "call", polynomial_conversion_call, 3);
}
