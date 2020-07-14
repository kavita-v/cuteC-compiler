/* Data type for links in the chain of symbols.      */
struct symrec
{
  char *name;  /* name of symbol                     */
  char addr[100];           /* value of a VAR          */
  struct symrec *next;    /* link field              */
};

typedef struct symrec symrec;
/* The symbol table: a chain of `struct symrec'.     */
extern symrec *sym_table;

symrec *putsym ();
symrec *getsym ();

typedef struct ASTNode *ASTptr;
typedef struct StmtNode *stmtptr;

typedef enum {
  RETURN_STATEMENT,
  DEFINE_VAR,
  WHILE_SYNTAX,
  IF_SYNTAX,
  ASSIGN_VAR
} StmtType;

struct ASTNode{
int singl;
struct StmtNode *left;
struct ASTNode *right;
};

struct StmtNode{
  StmtType type;
  char bodyCode[1000];
  struct ASTNode *down;
  union {
    char initCode[100];
    char initJumpCode[20];
  };
};




/*void StmtsTrav(stmtsptr ptr);
  void StmtTrav(stmtptr *ptr);*/
