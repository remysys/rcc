
#ifndef _SYMTAB_H
#define _SYMTAB_H

#include "hash.h"
#include <expat.h>

#ifdef ALLOC
#define ALLOC_CLS
#else
#define ALLOC_CLS extern
#endif
#define NAME_MAX 32           /* maximum identifier length */

typedef struct symbol {       /* symbol-table entry */
  char name[NAME_MAX + 1];    /* input variable name */
  char rname[NAME_MAX + 1];   /* actual variable name */
  unsigned int level;         /* declaration level */
  unsigned int implicit;      /* declaration created implicitly */
  unsigned int duplicate;     /* duplicate declaration */
  struct link *type;          /* first link in declarator chain */
  struct link *etype;         /* last link in declarator chain */
  struct symbol *args;        /* if a funct decl, the arg list. if a var, the initializer */
  struct symbol *next;        /* cross link to next variable at current nesting level */
} symbol;

ALLOC_CLS HASH_TAB *Symbol_tab; 

#define POINTER  0
#define ARRAY    1
#define FUNCTION 2

typedef struct declarator {
  int dcl_type;   /* POINTER, ARRAY, FUNCTION */
  int num_ele;    /* if class == ARRAY, # of elements */
} declarator;

/* specifier.noun, INT has the value 0 so that an 
 * uninitialized structure defaults to int
 */ 

#define INT         0 
#define CHAR        1
#define VOID        2
#define STRUCTURE   3
#define LABEL       4

/* specifier.sclass */
#define FIXED       0     /* at fixed address */
#define REGISTER    1     /* in a register */
#define AUTO        2     /* on the run-time stack */
#define TYPEDEF     3     /* typedef */
#define CONSTANT    4     /* this is a constant */

/* specifier.oclass: output (c-code) storage class */
#define NO_OCLASS 0       /* no output class (var is auto) */
#define PUB       1       /* public */
#define PRI       2       /* private */
#define EXT       3       /* extern */
#define COM       4       /* common */

typedef struct specifier {
  unsigned int noun;      /* CHAR INT STRUCTURE LABEL */
  unsigned int sclass;    /* REGISTER AUTO FIXED CONSTANT TYPEDEF */
  unsigned int oclass;    /* output storage class: PUB PRI COM EXT */
  unsigned int _long;     /* 1 = long 0 = short */
  unsigned int _unsigned; /* 1 = unsigned 0 = signed */
  unsigned int _static;   /* 1 = static keyword found in declarations */
  unsigned int _extern;   /* 1 = extern keyword found in declarations */
  
  union { 
    int v_int;             /* int & char values. if a string const. is numeric component of the label */
    unsigned int v_uint;   /* unsigned int constant value */
    long v_long;           /* signed long constant value */
    unsigned long v_ulong; /* unsigned long constant value */
    struct structdef *v_struct; /* if this is a struct. points at a structure-table element */
  } const_val;  /* val if constant */
} specifier;


#define DECLARATOR 0
#define SPECIFIER  1

typedef struct link {
  unsigned int class; /* DECLARATOR or SPECIFIER */
  unsigned int tdef;  /* for typedefs. if set, current link chain was created by a typedef */

  union {
    specifier s;  /* if class == DECLARATOR */
    declarator d; /* if class == SPECIFIER */
  } select;

  struct link *next; /* next element of chain */
} link;

/*
 * use the following p->XXX where p is a pointer to a link structure
 */

#define NOUN      select.s.nonu
#define SCLASS    select.s.sclass
#define OCLASS    select.s._oclass
#define LONG      select.s._long
#define UNSIGNED  select.s._unsigned
#define STATIC    select.s._static
#define EXTERN    select.s._extern

#define DCL_TYPE  select.d.dcl_type
#define NUM_ELE   select.d.num_ele  

#define VALUE     select.s.const_val
#define V_INT     VALUE.v_int
#define V_UINT    VALUE.v_uint
#define V_LONG    VALUE.v_long
#define V_ULONG   VALUE.v_ulong
#define V_STRUCT  VALUE.v_struct

/* use the following XXX(p) where p is a pointer to a link structure */

#define IS_DECLARATOR(p)  ((p) && (p)->class ==DECLARATOR)
#define IS_ARRAY(p)       ((p) && (p)->class == DECLARATOR && (p)->DCL_TYPE == ARRAY)
#define IS_POINTER(p)     ((p) && (p)->class == DECLARATOR && (p)->DCL_TYPE == POINTER)
#define IS_FUNCT(p)       ((p) && (p)->class == DECLARATOR && (p)->DCL_TYPE == FUNCTION)

#define IS_SPECIFIER(p)   ((p) && (p)->class == SPECIFIER)
#define IS_STRUCT(p)      ((p) && (p)->class == SPECIFIER && (p)->NOUN == STRUCTURE)
#define IS_LABEL(p)       ((p) && (p)->class == SPECIFIER && (p)->NOUN == LABEL)
#define IS_CHAR(p)        ((p) && (p)->class == SPECIFIER && (p)->NOUN == CHAR)
#define IS_INT(p)         ((p) && (p)->class == SPECIFIER && (p)->NOUN == INT)

#define IS_UINT(p)        (IS_INT(p) && (p)->UNSIGNED)
#define IS_LONG(p)        (IS_INT(p) && (p)->LONG)     
#define IS_ULONG(p)       (IS_INT(p) && (p)->LONG && (p)->UNSIGNED)
#define IS_UNSIGNED(p)    ((p) && (p)->UNSIGNED) 

#define IS_AGGREGATE(p)   (IS_ARRAY(p) || IS_STRUCT(p))
#define IS_PTR_TYPE(p)    (IS_ARRAY(p) || IS_POINTER)

#define IS_CONSTANT(p)      (IS_SPECIFIER(p) && (p)->SCLASS == CONSTANT)
#define IS_TYPEDEF(p)       (IS_SPECIFIER(p) && (p)->SCLASS == TYPEDEF)
#define IS_INT_CONSTANT(p)  (IS_CONSTANT(p) && (p)->NOUN == INT) 

#endif  /* _SYMTAB_H */