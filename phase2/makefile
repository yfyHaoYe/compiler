CC=gcc
FLEX=flex
BISON=bison
splc:
	@mkdir -p bin
	touch bin/splc
	@chmod +x bin/splc
	$(BISON) -d syntax.y
	$(FLEX) lex.l
	$(CC) -Wall syntax.tab.c type_table.c linked_list.c -lfl -o bin/splc
clean:
	@rm -rf lex.yy.c syntax.tab.c syntax.tab.h bin 
.PHONY: splc