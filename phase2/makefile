CC=gcc
FLEX=flex
BISON=bison
splc:
	@mkdir -p bin
	touch bin/splc
	@chmod +x bin/splc
	$(BISON) -d syntax.y
	$(FLEX) lex.l
	$(CC) -Wall -fsanitize=address syntax.tab.c script/type_table.c script/linked_list.c -lfl -o bin/splc
clean:
	@rm -rf lex.yy.c syntax.tab.c syntax.tab.h bin 
.PHONY: splc