# cuteC-compiler
cuteC-compiler (Come Undo Those Exceptions-C Compiler) is a mini-version (implementing a drop from the ocean that is C) of a C-compiler written in C for MIPS architecture.

## How to run?
Run these commands in the root directory of the repo:

### Compiling cuteC
```
make
```
### Running tests
```
./a.out<test/testFile.c
```
Open asmb.asm file in Mars. Assemble and Run.

## Features:
- Supports `int` datatype (positive and negative integers both)
- Arithmetic operations: `+ - / * %`
- Relational operators: `== != > < >= <=`
- Logical operators: `&& ||`
- Single line and Multiline comments: 
- Variable declaration and assignment (local)
- Supports `printf()` syscall 
- Supports `while` loops 
- Supports `for` loops
- Supports nested loops
- Supports `if, else if, else` statements (nested ifs)
- Verbose error reporting with line number 
- Unterminated multiline comments reported as error
- Can return arithmetic expressions (like a+b) or logical expressions (like a>b)

## Things to look out for
- Program should have exactly one `int main()` function. 
- Only one return statement that terminates the program. Return value is printed out.
- Declare all variables to be of type `int` 
- Multi-operand arithmetic and logical expressions follow BODMAS precedence rule
- For loop should follow the format: `for (i=0;i<10;i=i+1)`
- For loop works in the same scope as the main function. So, same variable names cannot be reused inside the for loop.

## Contributors:
- Kavita Vaishnaw (17110073)
- Heer Ambavi (16110062)
- Mohit Mina (17110078)

We would like to thank Prof. Bireswar Das, IIT Gandhinagar for the opportunity :)
