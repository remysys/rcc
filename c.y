%{
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <string.h>

#ifdef YYACTION
#define ALLOC              /* define ALLOC to create symbol table in symtab.h */
#endif

#include "symtab.h"         /* definitions for the symbol-table */
PRIVATE void clean_up(void);
%}

%union {
  char *p_char;
  symbol *p_sym;
  link *p_link;
  int  num;
  int  ascii;
}

%term STRING          /* string constant */
%term ICON            /* integer or long constant including '\t', etc */
%term FCON            /* floating-point constant */

%term TYPE            /* int char long float double signed unsigned short const volatile void */

%term <ascii> STRUCT  /* struct union */
%term ENUM            /* enum */

%term RETURN GOTO
%term IF ELSE
%term SWITCH CASE DEFAULT
%term BREAK CONTINUE
%term WHILE DO FOR
%term LC RC           /* { } */
%term SEMI            /* ;   */
%term ELLIPSIS        /* ... */

/* most other attributes are the first character of the lexeme. exceptions are as follows:
 * token    attribute
 * RELOP >     '>'
 * RELOP <     '<'
 * RELOP >=    'G'
 * RELOP <=    'L'
 */

%left COMMA                         /* , */
%right EQUAL <ascii> ASSIGNOP       /* = *= /= %= += -= <<= >>= &= |= ^= */
%right QUEST COLON                  /*  ? : */
%left OROR                          /* || */
%left ANDAND                        /* && */
%left OR                            /* | */
%left   XOR                         /* ^ */
%left AND                           /* & */
%left <ascii> EQUOP                 /* ==  != */
%left <ascii> RELOP                 /* <= >= < > */
%left <ascii> SHIFTOP               /* >> << */
%left PLUS  MINUS                   /* + - */
%left STAR  <ascii> DIVOP           /* * / % */
%right SIZEOF <ascii> UNOP INCOP    /* sizeof ! ~ ++ -- */
%left LB RB LP RP <ascii> STRUCTOP  /* [ ] ( ) . -> */


%term <p_sym> TTYPE       /* name of a type created with a previous typedef */
                          /* attribute is a pointer to the symbol table     */
                          /* entry for that typedef */

%nonassoc <ascii> CLASS   /* extern register auto static typedef. attribute */
                          /* is the first character of the lexeme */

%nonassoc <p_sym> NAME    /* identifier or typedef name. attribute is NULL  */
                          /* if the symbol doesn't exist, a pointer to the  */
                          /* associated "symbol" structure, otherwise */

%nonassoc ELSE            /* this gives a high precedence to ELSE to suppress
                           * the shift/reduce conflict error message in:
                           * s -> IF LP expr RP expr | IF LP expr RP s ELSE s
                           * the precedence of the first production is the same
                           * as RP. making ELSE higher precedence forces
                           * resolution in favor of the shift.
                           */

/* abbreviations used in nonterminal names:
 *
 * abs    == abstract
 * arg(s) == argument(s)
 * const  == constant
 * decl   == declarator
 * def    == definition
 * expr   == expression
 * ext    == external
 * opt    == optional
 * param  == parameter
 * struct == structure
*/

%type <num>   args const_expr test

%type <p_sym> ext_decl_list ext_decl def_list def decl_list decl
%type <p_sym> var_decl funct_decl local_defs new_name name enumerator
%type <p_sym> name_list var_list param_declaration abs_decl abstract_decl
%type <p_val> expr binary non_comma_expr unary initializer initializer_list
%type <p_val> or_expr and_expr or_list and_list

%type <p_link> type specifiers opt_specifiers type_or_class type_specifier
%type <p_sdef> opt_tag tag struct_specifier
%type <p_char> string_const target

/*----------------------------------------------------------------------
 * global and external variables. initialization to zero for all globals is
 * assumed. since rbison -a and -p is used, these variables may not be private.
 * the ifdef assures that space is allocated only once (this, header, section
 * will be placed in both y.act.c and y.tab.c, YYACTION is defined only in
 * y.act.c, however.
 */

%{
#ifdef YYACTION
%}

%{
int Nest_lev;  /* current block-nesting level */
%}

%{
int Enum_val;  /* current enumeration constant value */
%}

%{
#endif          /* ifdef YYACTION */
%}


%%
program : ext_def_list { clean_up(); }
  ;

ext_def_list : ext_def_list ext_def
  | /* epsilon */ 
  {
    yydata("#include <virtual.h>\n");
    yydata("#define T(x)\n");
    yydata("SEG(data)\n");
    yycode("\nSEG(code)\n");
    yybss("\nSEG(bss)\n");
  }
  ;

opt_specifiers
  : CLASS TTYPE { 
                  set_class_bit(0, $2->etype);   /* reset class */
                  set_class_bit($1, $2->etype);  /* add new class */
                  $$ = $2->type;
                }

  | TTYPE       {   
                  set_class_bit(0, $1->etype);    /* reset class bits */
                  $$ = $1->type ;
                }
  | specifiers
  | /* empty */  %prec COMMA
                {
                  $$ = new_link();
                  $$->class = SPECIFIER;
                  $$->NOUN  = INT;
                }
  ;

