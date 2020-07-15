#include<stdio.h>
#include<ctype.h>
#include<string.h>
#include<stdlib.h> 

#include "amb.tab.h" 
#include "amb.h"


int label_count=0;
FILE *fp;
struct ASTNode *final;
void ASTTrav(ASTptr ptr);
void StmtTrav(stmtptr ptr);


void ASTTrav(ASTptr ptr){
    //printf("stmts\n");
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
    //printf("stmt\n");
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
        
        char *else_label = fresh_local_label("else", label_count);
        char *end_label = fresh_local_label("if_end", label_count);
        label_count ++;
        //check if condition
        fprintf(fp,"%s\n", ptr->bodyCode);
        //if false jump to else
        fprintf(fp, "%s %s\n",ptr->initJumpCode,else_label);
        // if block
        ASTTrav(ptr->down);
        // skip else jump to endif
        fprintf(fp,"j %s\n%s:",end_label, else_label);
        // else block
        ASTTrav(ptr->jump);
        //endif
        fprintf(fp,"%s:\n",end_label);

       
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

   printf("Written asmb.asm\nRun the assembly on MARS Simulator.\n");
   return 0;
}
