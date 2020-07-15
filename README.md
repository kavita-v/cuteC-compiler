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
- Supports int datatype
- Binary operations
- comparision operators
- multiline commnents
- variable declaration and assignment (local)
- printf() syscall added
- support for while loop added
- supports if-else statement (no else if support yet)

### Things to look out for
- Program should have exactly one int main() function. 
- Only one return statement that terminates the program. Return value is printed out.
- Unterminated multiline comments identified.
- Declare variables of type int 
- Return arithmetic expressions (like a+b) or logical expressions (like a>b)
- multi-operand arithmetic expressions with BODMAS precedence rule

## Contributors:
- Kavita Vaishnaw
- Heer Ambavi
- Mohit Mina

We would like to thank Prof. Bireswar Das, IIT Gandhinagar for the opportunity :).
