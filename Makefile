cutec: amb.tab.o lex.yy.o main.c
	cc -g amb.tab.o lex.yy.o main.c -lfl

amb.tab.o: amb.tab.h amb.tab.c
	cc -g -c amb.tab.c

lex.yy.o: amb.tab.h lex.yy.c
	cc -g -c lex.yy.c

lex.yy.c: tok.l
	flex tok.l

amb.tab.h: amb.y
	bison -d amb.y

clean:
	rm amb.tab.c amb.tab.o lex.yy.o a.out amb.tab.h lex.yy.c

