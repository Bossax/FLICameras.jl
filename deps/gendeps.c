/*
 * gendeps.c --
 *
 * Generate definitions for the Julia interface to the C libraries of TAO, a
 * Toolkit for Adaptive Optics.
 *
 *-----------------------------------------------------------------------------
 *
 * This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)
 * licensed under the MIT license.
 *
 * Copyright (C) 2018-2021, Éric Thiébaut.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tao.h>
#include <tao-cameras.h>

#ifndef TAO_DLL
#  define TAO_DLL "/usr/local/lib/libtao.so"
#endif

/*
 * Output stream for all macros and functions.
 */
static FILE* output = NULL;

/*
 * Print a given string to the output stream.
 */
#define PUTS(str) fputs(str, output)

/*
 * Print a newline to the output stream.
 */
#define NEWLINE PUTS("\n")

/*
 * Determine the offset of a field in a structure.
 */
#define OFFSET_OF(type, field) ((char*)&((type*)0)->field - (char*)0)

/*
 * Determine whether an integer type is signed.
 */
#define IS_SIGNED(type) ((type)(~(type)0) < (type)0)

/*
 * Check whether 2 integer types are identical.
 */
#define SAME_INTEGER_TYPE(a, b) (sizeof(a) == sizeof(b) && \
                                 IS_SIGNED(a) == IS_SIGNED(b))

/*
 * Set all the bits of an L-value.
 */
#define SET_ALL_BITS(lval) lval = 0; lval = ~lval

/*
 * Define a Julia constant.
 */
