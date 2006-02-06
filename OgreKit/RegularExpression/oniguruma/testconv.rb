#!/usr/local/bin/ruby -Ke
# testconv.rb
# Copyright (C) 2003-2004  K.Kosako (sndgk393 AT ybb DOT ne DOT jp)

WINDOWS = (ARGV.size > 0 && /^-win/i =~ ARGV[0])
ARGV.shift if WINDOWS

if WINDOWS
  REGENC  = 'ONIG_ENCODING_SJIS'
else
  REGENC  = 'ONIG_ENCODING_EUC_JP'
end

def conv_reg(s)
  s.gsub!(/\\/, '\\\\\\\\')  #'
  s.gsub!(/\?\?/, '?\\\\?')  # escape ANSI trigraph (??)
  s
end

def conv_str(s)
  if (s[0] == ?')
    s = s[1..-2]
    return s.gsub(/\\/, '\\\\\\\\')  #'
  else
    return s[1..-2]
  end
end

print(<<"EOS")
/*
 * This program was generated by testconv.rb.
 */
#include "config.h"
#include <stdio.h>

#ifdef POSIX_TEST
#include "onigposix.h"
#else
#include "oniguruma.h"
#endif

#ifdef HAVE_STRING_H
# include <string.h>
#else
# include <strings.h>
#endif

#define SLEN(s)  strlen(s)

static int nsucc  = 0;
static int nfail  = 0;
static int nerror = 0;

static FILE* err_file;

#ifndef POSIX_TEST
static OnigRegion* region;
#endif

static void xx(char* pattern, char* str, int from, int to, int mem, int not)
{
  int r;

#ifdef POSIX_TEST
  regex_t reg;
  char buf[200];
  regmatch_t pmatch[20];

  r = regcomp(&reg, pattern, REG_EXTENDED | REG_NEWLINE);
  if (r) {
    regerror(r, &reg, buf, sizeof(buf));
    fprintf(err_file, "ERROR: %s\\n", buf);
    nerror++;
    return ;
  }

  r = regexec(&reg, str, reg.re_nsub + 1, pmatch, 0);
  if (r != 0 && r != REG_NOMATCH) {
    regerror(r, &reg, buf, sizeof(buf));
    fprintf(err_file, "ERROR: %s\\n", buf);
    nerror++;
    return ;
  }

  if (r == REG_NOMATCH) {
    if (not) {
      fprintf(stdout, "OK(N): /%s/ '%s'\\n", pattern, str);
      nsucc++;
    }
    else {
      fprintf(stdout, "FAIL: /%s/ '%s'\\n", pattern, str);
      nfail++;
    }
  }
  else {
    if (not) {
      fprintf(stdout, "FAIL(N): /%s/ '%s'\\n", pattern, str);
      nfail++;
    }
    else {
      if (pmatch[mem].rm_so == from && pmatch[mem].rm_eo == to) {
        fprintf(stdout, "OK: /%s/ '%s'\\n", pattern, str);
        nsucc++;
      }
      else {
        fprintf(stdout, "FAIL: /%s/ '%s' %d-%d : %d-%d\\n", pattern, str,
	        from, to, pmatch[mem].rm_so, pmatch[mem].rm_eo);
        nfail++;
      }
    }
  }
  regfree(&reg);

#else
  regex_t* reg;
  OnigErrorInfo einfo;

  r = onig_new(&reg, (UChar* )pattern, (UChar* )(pattern + SLEN(pattern)),
	       ONIG_OPTION_DEFAULT, #{REGENC}, ONIG_SYNTAX_DEFAULT, &einfo);
  if (r) {
    char s[ONIG_MAX_ERROR_MESSAGE_LEN];
    onig_error_code_to_str((UChar* )s, r, &einfo);
    fprintf(err_file, "ERROR: %s\\n", s);
    nerror++;
    return ;
  }

  r = onig_search(reg, (UChar* )str, (UChar* )(str + SLEN(str)),
		  (UChar* )str, (UChar* )(str + SLEN(str)),
		  region, ONIG_OPTION_NONE);
  if (r < ONIG_MISMATCH) {
    char s[ONIG_MAX_ERROR_MESSAGE_LEN];
    onig_error_code_to_str((UChar* )s, r);
    fprintf(err_file, "ERROR: %s\\n", s);
    nerror++;
    return ;
  }

  if (r == ONIG_MISMATCH) {
    if (not) {
      fprintf(stdout, "OK(N): /%s/ '%s'\\n", pattern, str);
      nsucc++;
    }
    else {
      fprintf(stdout, "FAIL: /%s/ '%s'\\n", pattern, str);
      nfail++;
    }
  }
  else {
    if (not) {
      fprintf(stdout, "FAIL(N): /%s/ '%s'\\n", pattern, str);
      nfail++;
    }
    else {
      if (region->beg[mem] == from && region->end[mem] == to) {
        fprintf(stdout, "OK: /%s/ '%s'\\n", pattern, str);
        nsucc++;
      }
      else {
        fprintf(stdout, "FAIL: /%s/ '%s' %d-%d : %d-%d\\n", pattern, str,
	        from, to, region->beg[mem], region->end[mem]);
        nfail++;
      }
    }
  }
  onig_free(reg);
#endif
}

static void x2(char* pattern, char* str, int from, int to)
{
  xx(pattern, str, from, to, 0, 0);
}

static void x3(char* pattern, char* str, int from, int to, int mem)
{
  xx(pattern, str, from, to, mem, 0);
}

static void n(char* pattern, char* str)
{
  xx(pattern, str, 0, 0, 0, 1);
}

extern int main(int argc, char* argv[])
{
  err_file = stdout;

#ifdef POSIX_TEST
  reg_set_encoding(#{REGENC.sub(/\AONIG_/, 'REG_POSIX_')});
#else
  region = onig_region_new();
#endif

EOS

PAT = '\\/([^\\\\\\/]*(?:\\\\.[^\\\\\\/]*)*)\\/'
CM = '\s*,\s*'
RX2 = %r{\Ax\(#{PAT}#{CM}('[^']*'|"[^"]*")#{CM}(\S+)#{CM}(\S+)\)}
RI2 = %r{\Ai\(#{PAT}#{CM}('[^']*'|"[^"]*")#{CM}(\S+)#{CM}(\S+)\)}
RX3 = %r{\Ax\(#{PAT}#{CM}('[^']*'|"[^"]*")#{CM}(\S+)#{CM}(\S+)#{CM}(\S+)\)}
RN  = %r{\An\(#{PAT}#{CM}('[^']*'|"[^"]*")\)} #'

while line = gets()
  if (m = RX2.match(line))
    reg = conv_reg(m[1])
    str = conv_str(m[2])
    printf("  x2(\"%s\", \"%s\", %s, %s);\n", reg, str, m[3], m[4])
  elsif (m = RI2.match(line))
    reg = conv_reg(m[1])
    str = conv_str(m[2])
    printf("  x2(\"%s\", \"%s\", %s, %s);\n", reg, str, m[3], m[4])
  elsif (m = RX3.match(line))
    reg = conv_reg(m[1])
    str = conv_str(m[2])
    printf("  x3(\"%s\", \"%s\", %s, %s, %s);\n", reg, str, m[3], m[4], m[5])
  elsif (m = RN.match(line))
    reg = conv_reg(m[1])
    str = conv_str(m[2])
    printf("  n(\"%s\", \"%s\");\n", reg, str)
  else

  end
end

print(<<'EOS')
  fprintf(stdout,
       "\nRESULT   SUCC: %d,  FAIL: %d,  ERROR: %d      (by Oniguruma %s)\n",
       nsucc, nfail, nerror, onig_version());

#ifndef POSIX_TEST
  onig_region_free(region, 1);
  onig_end();
#endif

  return 0;
}
EOS

# END OF SCRIPT
