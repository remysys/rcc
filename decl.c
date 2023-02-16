#include <stdio.h>
#include <stdlib.h>

#include "symtab.h"
#include "proto.h"


/* decl.c contains support subroutines for those actions 
 * in c.y that deal with declarations 
 */


link *new_class_spec(int first_char_of_lexeme) 
{
  /* return a new specifier link with the sclass field initialized to hold
   * a storage class, the first character of which is passed in as an argument
   * ('e' for extern, 's' for static, and so forth).
   */

  link *p = new_link();
  p->class = SPECIFIER;
  set_class_bit(first_char_of_lexeme, p);
  return p;
}


void set_class_bit(int first_char_of_lexeme, link *p)
{
  /* change the class of the specifier pointed to by p as indicated by the
   * first character in the lexeme. if it's 0, then the defaults are
   * restored (fixed, nonstatic, nonexternal). note that the TYPEDEF
   * class is used here only to remember that the input storage class
   * was a typedef, the tdef field in the link is set true (and the storage
   * class is cleared) before the entry is added to the symbol table.
   */

  switch (first_char_of_lexeme) {
    case 0: 
      p->SCLASS = FIXED;
      p->STATIC = 0;
      p->EXTERN = 0;
      break;
    
    case 't': 
      p->SCLASS = TYPEDEF;
      break;

    case 'r': 
      p->SCLASS = REGISTER; 
      break;

    case 's': 
      p->STATIC = 1;
      break;
    
    case 'e':
      p->EXTERN = 1;
      break;

    default:
      yyerror("internal: set_class_bit bad storage class '%c'\n", first_char_of_lexeme);
      exit(1);
      break; 
  }

}

link *new_type_spec(char *lexeme)
{
  /* create a new specifier and initialize the type according to the indicated
   * lexeme. input lexemes are: char const double float int long short
   * signed unsigned void volatile
   */
  
  link *p = new_link();
  p->class = SPECIFIER;
  switch (lexeme[0]) {
    case 'c':
      if (lexeme[1] == 'h') { /* char | const */
        p->NOUN = CHAR;       /* ignore const */
      }
      break;
    
    case 'd':   /* double */
    case 'f':   /* float */
      yyerror("no floating point\n");
      break;
    
    case 'i':   /* int */
      p->NOUN = INT;
      break;
    
    case 'l':   /* long */
      p->LONG = 1;
      break;
    
    case 'u':   /* unsigned */
      p->UNSIGNED = 1;
      break;
    
    case 'v':           /* void | volatile */
      p->NOUN = VOID;   /* ignore volatile */
      break;
    
    case 's':   /* short | signed */
      break;    /* ignore both    */
  }

  return p;
}


void add_spec_to_decl(link *p_spec, symbol *decl_chain)
{
  /* p_spec is a pointer either to a specifier/declarator chain created
   * by a previous typedef or to a single specifier. it is cloned and then
   * tacked onto the end of every declaration chain in the list pointed to by
   * decl_chain. note that the memory used for a single specifier, as compared
   * to a typedef, may be freed after making this call because a COPY is put
   * into the symbol's type chain
   *
   * typedefs are handled like this: if the incoming storage class is TYPEDEF,
   * then the typedef appeared in the current declaration and the tdef bit is
   * set at the head of the cloned type chain and the storage class in the
   * clone is cleared; otherwise, the clone's tdef bit is cleared (it's just
   * not copied by clone_type())
   */ 

  link *clone_start, *clone_end;
  for (; decl_chain; decl_chain = decl_chain->next) {
    if (!(clone_start = clone_type(p_spec, &clone_end))) {
      yyerror("internal: add_spec_to_decl no specifier\n");
      exit(1);
    } else {
      if (!decl_chain->type) {  /* no declarators */
        decl_chain->type = clone_start;
      } else {
        decl_chain->etype->next = clone_start;
      }

      decl_chain->etype = clone_end;

      if (IS_TYPEDEF(clone_end)) {
        set_class_bit(0, clone_end);
        decl_chain->type->tdef = 1;
      }
    }
  }
}


