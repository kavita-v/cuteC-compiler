%{
#include<stdio.h>
#include<ctype.h>
#include<string.h>
#include<stdlib.h>  
#include "amb.h"  /* Contains definition of `symrec' */

int  yylex(void);
void yyerror (char  *);

int whileStart=0,nextJump=0; /*two separate variables not necessary for this application*/
int count=0;
int labelCount=0;
FILE *fp;

struct StmtsNode *final;
void StmtsTrav(stmtsptr ptr);
void StmtTrav(stmtptr ptr);

%}

%union {
int   val;  /* For returning numbers.                   */
struct symrec  *tptr;   /* For returning symbol-table pointers      */
char c[1000];
char nData[100];
struct StmtNode *stmtptr;
struct StmtsNode *stmtsptr;
}


/* The above will cause a #line directive to come in calc.tab.h.  The #line directive is typically used by program generators to cause error messages to refer to the original source file instead of to the generated program. */

%token  <val> NUM        /* Integer   */
%token <val> RELOP
%token  WHILE
%token RETURN
%token <val> TYPE
%token <tptr> MAIN VAR  
%type  <c>  exp
%type <nData> x
%type <stmtsptr> stmts
%type <stmtptr> while_loop var_decl ret_stmt stmt

%right '='
%left '-' '+'
%left '*' '/'


/* Grammar follows */

%%
prog: 
    TYPE MAIN '(' ')' '{' stmts '}' { final=$6; }
    ;

stmts: 
    stmt
    {
        $$ = (struct StmtsNode *) malloc(sizeof(struct StmtsNode)); $$->singl = 1; 
        $$->left = $1; $$->right = NULL;
    } 
    | 
    stmt stmts 
    {
        $$ = (struct StmtsNode *) malloc(sizeof(struct StmtsNode)); $$->singl = 0; 
        $$->left = $1; $$->right = $2;
    }
    ;

stmt:
    ret_stmt { $$ = $1; }
    |
    while_loop { $$ = $1; }  
    |
    var_decl { $$ = $1; }
    ;

ret_stmt:
    RETURN exp ';' 
    {
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=RETURN_STATEMENT;
	    sprintf($$->bodyCode,"\n%s\nli $v0, 1\nmove $a0,$t0\nsyscall\n\nli $v0, 10\nsyscall\n", $2);
	    $$->down=NULL;
    }
;

while_loop:
    WHILE '(' VAR RELOP VAR ')' '{' stmts '}' /* Put exp in place of VAR RELOP VAR and change the code accordingly*/
    {
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=WHILE_SYNTAX;
        sprintf($$->initCode,"lw $t0, %s($t8)\nlw $t1, %s($t8)\n", $3->addr,$5->addr);
        sprintf($$->initJumpCode,"bge $t0, $t1,"); 
        $$->down=$8;
	}
;

var_decl:
    TYPE VAR '=' exp ';'
    {
        printf("Test1");$$=(struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=DEFINE_VAR;
	    sprintf($$->bodyCode,"%s\nsw $t0,%s($t8)\n", $4, $2->addr);
	    $$->down=NULL;
    }
;

exp:      
    x              { sprintf($$,"%s",$1); count=(count+1)%2; }
    |
    x '+' x        { sprintf($$,"%s\n%s\nadd $t0, $t0, $t1",$1,$3); }
    | 
    x '-' x        { sprintf($$,"%s\n%s\nsub $t0, $t0, $t1",$1,$3); }
    | 
    x '*' x        { sprintf($$,"%s\n%s\nmul $t0, $t0, $t1",$1,$3); }
    |
    x '/' x        { sprintf($$,"%s\n%s\ndiv $t0, $t0, $t1",$1,$3); }
;

x:   
    NUM            { sprintf($$,"li $t%d, %d",count,$1); count=(count+1)%2; }
    | 
    VAR            { sprintf($$, "lw $t%d, %s($t8)",count,$1->addr); count=(count+1)%2; }
;

/* End of grammar */
%%

void StmtsTrav(stmtsptr ptr){
    printf("stmts\n");
    if (ptr==NULL) return;
    if (ptr->singl==1){ 
        StmtTrav(ptr->left);
    } else {
    StmtTrav(ptr->left);
    StmtsTrav(ptr->right);
    }
}
    
void StmtTrav(stmtptr ptr){
    int ws,nj;
    printf("stmt\n");
    if (ptr==NULL) return;
    if (ptr->type!=WHILE_SYNTAX){
        fprintf(fp,"%s\n",ptr->bodyCode);
    } else {
        ws=whileStart; whileStart++;
        nj=nextJump; nextJump++;
        fprintf(fp,"LabStartWhile%d:%s\n%s NextPart%d\n",ws,ptr->initCode,ptr->initJumpCode,nj);
        StmtsTrav(ptr->down);
        fprintf(fp,"j LabStartWhile%d\nNextPart%d:\n",ws,nj);
    }	  
}
   
int main ()
{
   fp=fopen("asmb.asm","w");
   fprintf(fp,".data\n\n.text\n");
   yyparse ();
   StmtsTrav(final);
   fclose(fp);
}

void yyerror (char *s)  /* Called by yyparse on error */
{
  printf ("%s\n", s);
}

// Currently, value of return statement is shifted to $a0 so that it gets printed
// $v0 is usually for return values but it needs to be set to 1 so that syscall works
// figure out what else can be done
