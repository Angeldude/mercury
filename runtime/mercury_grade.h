/*
** Copyright (C) 1997-1999 The University of Melbourne.
** This file may only be copied under the terms of the GNU Library General
** Public License - see the file COPYING.LIB in the Mercury distribution.
*/

/*
** mercury_grades.h - defines the MR_GRADE macro.
**
** This is used to get the linker to ensure that different object files
** were compiled with consistent grades.
**
** Any condition compilation macros that affect link compatibility
** should be included here.
** For documentation on the meaning of these macros, see
** runtime/mercury_conf_param.h.
**
** IMPORTANT: any changes here may also require changes to
** 	scripts/parse_grade_options.sh-subr
** 	scripts/ml.in
**	compiler/handle_options.m
**	compiler/mercury_compile.m
*/

#ifndef MERCURY_GRADES_H
#define MERCURY_GRADES_H

#include "mercury_tags.h" /* for TAGBITS */

/* convert a macro to a string */
#define MR_STRINGIFY(x)		MR_STRINGIFY_2(x)
#define MR_STRINGIFY_2(x)	#x

/* paste two macros together */
#define MR_PASTE2(p1,p2)	MR_PASTE2_2(p1,p2)
#define MR_PASTE2_2(p1,p2)	p1##p2

/*
** Here we build up the MR_GRADE macro part at a time,
** based on the compilation flags.
**
** IMPORTANT: any changes here will probably require similar
** changes to compiler/handle_options.m and scripts/mgnuc.in.
*/

/*
** This part of the grade is a binary compatibility version number.
** You should increment it any time you make a change that breaks
** binary backwards compatibility.
** Note that the binary compatibility version number has no direct
** relationship with the source release number (which is in ../VERSION).
**
** Note: next time the binary compatibility version number is increased,
** we should remove the MR_get_new_type_ctor_rep() function in
** runtime/mercury_type_info.c.  
**
** It is a good idea to inspect all code for RTTI version number checks
** and remove them when increasing the binary compatibility version number.   
** Searching for MR_RTTI_VERSION__ should find all code related to the
** RTTI version number.
*/

#define MR_GRADE_PART_0		v1_

#ifdef USE_ASM_LABELS
  #define MR_GRADE_PART_1	MR_PASTE2(MR_GRADE_PART_0, asm_)
#else
  #define MR_GRADE_PART_1	MR_GRADE_PART_0
#endif

#ifdef USE_GCC_NONLOCAL_GOTOS
  #ifdef USE_GCC_GLOBAL_REGISTERS
    #define MR_GRADE_PART_2	MR_PASTE2(MR_GRADE_PART_1, fast)
  #else
    #define MR_GRADE_PART_2	MR_PASTE2(MR_GRADE_PART_1, jump)
  #endif
#else
  #ifdef USE_GCC_GLOBAL_REGISTERS
    #define MR_GRADE_PART_2	MR_PASTE2(MR_GRADE_PART_1, reg)
  #else
    #define MR_GRADE_PART_2	MR_PASTE2(MR_GRADE_PART_1, none)
  #endif
#endif

#ifdef MR_THREAD_SAFE
  #define MR_GRADE_PART_3	MR_PASTE2(MR_GRADE_PART_2, _par)
#else
  #define MR_GRADE_PART_3	MR_GRADE_PART_2
#endif
#ifdef CONSERVATIVE_GC
  #define MR_GRADE_PART_4	MR_PASTE2(MR_GRADE_PART_3, _gc)
#elif defined(NATIVE_GC)
  #define MR_GRADE_PART_4	MR_PASTE2(MR_GRADE_PART_3, _agc)
#else
  #define MR_GRADE_PART_4	MR_GRADE_PART_3
#endif

#ifdef PROFILE_TIME
  #ifdef PROFILE_CALLS
    #ifdef PROFILE_MEMORY
      #define MR_GRADE_PART_5	MR_PASTE2(MR_GRADE_PART_4, _profall)
    #else
      #define MR_GRADE_PART_5	MR_PASTE2(MR_GRADE_PART_4, _prof)
    #endif
  #else
    #ifdef PROFILE_MEMORY
      /*
      ** Memory profiling interferes with time profiling,
      ** so there's no point in allowing this.
      */
      #error "Invalid combination of profiling options"
    #else
      /* Currently useless, but... */
      #define MR_GRADE_PART_5	MR_PASTE2(MR_GRADE_PART_4, _proftime)
    #endif
  #endif
