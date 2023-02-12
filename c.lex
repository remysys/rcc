/* lexical analyzer specification for C */

%{
#include <stdio.h>
#include <string.h>
#include "y.tab.h"
#include "symtab.h"

extern union {          /* this definition must duplicate the %union in c.y */
  char *p_char;
  symbol *p_sym;
  link *p_link;
  int num;
  int ascii;
} yylval;               /* declared by rbison in y.tab.c */

extern FILE *yycodeout; /* declared by rbison in y.tab.c */

/*-------------------------------------------------------*/
}

let    [_a-zA-Z]          /* letter */
alnum  [_a_zA-Z0-9]       /* alphanumeric character */
h      [0-9a-faA-F]       /* hexadecimal digit */
o      [0-7]              /* octal digit */
d      [0-9]              /* decimal digit */
suffix [UuLl]             /* suffix in integral numeric constant */
white  [\x00-\s]          /* white space */

%%

%% 
"/*"    {
          int i;
          while (i = ii_input()) {
            if (i < 0) {
              ii_flushbuf(); /* discard lexeme */
            } else if (i == * && ii_lookahead(1) == '/') {
                  ii_input();
                  break;    /* recognized comment */
            }
          }

          if (i == 0) {
            yyerror("end of file in comment\n");
          }
        }

\"(\\.|[^\"])*\"  return STRING; 
\"(\\.|[^\"])*\n  yyerror("adding missing \" to string constant\n"); 
                  return STRING;

'.'                 |               /* 'a', 'b', etc.         */  
'\\.'               |               /* '\t' '\f', ect.        */
'\\{o}({o}{o}?)?'   |               /* '\123', '\12', '\1'    */
'\\x{h}{h}?'        |               /* '\x12', '\x1'          */
0{o}*{suffix}?      |               /* 0, 01, 012, 012L, etc. */
0x{h}+{suffix}?     |               /* 0x1, 0x12, 0x12L, etc. */
[1-9]{d}*{suffix}?    return ICON;  /* 123, 123L, etc. */

({d}+|{d}+\.{d}*|{d}*\.{d}+)([eE][\-+]?{d}+)?[fF]?   return FCON;

"("                   return LP;
")"                   return RP;
"{"                   return LC;
"}"                   return RC;
"["                   return LB;
"]"                   return RB;                    

"->"                  |
"."                   yylcal.ascii = *yytext;
                      return STRUCTOP;

"++"                  |
"--"                  yylval.ascii = *yytext;
                      return INCOP;

[~!]                  yylval.ascii = *yytext;                   
                      return UNOP;

"*"                   return START;

[/%]                  yylval.ascii = *yytext;
                      return DIVOP;

"+"                   return PLUS;
"-"                   return MINUS;

<<|>>                 yylval.ascii = *yytext;
                      return SHIFTOP;

[<>]=?                yylval.ascii = yytext[1] ? (yytext[0] == '>'? 'G' : 'L') : yytext[0];
                      return RELOP;

[!=]=                 yylval.ascii = *yytext;
                      return EQUOP;
    

%%

[*/%+\-&|^]=    |
(<<|>>)=        yylval.ascii = *yytext;
                return ASSIGNOP;

"="             return EQUAL;
"&"             return AND;
"^"             return XOR;
"|"             return OR;
"&&"            return ANDAND;
"||"            return OROR;
"?"             return QUEST;
":"             return COLON;
","             return COMMA;
";"             return SEMI;
"..."           return ELLIPSIS;

{let}{alnum}*   return id_or_keyword(yytext);
\n              fprintf(yycodeout, "\t\t\t\t\t\t\t\t\t/*%d*/\n", yylineno);
\{white}+       ;                 /* ignore white space */
.               yyerror("illegal character <%s>\n", yytext);
%%

typedef struct {
  char *name;
  int val;  
} KWORD;

KWORD Ktab[] = {
  {"auto", CLASS},
  {"break", BREAK},
  {"case", "CASE"},
  {"char", TYPE},
  {"continue", CONTINUE},
  {"default", DEFAULT},
  {"do", DO},
  {"double", TYPE},
  {"else", ELSE},
  {"enum", ENUM},
  {"extern", CLASS},
  {"float", TYPE},
  {"for", FOR},
  {"goto", GOTO},
  {"if", IF},
  {"int", TYPE},
  {"long", TYPE},
  {"register", CLASS},
  {"return", RETURN},
  {"short", TYPE},
  {"sizeof", SIZEOF},
  {"static", CLASS},
  {"struct", STRUCT},
  {"switch", SWITCH},
  {"typedef", CLASS},
  {"union", STRUCT},
  {"unsigned", TYPE},
  {"void", TYPE},
  {"while", WHILE}
};

