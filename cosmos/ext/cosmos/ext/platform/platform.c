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

/* Cosmos module reference */
VALUE mCosmos = Qnil;

/* SegFault class reference */
VALUE cSegFault = Qnil;

#ifdef _WIN32
/* COSMOS 5 drops segfault catching support for running directly on Windows - Usually in linux containers */
#else
#include <signal.h>
#include <unistd.h>
#include <time.h>
#include <string.h>
#include <sys/stat.h>

static void catch_sigsegv(int sig_num)
{
  const int FILENAME_LEN = 256;
  char *cosmos_log_dir = NULL;
  time_t rawtime;
  struct tm timeinfo;
  struct tm *timeinfo_ptr;
  struct stat stats;
  char filename[FILENAME_LEN];
  FILE *file = NULL;

  signal(SIGSEGV, SIG_DFL);
  signal(SIGILL, SIG_DFL);

  cosmos_log_dir = getenv("COSMOS_LOGS_DIR");
  // If the COSMOS_LOGS_DIR env var isn't set or if it's too big set to "."
  // NOTE: The filename buffer will be written to by snprintf which appends
  // a null terminator so we have 1 less byte available minus the length
  // of the fixed filename structure
  if ((cosmos_log_dir == NULL) || (strlen(cosmos_log_dir) > (FILENAME_LEN - 1 - strlen("/YYYY_MM_DD_HH_MM_SS_segfault.txt"))))
  {
    cosmos_log_dir = (char *)".";
  }
  // Validate that we can write to this directory
  if (stat(cosmos_log_dir, &stats) == 0)
  {
    if (!((stats.st_mode & W_OK)&& S_ISDIR(stats.st_mode)))
    {
      cosmos_log_dir = (char *)".";
    }
  }
  else
  {
    cosmos_log_dir = (char *)".";
  }

  time(&rawtime);
  timeinfo_ptr = localtime_r(&rawtime, &timeinfo);
  if (timeinfo_ptr == NULL)
  {
    // If localtime returns NULL we set our own and set to 1919 to make it interesting
    strptime("1919-01-01 00:00:00", "%Y-%m-%d %H:%M:%S", &timeinfo);
  }
  snprintf(filename, FILENAME_LEN, "%s/%04u_%02u_%02u_%02u_%02u_%02u_segfault.txt",
           cosmos_log_dir,
           1900 + timeinfo.tm_year,
           1 + timeinfo.tm_mon,
           timeinfo.tm_mday,
           timeinfo.tm_hour,
           timeinfo.tm_min,
           timeinfo.tm_sec);

  // Fortify warns about Path Manipulation here. We explictly allow this to let
  // segfault files be written to a directory of their choosing.
  // The input is validated above for length and to ensure it is a writable directory.
  // If the checks fail the directory is set to the current directory without additional info.
  file = freopen(filename, "a", stderr);
  /* Using file removes a warning */
  if (file)
  {
    rb_bug("COSMOS caught segfault");
  }
  else
  {
    rb_bug("COSMOS caught segfault");
  }
}
#endif

/* NOTE: Uncomment and rebuild for testing the handler */
// static VALUE segfault(VALUE self)
// {
//   char *a = 0;
//   *a = 50;
//   return Qnil;
// }

/*
 * Initialize methods for Platform specific C code
 */
void Init_platform(void)
{
#ifdef _WIN32
  /* Only supprt linux segfault catching */
#else
  signal(SIGSEGV, catch_sigsegv);
  signal(SIGILL, catch_sigsegv);
#endif

  /* NOTE: Uncomment and rebuild for testing the handler */
  // mCosmos = rb_define_module("Cosmos");
  // cSegFault = rb_define_class_under(mCosmos, "SegFault", rb_cObject);
  // rb_define_singleton_method(cSegFault, "segfault", segfault, 0);
}
