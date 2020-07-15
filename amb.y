%{
#include<stdio.h>
#include<ctype.h>
#include<string.h>
#include<stdlib.h>  
#include "amb.h"  /* Contains definition of `symrec' */

int  yylex(void);
void yyerror (char  *);

int count=0;
int label_count=0;
FILE *fp;

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

%union {
int   val;  /* For returning numbers.                   */
struct symrec  *tptr;   /* For returning symbol-table pointers      */
char c[10000];
char nData[100];
struct StmtNode *stmtptr;
struct ASTNode *ASTptr;
}


/* The above will cause a #line directive to come in calc.tab.h.  The #line directive is typically used by program generators to cause error messages to refer to the original source file instead of to the generated program. */

%token  <val> NUM        /* Integer   */
%token <val> RELOP LE_OP GE_OP NE_OP EQ_OP AND OR
%token  WHILE
%token FOR
%token IF
%token RETURN FORMAT
%token <val> TYPE
%token <tptr> MAIN VAR  
%token <nData> SYSCALL
%type  <c>  exp relop_exp
%type <nData> x
%type <ASTptr> stmts
%type <stmtptr> while_loop var_decl ret_stmt if_stmt stmt var_assign exp_as_stmt syscll


%right '='
%left '-' '+'
%left '*' '/' '%'
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
    if_stmt {$$ = $1; }
    |
    var_decl { $$ = $1; }
    |
    var_assign { $$ = $1; }
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
        $$->down=$5;
    }
;

// for_loop:
//     FOR '(' exp-option ';' exp-option ';' exp-option ';' ')' '{' stmts '}' {}
//     |
//     FOR '(' var_decl exp-option ';' exp-option ';' ')' '{' stmts '}' {}
// ;

if_stmt:
    IF '(' relop_exp ')' '{' stmts '}'
    {
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=IF_SYNTAX;
        sprintf($$->bodyCode,"%s", $3);
        sprintf($$->initJumpCode,"bge $t0, $0,");   
        $$->down=$6;
    }
    |
    IF '(' relop_exp ')' stmt
    {
        $$ = (struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=IF_SYNTAX;
        sprintf($$->bodyCode,"%s", $3);
        sprintf($$->initJumpCode,"bge $t0, $0,");   
        $$->down=$5;
    }
;

var_decl:
    TYPE VAR '=' exp ';'
    {
        $$=(struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=DEFINE_VAR;
	    sprintf($$->bodyCode,"%s\nsw $t0,%s($t8)\n", $4, $2->addr);
	    $$->down=NULL;
    }
    |
    TYPE VAR ';'
    {
        $$=(struct StmtNode *) malloc(sizeof(struct StmtNode)); $$->type=DEFINE_VAR;
	    sprintf($$->bodyCode,"li $t0, 0\nsw $t0,%s($t8)\n", $2->addr);
	    $$->down=NULL;
        // since no value is assigned, we only need to allocate memory. We will use 0 as the garbage value.
    }
;

var_assign:
    VAR '=' exp ';'
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
    exp ';'
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
    //TODO add here @mohit //add the instruction for register loading in $$. The beq is already there in both if/while.
;

exp-option:
    exp {}
    |
    "" {}
;

exp-common:
    exp {$$=$1;}
    |
    relop_exp   {$$=$1}
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
    '-' exp  %prec NEG { sprintf($$,"\n%s\nneg $t0, $t0",$2); }
    | 
    '(' exp ')'        { sprintf($$,"\n%s",$2); }
    // TODO: add %
;

x:   
    NUM            { sprintf($$,"li $t%d, %d",count,$1); count=(count+1)%2; }
    | 
    VAR            { sprintf($$, "lw $t%d, %s($t8)",count,$1->addr); count=(count+1)%2; }
;

/* End of grammar */
%%

void ASTTrav(ASTptr ptr){
    printf("stmts\n");
    if (ptr==NULL) return;
    if (ptr->singl==1){ 
        StmtTrav(ptr->left);
    } else {
    StmtTrav(ptr->left);
    ASTTrav(ptr->right);
    }
}
    
void StmtTrav(stmtptr ptr){
    int ws,nj;
    printf("stmt\n");
    if (ptr==NULL) return;

    else if (ptr->type==WHILE_SYNTAX){

        char *start_label = fresh_local_label("while_start", label_count);
        char *end_label = fresh_local_label("while_end", label_count);
        label_count ++;

        fprintf(fp, "%s:\n", start_label);
        fprintf(fp,"%s\n", ptr->bodyCode);
        fprintf(fp, "%s %s\n",ptr->initJumpCode,end_label);
        ASTTrav(ptr->down);
        fprintf(fp,"j %s\n%s:",start_label, end_label);

    } else if (ptr->type==IF_SYNTAX){
        
        char *end_label = fresh_local_label("if_end", label_count);
        label_count ++;
        printf("reached body\n");
        fprintf(fp,"%s\n", ptr->bodyCode);
        fprintf(fp, "%s %s\n",ptr->initJumpCode,end_label);
        printf("reached trav\n");
        ASTTrav(ptr->down);
        fprintf(fp,"j %s\n%s:",end_label, end_label);
       
    } else if (ptr->type==SYSCALL_SYNTAX){
        fprintf(fp,"%s\n",ptr->bodyCode);
        fprintf(fp, "li $v0, 1\nmove $a0, $t0\nsyscall\n"); //assuming exp is stored in $t0 TODO: @mohit chnge
        
    }else{
        fprintf(fp,"%s\n",ptr->bodyCode);
    }	  
}
   
int main ()
{
   fp=fopen("asmb.asm","w");
   fprintf(fp,".data\n\n.text\nli $t8,268500992\n"); //added li $t8 command to store initial memory address for symbol table
   yyparse ();
   ASTTrav(final);
   fclose(fp);
}

void yyerror (char *s)  /* Called by yyparse on error */
{
  printf ("%s\n", s);
}