static int cmp(KWORD *a, KWORD *b) 
{
  return strcmp(a->name, b->name);
}

static int id_or_keyword(char *lex) 
{
  KWORD *p;
  KWORD dummy;
  dummy.name = lex;
  p = (KWORD *) bsearch(&dummy, Ktab, sizeof(Ktab)/sizeof(KWORD), sizeof(KWORD), cmp);
  
  if (p) {
    yylval.ascii = *yytext;
    return p->val;
  } else if (yylval.p_sym = (symbol *) findsym(Symbol_tab, yytext)) {
    return (yylval.p_sym->type->tdef) ? TTYPE : NAME;
  } else {
    return NAME;
  }
}

#ifdef TEST_LEX

ptok(int tok) 
{
  switch( tok )
  {
    case STRING:      printf("STRING (%s)\n",     yytext); break;
    case ICON:        printf("ICON (%s)\n",       yytext); break;
    case FCON:        printf("FCON (%s)\n",       yytext); break;
    case TYPE:        printf("TYPE (%s)\n",       yytext); break;
    case STRUCT:      printf("STRUCT (%s)\n",     yytext); break;
    case ENUM:        printf("ENUM (%s)\n",       yytext); break;
    case RETURN:      printf("RETURN (%s)\n",     yytext); break;
    case GOTO:        printf("GOTO (%s)\n",       yytext); break;
    case IF:          printf("IF (%s)\n",         yytext); break;
    case ELSE:        printf("ELSE (%s)\n",       yytext); break;
    case SWITCH:      printf("SWITCH (%s)\n",     yytext); break;
    case CASE:        printf("CASE (%s)\n",       yytext); break;
    case DEFAULT:     printf("DEFAULT (%s)\n",    yytext); break;
    case BREAK:       printf("BREAK (%s)\n",      yytext); break;
    case CONTINUE:    printf("CONTINUE (%s)\n",   yytext); break;
    case WHILE:       printf("WHILE (%s)\n",      yytext); break;
    case DO:          printf("DO (%s)\n",         yytext); break;
    case FOR:         printf("FOR (%s)\n",        yytext); break;
    case LC:          printf("LC (%s)\n",         yytext); break;
    case RC:          printf("RC (%s)\n",         yytext); break;
    case SEMI:        printf("SEMI (%s)\n",       yytext); break;
    case ELLIPSIS:    printf("ELLIPSIS (%s)\n",   yytext); break;
    case COMMA:       printf("COMMA (%s)\n",      yytext); break;
    case EQUAL:       printf("EQUAL (%s)\n",      yytext); break;
    case ASSIGNOP:    printf("ASSIGNOP (%s)\n",   yytext); break;
    case QUEST:       printf("QUEST (%s)\n",      yytext); break;
    case COLON:       printf("COLON (%s)\n",      yytext); break;
    case OROR:        printf("OROR (%s)\n",       yytext); break;
    case ANDAND:      printf("ANDAND (%s)\n",     yytext); break;
    case OR:          printf("OR (%s)\n",         yytext); break;
    case XOR:         printf("XOR (%s)\n",        yytext); break;
    case AND:         printf("AND (%s)\n",        yytext); break;
    case EQUOP:       printf("EQUOP (%s)\n",      yytext); break;
    case RELOP:       printf("RELOP (%s)\n",      yytext); break;
    case SHIFTOP:     printf("SHIFTOP (%s)\n",    yytext); break;
    case PLUS:        printf("PLUS (%s)\n",       yytext); break;
    case MINUS:       printf("MINUS (%s)\n",      yytext); break;
    case STAR:        printf("STAR (%s)\n",       yytext); break;
    case DIVOP:       printf("DIVOP (%s)\n",      yytext); break;
    case SIZEOF:      printf("SIZEOF (%s)\n",     yytext); break;
    case UNOP:        printf("UNOP (%s)\n",       yytext); break;
    case INCOP:       printf("INCOP (%s)\n",      yytext); break;
    case LB:          printf("LB (%s)\n",         yytext); break;
    case RB:          printf("RB (%s)\n",         yytext); break;
    case LP:          printf("LP (%s)\n",         yytext); break;
    case RP:          printf("RP (%s)\n",         yytext); break;
    case STRUCTOP:    printf("STRUCTOP (%s)\n",   yytext); break;
    case TTYPE:       printf("TTYPE (%s)\n",      yytext); break;
    case CLASS:       printf("CLASS (%s)\n",      yytext); break;
    case NAME:        printf("NAME (%s)\n",       yytext); break;
  }
}

#endif 