void add_symbols_to_table(symbol *sym)
{
  /* add declarations to the symbol table.
   *
   * serious redefinitions (two publics, for example) generate an error
   * message. harmless redefinitions are processed silently. bad code is
   * generated when an error message is printed. the symbol table is modified
   * in the case of a harmless duplicate to reflect the higher precedence
   * storage class: (public == private) > common > extern
   *
   * the sym->rname field is modified as if this were a global variable (an
   * underscore is inserted in front of the name). you should add the symbol
   * chains to the table before modifying this field to hold stack offsets
   * in the case of local variables
   */

  symbol *exists;      /* existing symbol if there's a conflict */
  int harmless;
  symbol *new;

  for (new = sym; new; new = new->next) {
    exists = (symbol *) findsym(Symbol_tab, new->name);

    if (!exists || exists->level != new->level) {
      sprintf(new->rname, "_%1.*s", sizeof(new->rname)-2, new->name);
      addsym(Symbol_tab, new );
    } else {
      harmless = 0;
      new->duplicate = 1;
      
      if (the_same_type(exists->type, new->type, 0)) {
        if (exists->etype->OCLASS==EXT || exists->etype->OCLASS==COM) {
          harmless = 1;

          if (new->etype->OCLASS != EXT) {
            exists->etype->OCLASS = new->etype->OCLASS;
            exists->etype->SCLASS = new->etype->SCLASS;
            exists->etype->EXTERN = new->etype->EXTERN;
            exists->etype->STATIC = new->etype->STATIC;
          }
        }
      }
       
      if (!harmless) {
        yyerror("duplicate declaration of %s\n", new->name);
      }
    }
  }
}


void figure_osclass(symbol *sym)
{
  /* go through the list figuring the output storage class of all variables.
   * note that if something is a variable, then the args, if any, are a list
   * of initializers. i'm assuming that the sym has been initialized to zeros;
   * at least the OSCLASS field remains unchanged for nonautomatic local
   * variables, and a value of zero there indicates a nonexistent output class.
   */

  for (; sym; sym = sym->next) {
    if (sym->level == 0) {
      if (IS_FUNCT(sym->type)) {
        if (sym->etype->EXTERN) {
          sym->etype->OCLASS = EXT;
        } else if  (sym->etype->STATIC) {
          sym->etype->OCLASS = PRI;
        } else {
          sym->etype->OCLASS = PUB;
        }
      } else {
        if (sym->etype->STATIC)  {
          sym->etype->OCLASS = PRI;
        }
        
        if (sym->args) {
          sym->etype->OCLASS = PUB;
        }  else {
          sym->etype->OCLASS = COM;
        }
      }
    } else if(sym->type->SCLASS == FIXED) {
      if (IS_FUNCT(sym->type)) {
        sym->etype->OCLASS = EXT;
      }
      else if (!IS_LABEL(sym->type)) {
        sym->etype->OCLASS = PRI;
      }
    }
  }
}

symbol *remove_duplicates(symbol *sym)
{
   /* remove all nodes marked as duplicates from the linked list and free the
    * memory. these nodes should not be in the symbol table. return the new
    * head-of-list pointer (the first symbol may have been deleted)
    */
  
  symbol *prev = NULL;
  symbol *first = sym;

  while (sym) {
    if (!sym->duplicate) {        /* not a duplicate, go to the next list element */           
      prev = sym;
      sym  = sym->next;
    } else if (prev == NULL) {        /* node is at start of the list */
      first = sym->next;
      discard_symbol( sym );
      sym = first;
    } else {                          /* node is in middle of the list. */
      prev->next = sym->next;
      discard_symbol( sym );
      sym = prev->next;
    }
  }
  
  return first;
}