%{
#include<stdio.h>
#include<ctype.h>
#include<string.h>
#include<stdlib.h>  
#include "amb.h"  /* Contains definition of `symrec' */

int  yylex(void);
void yyerror (char  *);

int count=0;

struct ASTNode *final;
void ASTTrav(ASTptr ptr);
void StmtTrav(stmtptr ptr);

char *fresh_local_label(char *prefix, int label_count) {
    // We assume we never write more than 6 chars of digits, plus a '.' and '_'.
    size_t buffer_size = strlen(prefix) + 8;
    char *buffer = malloc(buffer_size);

    snprintf(buffer, buffer_size, ".%s_%d", prefix, label_count);
    return buffer;
}
%}

%define parse.error verbose

%union {
int   val;  /* For returning numbers.                   */
struct symrec  *tptr;   /* For returning symbol-table pointers      */
char c[10000];
char nData[100];
struct StmtNode *stmtptr;
struct ASTNode *ASTptr;
}


/* The above will cause a #line directive to come in amb.tab.h.  The #line directive is typically used by program generators to cause error messages to refer to the original source file instead of to the generated program. */

%token <val> NUM
%token <val> RELOP LE_OP GE_OP NE_OP EQ_OP AND OR MOD
%token  WHILE FOR IF ELSE
%token RETURN FORMAT
%token <val> TYPE
%token <tptr> MAIN VAR  
%token <nData> SYSCALL BREAK
%type  <c>  exp relop_exp exp-common
%type <nData> x
%type <ASTptr> stmts else_stmt
%type <stmtptr> while_loop for_loop for_exp var_decl ret_stmt if_stmt stmt var_assign exp_as_stmt syscll


%right '='
%left OR
%left AND
%left NE_OP EQ_OP
%left LE_OP GE_OP '<' '>'
%left '-' '+'
%left '*' '/' MOD
%left NEG

/* Grammar follows */

%%
prog: 
    TYPE MAIN '(' ')' '{' stmts '}' { final=$6; }
    ;

stmts: 
    stmt
    {
        $$ = (struct ASTNode *) malloc(sizeof(struct ASTNode)); $$->singl = 1; 
        $$->left = $1; $$->right = NULL;
    } 
    | 
    stmt stmts 
    {
        $$ = (struct ASTNode *) malloc(sizeof(struct ASTNode)); $$->singl = 0; 
        $$->left = $1; $$->right = $2;
    }
    ;

stmt:
    ret_stmt { $$ = $1; }
    |
    while_loop { $$ = $1; }  
    |
    for_loop {$$ = $1;}
    |
    if_stmt {$$ = $1; }
    |
    var_decl ';' { $$ = $1; }
    |
    var_assign ';' { $$ = $1; }
    |
    exp_as_stmt { $$ = $1; }
    |
    syscll { $$ = $1;}
    ;

ret_stmt:
    RETURN exp ';' 
    {
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=RETURN_STATEMENT;
	    sprintf($$->bodyCode,"\n%s\nli $v0, 1\nmove $a0,$t0\nsyscall\n\nli $v0, 10\nsyscall\n", $2);
	    $$->down=NULL;
    }
    |
    RETURN relop_exp ';'
    {
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=RETURN_STATEMENT;
	    sprintf($$->bodyCode,"\n%s\nli $v0, 1\nmove $a0,$t0\nsyscall\n\nli $v0, 10\nsyscall\n", $2);
	    $$->down=NULL;
    }
    // Currently, value of return statement is shifted to $a0 so that it gets printed
    // $v0 is usually for return values but it needs to be set to 1 so that syscall works
;

while_loop:
    WHILE '(' relop_exp ')' '{' stmts '}' 
    {
        printf("entered while\n");
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=WHILE_SYNTAX;
        sprintf($$->bodyCode,"%s", $3);
        sprintf($$->initJumpCode,"beq $t0, $0,");  
        $$->down=$6;
	}
    |
    WHILE '(' relop_exp ')' stmt
    {
        printf("entered while\n");
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=WHILE_SYNTAX;
        sprintf($$->bodyCode,"%s", $3);
        sprintf($$->initJumpCode,"beq $t0, $0,");
        // we need to creat an ASTNode for the stmt
        $$->down = (struct ASTNode *) malloc(sizeof(struct ASTNode)); $$->down->singl = 1; 
        $$->down->left = $5; $$->down->right = NULL;
    }
;

