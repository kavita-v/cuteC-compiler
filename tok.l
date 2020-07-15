%{
#include "amb.tab.h"
#include "amb.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int Adr=0;
symrec *sym_table = (symrec *)0;

void comment();
void yyerror();

%}

D			[0-9]
L			[a-zA-Z_]
number      {D}+
id  {L}({L}|{D})*

%%
"//"[^\n]*    { /* Discard comments. */ }
[ \t\n]+      { /* Ignore whitespace */ }
"/*"          { comment(); }
"while"       { return WHILE; }
"for"         { return FOR; }
"if"          { return IF; }
"else"        { return ELSE; }
"<="          { return LE_OP; }
">="          { return GE_OP; }
"!="          { return NE_OP; }
"=="          { return EQ_OP; }
"&&"          { return AND; }
"||"          { return OR; }
"%"           { return MOD; }
{number}      { sscanf(yytext,"%d",&yylval.val);return NUM; }
"return"      { return RETURN; }
"int"         { yylval.val=1;return TYPE; }
"main"        { symrec *s; s=getsym(yytext); if(s==0) s=putsym(yytext,MAIN); yylval.tptr=s; return MAIN; }
"printf"      {sscanf(yytext,"%s",yylval.nData); return SYSCALL;}
"\"%d\""|"'%d'"     {return FORMAT;}
{id}          { symrec *s; s=getsym(yytext); if(s==0) s=putsym(yytext,VAR); yylval.tptr=s; return VAR; }
.             { return yytext[0]; }
%%

/* The symbol table: a chain of `struct symrec'.  */

symrec * putsym (char *sym_name,int sym_type){
  symrec *ptr;
  ptr = (symrec *) malloc (sizeof (symrec));
  ptr->name = (char *) malloc (strlen (sym_name) + 1);
  strcpy (ptr->name,sym_name);
  sprintf(ptr->addr,"%d",Adr); /* set value to 0 even if fctn.  */
  Adr=Adr+4;
  ptr->next = (struct symrec *)sym_table;
  sym_table = ptr;
  return ptr;
}

symrec *getsym (char *sym_name){
  symrec *ptr;
  for (ptr = sym_table; ptr != (symrec *) 0;
       ptr = (symrec *)ptr->next)
    if (strcmp (ptr->name,sym_name) == 0)
      return ptr;
  return 0;
}

/* Function for identifying unterminated multi-line comments */

// TODO: write a test for multiline comments
void comment(void) {
    /* Consume characters up to the closing comment marker. */
    char curr, prev = 0;
  
    while ((curr = input()) != 0) {
        if (curr == '/' && prev == '*')
            return;
        prev = curr;
    }
    yyerror("unterminated comment");
}
