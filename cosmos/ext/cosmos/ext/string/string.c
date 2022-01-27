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

/*
 * Removes quotes from the given string if present.
 *
 *   "'quoted string'".remove_quotes #=> "quoted string"
 */
static VALUE string_remove_quotes(VALUE self)
{
  long length = RSTRING_LEN(self);
  char *ptr = RSTRING_PTR(self);
  char first_char = 0;
  char last_char = 0;

  if (length < 2)
  {
    return self;
  }

  first_char = ptr[0];
  if ((first_char != 34) && (first_char != 39))
  {
    return self;
  }

  last_char = ptr[length - 1];
  if (last_char != first_char)
  {
    return self;
  }

  return rb_str_new(ptr + 1, length - 2);
}

/*
 * Initialize methods for String Core Ext
 */
void Init_string(void)
{
  rb_define_method(rb_cString, "remove_quotes", string_remove_quotes, 0);
}