for_loop:
    FOR '(' for_exp ';' relop_exp ';' for_exp ')' '{' stmts '}' 
    {
        printf("entered for\n");
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=FOR_SYNTAX;
        sprintf($$->bodyCode,"%s",$5);
        sprintf($$->initJumpCode,"beq $t0, $0,");
        sprintf($$->for_exp,"%s",$3->bodyCode);
        sprintf($$->for_exp2,"%s",$7->bodyCode);
        $$->down=$10;
    }
    |
    FOR '(' for_exp ';' relop_exp ';' for_exp ')' stmt 
    {
        printf("entered for\n");
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=FOR_SYNTAX;
        sprintf($$->bodyCode,"%s",$5);
        sprintf($$->initJumpCode,"beq $t0, $0,");
        sprintf($$->for_exp,"%s",$3->bodyCode);
        sprintf($$->for_exp2,"%s",$7->bodyCode);
        // we need to creat an ASTNode for the stmt
        $$->down = (struct ASTNode *) malloc(sizeof(struct ASTNode)); $$->down->singl = 1; 
        $$->down->left = $9; $$->down->right = NULL;
    }
;

for_exp:
    var_assign {$$ = $1;} | var_decl {$$ = $1;}
;

if_stmt:
    IF '(' relop_exp ')' '{' stmts '}' else_stmt
    {
        printf("entered if\n");
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=IF_SYNTAX;
        sprintf($$->bodyCode,"%s", $3);
        sprintf($$->initJumpCode,"beq $t0, $0,");   
        $$->down=$6;
        $$->jump=$8;
    }
    |
    IF '(' relop_exp ')' stmt else_stmt
    {
        printf("entered if\n");
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=IF_SYNTAX;
        sprintf($$->bodyCode,"%s", $3);
        sprintf($$->initJumpCode,"beq $t0, $0,");   
        // we need to creat an ASTNode for the stmt
        $$->down = (struct ASTNode *) malloc(sizeof(struct ASTNode)); $$->down->singl = 1; 
        $$->down->left = $5; $$->down->right = NULL;
        $$->jump=$6;
    }
    |
    IF '(' relop_exp ')' '{' stmts '}'
    {
        printf("entered if\n");
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=IF_SYNTAX;
        sprintf($$->bodyCode,"%s", $3);
        sprintf($$->initJumpCode,"beq $t0, $0,");   
        $$->down=$6;
        $$->jump=NULL;
    }
    |
    IF '(' relop_exp ')' stmt
    {
        printf("entered if\n");
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=IF_SYNTAX;
        sprintf($$->bodyCode,"%s", $3);
        sprintf($$->initJumpCode,"beq $t0, $0,");   
        // we need to creat an ASTNode for the stmt
        $$->down = (struct ASTNode *) malloc(sizeof(struct ASTNode)); $$->down->singl = 1; 
        $$->down->left = $5; $$->down->right = NULL;
        $$->jump=NULL;
    }
;

else_stmt:
    ELSE '{' stmts '}'  
    {   printf("entered else\n"); 
        $$ = $3;
    }
    |
    ELSE stmt
    {
        printf("entered else\n");
        // we need to creat an ASTNode for the stmt
        $$ = (struct ASTNode *) malloc(sizeof(struct ASTNode)); $$->singl = 1; 
        $$->left = $2; $$->right = NULL;
    }
;

