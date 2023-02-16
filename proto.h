/* proto.h: function prototypes for the various files that
 *  comprise the compiler.
 */


#include "symtab.h"

/* ---------------------- decl.c ---------------------- */

extern	link *new_class_spec(int first_char_of_lexeme);
extern	void set_class_bit(int first_char_of_lexeme,link *p);
extern	link *new_type_spec(char *lexeme);
extern	void add_spec_to_decl(link *p_spec,symbol *decl_chain);
extern	void add_symbols_to_table(symbol *sym);
extern	void figure_osclass(symbol *sym);

extern	symbol *remove_duplicates(symbol *sym);




/* ---------------------- symtab.c ----------------------= */

extern	symbol *new_symbol(char *name,int scope);
extern	void discard_symbol(symbol *sym);
extern	void discard_symbol_chain(symbol *sym);
extern	link *new_link(void);
extern	void discard_link_chain(link *p);
extern	void discard_link(link *p);
extern	void add_declarator(symbol *sym,int type);
extern	void spec_cpy(link *dst,link *src);
extern	link *clone_type(link *tchain,link **endp );
extern	int the_same_type(link *p1,link *p2,int relax);
extern	int get_sizeof(link *p);
extern	symbol *reverse_links(symbol *sym);
extern	char *sclass_str(int class);
extern	char *oclass_str(int class);
extern	char *noun_str(int noun);
extern	char *attr_str(specifier *spec_p);
extern	char *type_str(link *link_p);
extern	char *tconst_str(link *type);
extern	char *sym_chain_str(symbol *chain);
extern	void print_syms(char *filename);