#define DEFINE_CONST(name, format) \
    fprintf(output, "const " #name format "\n", name)
#define DEFINE_CONST_CAST(name, format, type) \
    fprintf(output, "const " #name format "\n", (type)name)

/*
 * Define a Julia constant with the prefix _sizeof_.
 */
#define DEFINE_OFFSETOF(name, value) \
    fprintf(output, "const _offsetof_%s = %ld\n", name, (long)(value))

/*
 * Define a Julia constant with the offset (in bytes) of a field of a
 * C-structure.  The given name is prefixed by _offsetof_.
 */
#define DEFINE_OFFSETOF_FIELD(name, type, field) \
    DEFINE_OFFSETOF(name, OFFSET_OF(type, field))

/*
 * Define a Julia constant with the prefix _sizeof_.
 */
#define DEFINE_SIZEOF(name, value) \
    fprintf(output, "const _sizeof_%s = %ld\n", name, (long)(value))

/*
 * Define a Julia constant with the size of a given C-type, L-value
 * or member of a structure.  The given name is prefixed by _sizeof_.
 */
#define DEFINE_SIZEOF_TYPE(name, type) DEFINE_SIZEOF(name, sizeof(type))
#define DEFINE_SIZEOF_LVALUE(name, lval) DEFINE_SIZEOF(name, sizeof(lval))
#define DEFINE_SIZEOF_FIELD(name, type, field)  \
    do {                                        \
        type tmp_;                              \
        DEFINE_SIZEOF_LVALUE(name, tmp_.field); \
    } while (0)

/*
 * Define a Julia alias for a C type, an L-value or a member of a
 * structure.  Compared to the DEFINE_XXX_ALIAS macros, the name is
 * prefixed by _typeof_.
 */
#define DEFINE_TYPEOF_TYPE(name, type) \
    DEFINE_TYPE_ALIAS("_typeof_"name, type)
#define DEFINE_TYPEOF_LVALUE(name, lval) \
    DEFINE_LVALUE_ALIAS("_typeof_"name, type)
#define DEFINE_TYPEOF_FIELD(name, type, field) \
    DEFINE_FIELD_ALIAS("_typeof_"name, type, field)

/*
 * Define a Julia alias for a C type, an L-value or a member of a
 * structure.
 */
#define DEFINE_TYPE_ALIAS(name, type)           \
    do {                                        \
        fprintf(output, "const %s = ", name);   \
        PRINT_TYPE_ALIAS(type, 0);              \
        NEWLINE;                                \
    } while (0)
#define DEFINE_LVALUE_ALIAS(name, lval)         \
    do {                                        \
        fprintf(output, "const %s = ", name);   \
        PRINT_LVALUE_ALIAS(lval, 0);            \
        NEWLINE;                                \
    } while (0)
#define DEFINE_FIELD_ALIAS(name, type, field)   \
    do {                                        \
        type _tmp;                              \
        DEFINE_LVALUE_ALIAS(name, _tmp.field); \
    } while (0)

/*
 * Print a Julia alias for a C type, an L-value or a member of a structure.
 */
#define PRINT_TYPE_ALIAS(type, style) \
    print_integer_alias(sizeof(type), IS_SIGNED(type), style)
#define PRINT_LVALUE_ALIAS(lval, style)                         \
    do {                                                        \
        SET_ALL_BITS(lval);                                     \
        print_integer_alias(sizeof(lval), lval < 0, style);     \
    } while (0)
#define PRINT_FIELD_ALIAS(type, field, style)   \
    do {                                        \
        type _tmp;                              \
        PRINT_LVALUE_ALIAS(_tmp.field, style);  \
    } while (0)


#define ASSERT(expr)                                            \
    do {                                                        \
        if (!(expr)) {                                          \
            fprintf(stderr,                                     \
                    "Assertion `%s' failed in %s (%s:%d).\n",   \
                    #expr, __func__, __FILE__, __LINE__);       \
            exit(EXIT_FAILURE);                                 \
        }                                                       \
    } while (false)

static void
print_integer_alias(int size, int is_signed, int c_style)
{
    if (c_style) {
        switch (size) {
        case sizeof(int):
            fputs(is_signed ? "Cint" : "Cuint", output);
            return;
        case sizeof(long):
            fputs(is_signed ? "Clong" : "Culong", output);
            return;
        case sizeof(short):
            fputs(is_signed ? "Cshort" : "Cushort", output);
            return;
        case sizeof(char):
            fputs(is_signed ? "Cchar" : "Cuchar", output);
            return;
        }
    }
    fprintf(output, "%sInt%d", is_signed ? "" : "U", 8*size);
}

typedef enum {
    UNKNOWN,
    SIGNED,
    UNSIGNED,
    FLOAT,
} number_class;

/* List of types (C type, TAO name, Julia type, bits). */
#define ELTYPES \
    ITEM(   int8_t,    INT8,     Int8,    SIGNED) \
    ITEM(  uint8_t,   UINT8,    UInt8,  UNSIGNED) \
    ITEM(  int16_t,   INT16,    Int16,    SIGNED) \
    ITEM( uint16_t,  UINT16,   UInt16,  UNSIGNED) \
    ITEM(  int32_t,   INT32,    Int32,    SIGNED) \
    ITEM( uint32_t,  UINT32,   UInt32,  UNSIGNED) \
    ITEM(  int64_t,   INT64,    Int64,    SIGNED) \
    ITEM( uint64_t,  UINT64,   UInt64,  UNSIGNED) \
    ITEM(    float,   FLOAT,   Cfloat,     FLOAT) \
    ITEM(   double,  DOUBLE,  Cdouble,     FLOAT)

static struct {
    const char*  cname;
    const char*  tname;
    const char*  jname;
    tao_eltype   id;
    size_t       size;
    number_class cls;
} types[] = {
#define ITEM(c,t,j,n) {#c, "TAO_"#t, #j, TAO_##t, sizeof(c), n},
    ELTYPES
#undef ITEM
    {NULL, NULL, NULL, 0, 0, 0}
};

int main(int argc, char* argv[])
{
    int status = 0;

    output = stdout;
    if (argc == 2 && (strcmp(argv[1], "--help") == 0 ||
                      strcmp(argv[1], "-h") == 0)) {
    usage:
        fprintf(stderr, "Usage: %s [--help|-h]\n", argv[0]);
        return status;
    } else if (argc > 1) {
        status = 1;
        goto usage;
    }

    /*
     * A few checks.
     */
    ASSERT(sizeof(int) == sizeof(tao_object_type));
    ASSERT(sizeof(int) == sizeof(tao_eltype));

    /*
     * Count the number of TAO element types.
     */
    int ntypes = 0;
    while(types[ntypes].cname != NULL) {
        ++ntypes;
    }

#define DOC_QUOTE "\"\"\"\n"
    PUTS("#\n"
         "# deps.jl --\n"
         "#\n"
         "# Definitions for the Julia interface to TAO C-library.\n"
         "#\n"
         "# *IMPORTANT* This file has been automatically generated, do not edit it\n"
         "#             directly but rather modify the source in `gendeps.c`.\n"
         "#\n"
         "#------------------------------------------------------------------------------\n"
         "#\n"
         "# This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)\n"
         "# licensed under the MIT license.\n"
         "#\n"
         "# Copyright (C) 2018-2021, Éric Thiébaut.\n"
         "#\n"
         "\n"
         "# Path to the core TAO dynamic library:\n");
    fprintf(output, "const taolib = \"%s\"\n", TAO_DLL);

    PUTS("\n"
         "# Possible return values for an operation:\n");
    PUTS("struct Status\n"
         "    val::");
    PRINT_TYPE_ALIAS(tao_status, 1);
    PUTS("\nend\n");
#define DEF(id) fprintf(output, "const %-7s = Status(%2d)\n", #id, TAO_##id)
    DEF(ERROR);
    DEF(OK);
    DEF(TIMEOUT);
#undef DEF

    PUTS("\n"
         "# Type used to store a shared memory identifier:\n"
         "const ShmId = ");
    PRINT_TYPE_ALIAS(tao_shmid, 0);
    PUTS("\n\n"
         DOC_QUOTE
         "`TaoBindings.BAD_SHMID` is used to denote an invalid shared memory "
         "identifier.\n"
         DOC_QUOTE);
    fprintf(output, "const BAD_SHMID = ShmId(%ld)\n", (long)TAO_BAD_SHMID);

    /*
     * In principle, C enumerations are simple integers.  With gcc, an enum
     * with no negative constants is unsigned, signed otherwise.
     */
    enum _test { TEST1=-1, TEST2, TEST3};
    PUTS("\n"
         "# Julia type corresponding to a C enumeration:\n"
         "const Cenum = ");
    PRINT_TYPE_ALIAS(enum _test, 1);
    NEWLINE;

    /*
     * Format to be used below.
     */
#define FMT "0x%08x"

    PUTS("\n"
         DOC_QUOTE
         "`TaoBindings.SHARED_MAGIC` specifies a, hopefully unique, signature "
         "stored in\nthe 24 most significant bits of the TAO shared object "
         "type.\n"
         DOC_QUOTE);
    fprintf(output, "const SHARED_MAGIC = "FMT"\n", TAO_SHARED_MAGIC);
    PUTS("\n"
         DOC_QUOTE
         "`TaoBindings.SHARED_OBJECT` is the type of a basic TAO shared "
         "object.\n"
         DOC_QUOTE);
    fprintf(output, "const SHARED_OBJECT = "FMT"\n", TAO_SHARED_OBJECT);
    PUTS("\n"
         DOC_QUOTE
         "`TaoBindings.SHARED_ARRAY` is the type of a TAO shared multi-"
         "dimensional array.\n"
         DOC_QUOTE);
    fprintf(output, "const SHARED_ARRAY = "FMT"\n", TAO_SHARED_ARRAY);
    PUTS("\n"
         DOC_QUOTE
         "`TaoBindings.SHARED_CAMERA` is the type of a TAO shared camera "
         "data.\n"
         DOC_QUOTE);
    fprintf(output, "const SHARED_CAMERA = "FMT"\n", TAO_SHARED_CAMERA);
    PUTS("\n"
         DOC_QUOTE
         "`TaoBindings.REMOTE_MIRROR` is the type of a TAO remote deformable "
         "mirror.\n"
         DOC_QUOTE);
    fprintf(output, "const REMOTE_MIRROR = "FMT"\n", TAO_REMOTE_MIRROR);
    PUTS("\n"
         DOC_QUOTE
         "`TaoBindings.SHARED_MIRROR_DATA` is the type of a TAO shared "
         "deformable mirror data.\n"
         DOC_QUOTE);
    fprintf(output, "const SHARED_MIRROR_DATA = "FMT"\n",
            TAO_SHARED_MIRROR_DATA);
    PUTS("\n"
         DOC_QUOTE
         "`TaoBindings.SHARED_ANY` is the shared object type to use when any "
         "type is\n"
         "acceptable.\n"
         DOC_QUOTE);
    fprintf(output, "const SHARED_ANY = "FMT"\n", TAO_SHARED_ANY);
    PUTS("\n"
         DOC_QUOTE
         "`TaoBindings.SHARED_OWNER_SIZE` is the the number of bytes "
         "(including the final\nnull) for the name of the owner.\n"
         DOC_QUOTE);
    fprintf(output, "const SHARED_OWNER_SIZE = %d\n", TAO_SHARED_OWNER_SIZE);
    PUTS("\n"
         DOC_QUOTE
         "`TaoBindings.MAX_NDIMS` is the maximum number of dimensions of TAO "
         "arrays.\n"
         DOC_QUOTE);
    fprintf(output, "const MAX_NDIMS = %d\n", TAO_MAX_NDIMS);
    PUTS("\n"
         "# Union of all element types of TAO shared arrays.\n"
         "const SharedArrayElementTypes = Union{");
    for (int i = 0; i < ntypes; ++i) {
        if (i > 0) {
            fputs(((i % 5) == 0) ?
                  ",\n                                      " :
                  ", ", output);
        }
        fputs(types[i].jname, output);
    }
    PUTS("}\n"
         "\n"
         "# List of all element types of TAO shared arrays (can be indexed\n"
         "# by TAO element type identifier).\n"
         "const SHARED_ARRAY_ELTYPES = (");
    for (int i = 0; i < ntypes; ++i) {
        /* 2-loops to make sure types are in the correct order */
        bool found = false;
        if (i > 0) {
            fputs(((i % 5) == 0) ?
                  ",\n                                    " :
                  ", ", output);
        }
        for (int j = 0; j < ntypes; ++j) {
            if (types[j].id == i+1) {
                found = true;
                fputs(types[j].jname, output);
                break;
            }
        }
        if (! found) {
            fputs("Nothing", output);
        }
    }
    PUTS(")\n"
         "\n"
         DOC_QUOTE
         "    TaoBindings.shared_array_eltype(T) -> id\n"
         "\n"
         "yields the element type code of TAO shared array corresponding to "
         "Julia\ntype `T`.  An error is raised if `T` is not supported.\n"
         DOC_QUOTE);
    for (int i = 0; i < ntypes; ++i) {
        fprintf(output, "shared_array_eltype(::Type{%s}) = Cint(%d)\n",
                types[i].jname, (int)types[i].id);
    }
    fprintf(output, "@noinline shared_array_eltype(::Type{T}) where T =\n"
            "    error(\"unsupported element type \", T)\n");
    PUTS("\n"
         "# Identifiers of the type of the elements in an array.\n");
#define DEF(x, c) fprintf(output, "const ELTYPE_%-6s = %2d # %s\n",     \
                          #x, TAO_##x, c)
    DEF(INT8,   "Signed 8-bit integer");
    DEF(UINT8,  "Unsigned 8-bit integer");
    DEF(INT16,  "Signed 16-bit integer");
    DEF(UINT16, "Unsigned 16-bit integer");
    DEF(INT32,  "Signed 32-bit integer");
    DEF(UINT32, "Unsigned 32-bit integer");
    DEF(INT64,  "Signed 64-bit integer");
    DEF(UINT64, "Unsigned 64-bit integer");
    DEF(FLOAT,  "Single precision floating-point");
    DEF(DOUBLE, "Double precision floating-point");
#undef DEF

    PUTS("\n"
         "# Julia types of the members of the C `timespec` structure.\n");
    DEFINE_TYPEOF_FIELD("timespec_sec",  struct timespec, tv_sec);
    DEFINE_TYPEOF_FIELD("timespec_nsec", struct timespec, tv_nsec);

    PUTS("\n"
         "# The different possible camera states.\n");
#define DEF(x) fprintf(output, "const %-25s = Cint(%d)\n", #x, TAO_##x)
    DEF(CAMERA_STATE_INITIALIZING);
    DEF(CAMERA_STATE_SLEEPING);
    DEF(CAMERA_STATE_STARTING);
    DEF(CAMERA_STATE_ACQUIRING);
    DEF(CAMERA_STATE_STOPPING);
    DEF(CAMERA_STATE_ABORTING);
    DEF(CAMERA_STATE_FINISHED);
#undef DEF
    return 0;
}