#else
  #ifdef PROFILE_CALLS
    #ifdef PROFILE_MEMORY
      #define MR_GRADE_PART_5	MR_PASTE2(MR_GRADE_PART_4, _memprof)
    #else
      #define MR_GRADE_PART_5	MR_PASTE2(MR_GRADE_PART_4, _profcalls)
    #endif
  #else
    #ifdef PROFILE_MEMORY
      /*
      ** Call-graph memory profiling requires call profiling,
      ** and call profiling is reasonably cheap, so there's
      ** no point in allowing this.
      */
      #error "Invalid combination of profiling options"
    #else
      #define MR_GRADE_PART_5	MR_GRADE_PART_4
    #endif
  #endif
#endif

#ifdef MR_USE_TRAIL
  #define MR_GRADE_PART_6	MR_PASTE2(MR_GRADE_PART_5, _tr)
#else
  #define MR_GRADE_PART_6	MR_GRADE_PART_5
#endif

#ifdef MR_USE_MINIMAL_MODEL
  #define MR_GRADE_PART_7	MR_PASTE2(MR_GRADE_PART_6, _mm)
#else
  #define MR_GRADE_PART_7	MR_GRADE_PART_6
#endif

#if defined(MR_USE_TRAIL) && defined(MR_USE_MINIMAL_MODEL)
  #error "trailing and minimal model tabling are not compatible"
#endif

#if TAGBITS == 0
  #define MR_GRADE_PART_8	MR_PASTE2(MR_GRADE_PART_7, _notags)
#elif defined(HIGHTAGS)
  #define MR_GRADE_PART_8	MR_PASTE2(MR_GRADE_PART_7, \
  					MR_PASTE2(_hightags, TAGBITS))
#else
  #define MR_GRADE_PART_8	MR_PASTE2(MR_GRADE_PART_7, \
  					MR_PASTE2(_tags, TAGBITS))
#endif

#ifdef BOXED_FLOAT
  #define MR_GRADE_PART_9	MR_GRADE_PART_8
#else				/* "ubf" stands for "unboxed float" */
  #define MR_GRADE_PART_9	MR_PASTE2(MR_GRADE_PART_8, _ubf)
#endif

#define MR_GRADE_PART_10	MR_GRADE_PART_9

#if defined(PIC_REG) && defined(USE_GCC_GLOBAL_REGISTERS) && defined(__i386__)
  #define MR_GRADE_PART_11	MR_PASTE2(MR_GRADE_PART_10, _picreg)
#else
  #define MR_GRADE_PART_11	MR_GRADE_PART_10
#endif

/*
** Stack traces aren't strictly binary incompatible - but if you
** try to do a stack trace you might find it doesn't work very
** well unless all modules are compiled in with --stack-trace.
** Hence we consider it effectively binary incompatible.
** Similar considerations apply to procedure call tracing.
*/
#if defined(MR_STACK_TRACE)
  #if defined(MR_REQUIRE_TRACING)
    #define MR_GRADE_PART_12	MR_PASTE2(MR_GRADE_PART_11, _debug)
  #else
    #define MR_GRADE_PART_12	MR_PASTE2(MR_GRADE_PART_11, _strce)
  #endif
#else
  #if defined(MR_REQUIRE_TRACING)
    #define MR_GRADE_PART_12	MR_PASTE2(MR_GRADE_PART_11, _trace)
  #else
    #define MR_GRADE_PART_12	MR_GRADE_PART_11
  #endif
#endif

#define MR_GRADE		MR_GRADE_PART_12

#define MR_GRADE_VAR		MR_PASTE2(MR_grade_,MR_GRADE)
#define MR_GRADE_STRING 	MR_STRINGIFY(MR_GRADE)

extern const char MR_GRADE_VAR;

/*
** Here we do the same thing as above, but this time we build up a string
** containing the options to pass to the compiler to select this grade.
*/

#ifdef USE_ASM_LABELS
  #define MR_GRADE_OPT_PART_1	"asm_"
#else
  #define MR_GRADE_OPT_PART_1	""
#endif

#ifdef USE_GCC_NONLOCAL_GOTOS
  #ifdef USE_GCC_GLOBAL_REGISTERS
    #define MR_GRADE_OPT_PART_2	MR_GRADE_OPT_PART_1 "fast"
  #else
    #define MR_GRADE_OPT_PART_2	MR_GRADE_OPT_PART_1 "jump"
  #endif
