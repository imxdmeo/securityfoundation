/*
 * pwgen.c -- OS X command line password generator
 *
 * Copyright (c) 2013 Anders Bergh <anders1@gmail.com>
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 *   1. The origin of this software must not be misrepresented; you must not
 *   claim that you wrote the original software. If you use this software
 *   in a product, an acknowledgment in the product documentation would be
 *   appreciated but is not required.
 *
 *   2. Altered source versions must be plainly marked as such, and must
 *   not be misrepresented as being the original software.
 *
 *   3. This notice may not be removed or altered from any source
 *   distribution.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <getopt.h>
#include <assert.h>

#import <Foundation/Foundation.h>
#import "SecurityFoundation/SFPasswordAssistant.h"

#define MIN_LENGTH 8
#define MAX_LENGTH 31

static void usage(const char *argv0) {
  // to get the available languages
  NSDictionary *policy = (NSDictionary *)SFPWAPolicyCopyDefault();
  NSArray *languages =
      [policy[@"Languages-Evaluate"] componentsSeparatedByString:@","];

  printf("usage: %s [options]\n\n", argv0);
  printf("Option:          Meaning:\n");
  printf("  -a, --algorithm  Available algorithms: memorable, random\n");
  printf("                   letters, alphanumeric, numbers.\n");
  printf("  -c, --count      The number of passwords to generate.\n");
  printf("                   The default is `memorable'.\n");
  printf("  -l, --length     Desired length of the generated passwords.\n");
  printf("  -L, --language   Generate passwords in a specified language.\n");
  printf("                   Languages: %s.\n",
         [[languages componentsJoinedByString:@", "] UTF8String]);
  printf("                   Note that this feature is broken and will\n");
  printf("                   produce garbage, bug: rdar://14889281\n");
  printf("  -h, --help       Prints this message.\n");

  [policy release];

  exit(1);
}

int main(int argc, char *argv[]) {
  // Default options
  int count = 1;
  int length = 12;
  SFPWAAlgorithm algorithm = kSFPWAAlgorithmMemorable;
  NSString *language = @"en";

  const struct option longopts[] = {
    { "algorithm", optional_argument, NULL, 'a' },
    { "count", required_argument, NULL, 'c' },
    { "length", required_argument, NULL, 'l' },
    { "language", required_argument, NULL, 'L' },
    { "help", no_argument, NULL, 'h' }, { NULL, 0, NULL, 0 }
  };

  char ch;
  while ((ch = getopt_long(argc, argv, "c:a:l:L:h", longopts, NULL)) != -1) {
    switch (ch) {
      case 'a':
        if (strcmp(optarg, "memorable") == 0)
          algorithm = kSFPWAAlgorithmMemorable;

        else if (strcmp(optarg, "random") == 0)
          algorithm = kSFPWAAlgorithmRandom;

        else if (strcmp(optarg, "letters") == 0)
          algorithm = kSFPWAAlgorithmLetters;

        else if (strcmp(optarg, "alphanumeric") == 0)
          algorithm = kSFPWAAlgorithmAlphanumeric;

        else if (strcmp(optarg, "numbers") == 0)
          algorithm = kSFPWAAlgorithmNumbers;

        else {
          fprintf(stderr, "error: unknown algorithm.\n");
          usage(argv[0]);
          return 1;
        }
        break;

      case 'c':
        count = atoi(optarg);
        break;

      case 'l':
        length = atoi(optarg);
        break;

      case 'L':
        language = [NSString stringWithUTF8String:optarg];
        break;

      default:
        usage(argv[0]);
        return 1;
    }
  }

  if (count < 1)
    count = 1;

  if (length < MIN_LENGTH)
    length = MIN_LENGTH;

  else if (length > MAX_LENGTH)
    length = MAX_LENGTH;

  NSDictionary *policy = (NSDictionary *)SFPWAPolicyCopyDefault();
  assert(policy != NULL);

  SFPWAContextRef ctx = SFPWAContextCreateWithDefaults();
  assert(ctx != NULL);

  if (language) {
    NSArray *languages =
        [policy[@"Languages-Evaluate"] componentsSeparatedByString:@","];
    if ([languages containsObject:language]) {
      SFPWAContextLoadDictionaries(ctx, (CFArrayRef) @[ language ], 1);
    } else {
      fprintf(stderr,
              "warning: requested language `%s' unavailable, try one of: %s.\n",
              [language UTF8String],
              [[languages componentsJoinedByString:@", "] UTF8String]);
    }
  }

  NSMutableArray *suggestions = (NSMutableArray *)SFPWAPasswordSuggest(
      ctx, (CFDictionaryRef) policy, length, 0, count, algorithm);
  assert(suggestions != NULL);

  for (NSString *s in suggestions)
    printf("%s\n", [s UTF8String]);

  SFPWAContextRelease(ctx);
  [policy release];

  return 0;
}