specifiers
  : type_or_class
  | specifiers type_or_class 
                { 
                  spec_cpy( $$, $2 );
                  discard_link_chain( $2 );
                }
  ;

type
  : type_specifier
  | type type_specifier 
                {  
                  spec_cpy( $$, $2 );
                  discard_link_chain( $2 );
                }
  ;

type_or_class
  : type_specifier
  | CLASS { $$ = new_class_spec($1); }
  ;

type_specifier
  : TYPE { $$ = new_type_spec(yytext); }
  ;

var_decl
  : new_name  %prec COMMA       /* this production is done first */
  | var_decl LP RP              { add_declarator($$, FUNCTION); }
  | var_decl LP var_list RP     { 
                                  add_declarator($$, FUNCTION);
                                  discard_symbol_chain($3);
                                }
  | var_decl LB RB
                                {
                                  /* at the global level, this must be treated as an array of
                                  * indeterminate size; at the local level this is equivalent to
                                  * a pointer. the latter case is patched after the declaration
                                  * is assembled.
                                  */

                                  add_declarator($$, ARRAY);
                                  $$->etype->NUM_ELE = 0;
                                }

  | var_decl LB const_expr RB
                                {
                                  add_declarator($$, ARRAY);
                                  $$->etype->NUM_ELE = $3;
                                }
  | STAR var_decl %prec UNOP
                                {
                                  add_declarator($$ = $2, POINTER);
                                }

  | LP var_decl RP { $$ = $2; }
  ;

/*----------------------------------------------------------------------
 * name productions. new_name always creates a new symbol, initialized with the
 * current lexeme. name returns a preexisting symbol with the associated name
 * (if there is one); otherwise, the symbol is allocated. the NAME token itself
 * has a NULL attribute if the symbol doesn't exist, otherwise it returns a
 * pointer to a "symbol" for the name
 */

new_name : NAME { $$ = new_symbol(yytext, Nest_lev); }
  ;

name : NAME { 
              if (!$1 || $1->level != Nest_lev) {
                $$ = new_symbol(yytext, Nest_lev);
              }
            }
  ;

/*
 * global declarations: take care of the declarator part of the declaration.
 * (the specifiers are handled by specifiers).
 * assemble the declarators into a chain, using the cross links.
 */

ext_decl_list : ext_decl        { $$->next = NULL; }
 | ext_decl_list COMMA ext_decl {
                                  $3->next = $1;
                                  $$ = $3;
                                }
 ;

ext_decl
  : var_decl
  | funct_decl
  ;

funct_decl : STAR funct_decl    { add_declarator($$ = $2, POINTER); }
  | funct_decl LB RB            { 
                                  add_declarator($$, ARRAY);
                                  $$->etype->NUM_ELE = 0;
                                }
  | funct_decl LB const_expr RB {
                                  add_declarator($$, ARRAY);
                                  $$->etype->NUM_ELE = $3;
                                }
  | LP funct_decl RP            { $$ = $2; }
  | funct_decl LP RP            { add_declarator( $$, FUNCTION); }
  | new_name LP RP              { add_declarator( $$, FUNCTION); }

  | new_name LP { ++Nest_lev; } name_list { --Nest_lev; } RP
                                {
                                  add_declarator($$, FUNCTION);
                                  $4 = reverse_links( $4 );
                                  $$->args = $4;
                                }
  | new_name LP { ++Nest_lev; } var_list { --Nest_lev; } RP
                                {
                                  add_declarator($$, FUNCTION);
                                  $$->args = $4;
                                }
  ;

name_list : new_name    {
                          $$->next = NULL;
                          $$->type = new_link();
                          $$->type->class = SPECIFIER;
                          $$->type->SCLASS = AUTO;
                        }

  | name_list COMMA new_name  {
                                $$ = $3;
                                $$->next = $1;
                                $$->type = new_link();
                                $$->type->class = SPECIFIER;
                                $$->type->SCLASS = AUTO;
                              }
  ;

var_list : param_declaration          { if ($1) { $$->next = NULL; } }
  | var_list COMMA param_declaration  { 
                                        if ($3) {
                                          $$ = $3;
                                          $3->next = $1;
                                        }
                                      }
  ;

param_declaration
  : type  var_decl { add_spec_to_decl($1, $$ = $2); }
  | abstract_decl  { discard_symbol($1); $$ = NULL; }
  | ELLIPSIS       { $$ = NULL; }
  ;


abstract_decl
  : type abs_decl   { add_spec_to_decl($1, $$ = $2); }
  | TTYPE abs_decl  {
                      $$ = $2;
                      add_spec_to_decl($1->type, $2);
                    }
  ;