#else
  #ifdef USE_GCC_GLOBAL_REGISTERS
    #define MR_GRADE_OPT_PART_2	MR_GRADE_OPT_PART_1 "reg"
  #else
    #define MR_GRADE_OPT_PART_2	MR_GRADE_OPT_PART_1 "none"
  #endif
#endif

#ifdef MR_THREAD_SAFE
  #define MR_GRADE_OPT_PART_3	MR_GRADE_OPT_PART_2 ".par"
#else
  #define MR_GRADE_OPT_PART_3	MR_GRADE_OPT_PART_2
#endif
#ifdef CONSERVATIVE_GC
  #define MR_GRADE_OPT_PART_4	MR_GRADE_OPT_PART_3 ".gc"
#elif defined(NATIVE_GC)
  #define MR_GRADE_OPT_PART_4	MR_GRADE_OPT_PART_3 ".agc"
#else
  #define MR_GRADE_OPT_PART_4	MR_GRADE_OPT_PART_3
#endif

#ifdef PROFILE_TIME
  #ifdef PROFILE_CALLS
    #ifdef PROFILE_MEMORY
      #define MR_GRADE_OPT_PART_5	MR_GRADE_OPT_PART_4 ".profall"
    #else
      #define MR_GRADE_OPT_PART_5	MR_GRADE_OPT_PART_4 ".prof"
    #endif
  #else
    #ifdef PROFILE_MEMORY
      /*
      ** Memory profiling interferes with time profiling,
      ** so there's no point in allowing this.
      */
      #error "Invalid combination of profiling options"
    #else
      /* Currently useless "but... */
      #define MR_GRADE_OPT_PART_5	MR_GRADE_OPT_PART_4 ".proftime"
    #endif
  #endif
#else
  #ifdef PROFILE_CALLS
    #ifdef PROFILE_MEMORY
      #define MR_GRADE_OPT_PART_5	MR_GRADE_OPT_PART_4 ".memprof"
    #else
      #define MR_GRADE_OPT_PART_5	MR_GRADE_OPT_PART_4 ".profcalls"
    #endif
  #else
    #ifdef PROFILE_MEMORY
      /*
      ** Call-graph memory profiling requires call profiling,
      ** and call profiling is reasonably cheap, so there's
      ** no point in allowing this.
      */
      #error "Invalid combination of profiling options"
    #else
      #define MR_GRADE_OPT_PART_5	MR_GRADE_OPT_PART_4
    #endif
  #endif
#endif

#ifdef MR_USE_TRAIL
  #define MR_GRADE_OPT_PART_6	MR_GRADE_OPT_PART_5 ".tr"
#else
  #define MR_GRADE_OPT_PART_6	MR_GRADE_OPT_PART_5
#endif

#ifdef MR_USE_MINIMAL_MODEL
  #define MR_GRADE_OPT_PART_7	MR_GRADE_OPT_PART_6 ".mm"
#else
  #define MR_GRADE_OPT_PART_7	MR_GRADE_OPT_PART_6
#endif

/*
** Parts 8-10 above (i.e. tag bits, and (un)boxed float)
** are documented as "not for general use", and can't be set via the
** `--grade' option; we don't bother to pass them on.
*/

#if defined(PIC_REG) && defined(USE_GCC_GLOBAL_REGISTERS) && defined(__i386__)
  #define MR_GRADE_OPT_PART_11	MR_GRADE_OPT_PART_7 ".picreg"
#else
  #define MR_GRADE_OPT_PART_11	MR_GRADE_OPT_PART_7
#endif

/*
** Stack traces aren't strictly binary incompatible - but if you
** try to do a stack trace you might find it doesn't work very
** well unless all modules are compiled in with --stack-trace.
** Hence we consider it effectively binary incompatible.
** Similar considerations apply to procedure call tracing.
*/
#if defined(MR_STACK_TRACE)
  #if defined(MR_REQUIRE_TRACING)
    #define MR_GRADE_OPT_PART_12	MR_GRADE_OPT_PART_11 ".debug"
  #else
    #define MR_GRADE_OPT_PART_12	MR_GRADE_OPT_PART_11 ".strce"
  #endif
#else
  #if defined(MR_REQUIRE_TRACING)
    #define MR_GRADE_OPT_PART_12	MR_GRADE_OPT_PART_11 ".trace"
  #else
    #define MR_GRADE_OPT_PART_12	MR_GRADE_OPT_PART_11
  #endif
#endif

#define MR_GRADE_OPT		MR_GRADE_OPT_PART_12

#endif /* MERCURY_GRADES_H */
