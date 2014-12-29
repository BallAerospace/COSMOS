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

/* Cosmos module reference */
VALUE mCosmos = Qnil;

/* SegFault class reference */
VALUE cSegFault = Qnil;

#ifdef _WIN32
  #include <windows.h>
#else
  #include <signal.h>
  #include <unistd.h>
  #include <time.h>

  static void catch_sigsegv(int sig_num) {
    char *cosmos_log_dir = NULL;
    time_t rawtime;
    struct tm *timeinfo;
    char filename[256];

    signal(SIGSEGV, SIG_DFL);
    signal(SIGILL, SIG_DFL);

    cosmos_log_dir = getenv("COSMOS_LOGS_DIR");
    if (cosmos_log_dir == NULL) {
      cosmos_log_dir = (char*) ".";
    }
    time(&rawtime);
    timeinfo = localtime(&rawtime);
    sprintf(filename, "%s/%04u_%02u_%02u_%02u_%02u_%02u_segfault.txt",
      cosmos_log_dir,
      1900 + timeinfo->tm_year,
      1 + timeinfo->tm_mon,
      timeinfo->tm_mday,
      timeinfo->tm_hour,
      timeinfo->tm_min,
      timeinfo->tm_sec);
    freopen(filename, "a", stderr);
    rb_bug("COSMOS caught segfault");
  }
#endif

static VALUE segfault(VALUE self) {
  char *a = 0;
  *a = 50;
  return Qnil;
}

/*
 * Initialize methods for Platform specific C code
 */
void Init_platform (void) {
  VALUE ruby_version = rb_const_get(rb_cObject, rb_intern("RUBY_VERSION"));

#ifdef _WIN32
  char* rversion = RSTRING_PTR(ruby_version);
  if ((rversion[0] == '2') && (rversion[2] == '0')) {
    LoadLibraryA("exchndl20.dll");
  } else if ((rversion[0] == '2') && (rversion[2] == '1')) {
    LoadLibraryA("exchndl21.dll");
  }
#else
  signal(SIGSEGV, catch_sigsegv);
  signal(SIGILL, catch_sigsegv);
#endif

  mCosmos = rb_define_module("Cosmos");
  cSegFault = rb_define_class_under(mCosmos, "SegFault", rb_cObject);
  rb_define_singleton_method(cSegFault, "segfault", segfault, 0);
}