abs_decl
  : /* epsilon */             { $$ = new_symbol("", 0); }
  | LP abs_decl RP LP RP      { add_declarator($$ = $2, FUNCTION); }
  | STAR abs_decl             { add_declarator($$ = $2, POINTER); }
  | abs_decl LB            RB { add_declarator($$, POINTER); }
  | abs_decl LB const_expr RB { 
                                add_declarator($$, ARRAY);
                                $$->etype->NUM_ELE = $3;
                              }
  | LP abs_decl RP            { $$ = $2; }
  ;

def_list
  : def_list def  {
                    symbol *p;
                    if (p = $2) {
                      for(; p->next; p = p->next )
                        ;
                      p->next = $1;
                      $$ = $2;
                    }
                  }
  | /* epsilon */ { $$ = NULL; }
  ;        

def : specifiers decl_list { add_spec_to_decl($1, $2); }
      SEMI { $$ = $2; }

  | specifiers SEMI { $$ = NULL; }
  ;

decl_list : decl { $$->next = NULL;}
  | decl_list COMMA decl  {
                            $3->next = $1;
                            $$ = $3;
                          }
  ;

decl
  : funct_decl
  | var_decl
  | var_decl COLON const_expr %prec COMMA
  | COLON const_expr %prec COMMA
  ;

ext_def : opt_specifiers ext_decl_list  {
                                          add_spec_to_decl($1, $2);
                                          if (!$1->tdef) {
                                            discard_link_chain($1);
                                          } 
                                          add_symbols_to_table($2 = reverse_links($2));
                                          figure_osclass($2);
                                          generate_defs_and_free_args($2);
                                          remove_duplicates($2);
                                        }
  SEMI

  | opt_specifiers  {
                      if (!($1->class == SPECIFIER && $1->NOUN == STRUCTURE)) {
                        yyerror("useless definition (no identifier)\n");
                      }
                        
                      if (!$1->tdef) {
                        discard_link_chain($1);
                      }
                    }
  SEMI
  ;
%%

#define OFILE_NAME "output.c" /* output file name.  */
char *Bss ;                   /* name of BSS  temporary file. */
char *Code;                   /* name of Code temporary file. */
char *Data;                   /* name of Data temporary file. */

PRIVATE void init_output_streams(char **p_code, char **p_data, char **p_bss)
{

  if (!(*p_code = mktemp("ccXXXXXX")) || !(*p_data = mktemp("cdXXXXXX")) || !(*p_bss  = mktemp("cbXXXXXX"))) {
    yyerror("can't create temporary-file names");
    exit(1);
  }

  if (!(yycodeout=fopen(*p_code, "w")) || !(yydataout=fopen(*p_data, "w")) || !(yybssout =fopen(*p_bss, "w"))) {
    perror("can't open temporary files");
    exit(1);
  }
}

PRIVATE void sigint_handler()
{
  /* Ctrl-C handler */

  signal(SIGINT, SIG_IGN);
  clean_up();
  unlink(OFILE_NAME);
  (*Osig)(0);
  exit(1);   /* needed only if old signal handler returns */
}

int sym_cmp    (symbol *s1, symbol *s2)       { return strcmp(s1->name, s2->name); }
int struct_cmp (structdef *s1, structdef *s2) { return strcmp(s1->tag, s2->tag); }

unsigned int sym_hash     (symbol *s1)    { return hash_pjw(s1->name); }
unsigned int struct_hash  (structdef *s1) { return hash_pjw(s1->tag); }

void yy_init_occs(void *val )
{     
  Osig = signal(SIGINT, SIG_IGN);
  init_output_streams(&Code, &Data, &Bss);
  signal(SIGINT, sigint_handler);

  ((yystype *)val)->p_char = "---";   /* attribute for the start symbol */

  Symbol_tab = maketab(257, sym_hash, sym_cmp);
  Struct_tab = maketab(127, struct_hash, struct_cmp);
}

PRIVATE void clean_up()
{
  /* cleanup actions. mark the ends of the various segments, then merge the
   * three temporary files used for the code, data, and bss segments into a
   * single file called output.c. delete the temporaries
   */

  extern FILE *yycodeout, *yydataout, *yybssout;

  signal(SIGINT, SIG_IGN);
  fclose(yycodeout);
  fclose(yydataout);
  fclose(yybssout);
  remove(OFILE_NAME);     /* delete old output file (ignore EEXIST) */

  if (rename(Data, OFILE_NAME )) {
    yyerror("can't rename temporary (%s) to %s\n", Data, OFILE_NAME );
  } else {           
    /* append the other temporary */
    movefile(OFILE_NAME, Bss , "a");    /* files to the end of the */
    movefile(OFILE_NAME, Code, "a");    /* output file and delete the temporary files */
  }
}

int main()
{
  ii_advance();
  ii_mark_start(); // skipping leading newline 
  yyparse();
  return 0; 
}