var_decl:
    TYPE VAR '=' exp
    {
        $$=(struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=DEFINE_VAR;
	    sprintf($$->bodyCode,"%s\nsw $t0,%s($t8)\n", $4, $2->addr);
	    $$->down=NULL;
    }
    |
    TYPE VAR
    {
        $$=(struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=DEFINE_VAR;
	    sprintf($$->bodyCode,"li $t0, 0\nsw $t0,%s($t8)\n", $2->addr);
	    $$->down=NULL;
        // since no value is assigned, we only need to allocate memory. We will use 0 as the garbage value.
    }
;

var_assign:
    VAR '=' exp
    {
        $$=(struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=ASSIGN_VAR;
	    sprintf($$->bodyCode,"%s\nsw $t0,%s($t8)\n", $3, $1->addr);
	    $$->down=NULL;
    }
    |
    VAR '=' var_assign
    {
        $$=(struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=ASSIGN_VAR;
	    sprintf($$->bodyCode,"%s\nsw $t0,%s($t8)\n", $3->bodyCode, $1->addr);
	    $$->down=NULL;
    }
;

exp_as_stmt:
    exp-common ';'
    {
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=EXP_STATEMENT;
	    sprintf($$->bodyCode,"%s\n", $1);
	    $$->down=NULL;
    }
;

syscll:
    SYSCALL '(' FORMAT ',' exp  ')' ';'
    {
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=SYSCALL_SYNTAX;
        if (strcmp($1,"printf") == 0) {
            sprintf($$->bodyCode,"%s", $5);
            }
        
    }
;

relop_exp:
    exp '>' exp
    {
        sprintf($$,"%s \nsw $t0, -4($sp)\nsub $sp, $sp, 4\n %s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t2, 0($sp)\naddi $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nsgt $t0, $t1,$t2",$1,$3); 
    }
    |
    exp '<' exp
    {
        sprintf($$,"%s \nsw $t0, -4($sp)\nsub $sp, $sp, 4\n %s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t2, 0($sp)\naddi $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nslt $t0, $t1,$t2",$1,$3); 
    }
    |
    exp LE_OP exp
    {
        sprintf($$,"%s \nsw $t0, -4($sp)\nsub $sp, $sp, 4\n %s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t2, 0($sp)\naddi $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nsle $t0, $t1,$t2",$1,$3);
    }
    |
    exp GE_OP exp
    {
        sprintf($$,"%s \nsw $t0, -4($sp)\nsub $sp, $sp, 4\n %s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t2, 0($sp)\naddi $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nsge $t0, $t1,$t2",$1,$3);
    }
    |
    exp-common NE_OP exp-common
    {
        sprintf($$,"%s \nsw $t0, -4($sp)\nsub $sp, $sp, 4\n %s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t2, 0($sp)\naddi $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nsne $t0, $t1,$t2",$1,$3);
    }
    |
    exp-common EQ_OP exp-common
    {
        sprintf($$,"%s \nsw $t0, -4($sp)\nsub $sp, $sp, 4\n %s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t2, 0($sp)\naddi $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nseq $t0, $t1,$t2",$1,$3);
    }
    |
    exp-common AND exp-common
    {
        sprintf($$,"%s \nsw $t0, -4($sp)\nsub $sp, $sp, 4\n %s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t2, 0($sp)\naddi $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nand $t0, $t1,$t2",$1,$3);
    }
    |
    exp-common OR exp-common
    {
        sprintf($$,"%s \nsw $t0, -4($sp)\nsub $sp, $sp, 4\n %s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t2, 0($sp)\naddi $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nor $t0, $t1,$t2",$1,$3);
    }
    |
    exp
    {
        sprintf($$, "%s\nmove $t1, $t0\nsne $t0, $t1, $0", $1);
    }
    |
    '(' relop_exp ')'        
    { 
        sprintf($$,"\n%s",$2); 
    }
    // The logical expression evaluates and stores the result (T/F) in $t0. 
    // Can be used directly in conditionals and loops by bne with $0
;


exp-common:
    exp { sprintf($$,$1); }
    |
    relop_exp   { sprintf($$,$1); }
    ;

exp:      
    x              { sprintf($$,"\n%s",$1); count=(count+1)%2; }
    |
    exp '+' exp        { sprintf($$,"\n%s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\n%s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nlw $t0, 0($sp)\naddi $sp, $sp, 4\nadd $t0, $t0, $t1",$1,$3); }
    | 
    exp '-' exp        { sprintf($$,"\n%s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\n%s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nlw $t0, 0($sp)\naddi $sp, $sp, 4\nsub $t0, $t0, $t1",$1,$3); }
    | 
    exp '*' exp        { sprintf($$,"\n%s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\n%s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nlw $t0, 0($sp)\naddi $sp, $sp, 4\nmul $t0, $t0, $t1",$1,$3); }
    |
    exp '/' exp        { sprintf($$,"\n%s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\n%s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nlw $t0, 0($sp)\naddi $sp, $sp, 4\ndiv $t0, $t0, $t1",$1,$3); }
    |
    exp MOD exp        { sprintf($$,"\n%s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\n%s\nsw $t0, -4($sp)\nsub $sp, $sp, 4\nlw $t1, 0($sp)\naddi $sp, $sp, 4\nlw $t0, 0($sp)\naddi $sp, $sp, 4\nrem $t0, $t0, $t1",$1,$3); }
    | 
    '-' exp  %prec NEG { sprintf($$,"\n%s\nneg $t0, $t0",$2); }
    | 
    '(' exp ')'        { sprintf($$,"\n%s",$2); }
    // The arithmetic expression evaluates and stores the result in $t0. 
    // Using push and pop in stack so there is no issue of register allocation
;

x:   
    NUM            { sprintf($$,"li $t%d, %d",count,$1); count=(count+1)%2; }
    | 
    VAR            { sprintf($$, "lw $t%d, %s($t8)",count,$1->addr); count=(count+1)%2; }
;

/* End of grammar */
%%

extern int linenum;
void yyerror (char *s)  /* Called by yyparse on error */
{
  fprintf (stderr, " line %d: %s\n", linenum, s);
}

