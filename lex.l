%{
    #define EXIT_OK 0
    #define EXIT_FAIL 1

%}
letter [a-zA-Z]
letter_ {letter}|_
digit [0-9]
hex_digit [0-9a-fA-F]
char [^\n\t]
CharHex \\x
hex [Ox|OX]
TYPE  [int | float | char]
STRUCT struct
IF if
ELSE else
WHILE while
RETURN return
DOT \.
SEMI ;
SIN_QUOTE '
COMMA ,
ASSIGN =
LT <
LE <=
GT >
GE >=
NE !=
EQ ==
PLUS +
MINUS -
MUL *
DIV /
AND &&
OR ||
NOT !
LP (
RP )
LB [
RB ]
LC {
RC }
%%
{hex}{hex_digit}+ | {digit}+ {return INT}
({sin_quote}{char}{sin_quote})|({CharHex}{hex_digit}+) {return CHAR}
{letter_}({letter_}|{digit})* {return ID} 
{digit}+{DOT}{digit}+ {return FLOAT}
{TYPE} {return TYPE}
{STRUCT} {return STRUCT}
{IF} {return IF}
{ELSE} {return ELSE}
{WHILE} {return WHILE}
{RETURN} {return RETURN}
{COMMA} {return COMMA}
{ASSIGN} {return ASSIGN}
{LT} {return LT}
{LE} {return LE}
{GT} {return GT}
{GE} {return GE}
{NE} {return NE}
{EQ} {return EQ}
{PLUS} {return PLUS}
{MINUS} {return MINUS}
{MUL} {return MUL}
{DIV} {return DIV}
{AND} {return AND}
{OR} {return OR}
{NOT} {return NOT}
{LP} {return LP}
{RP} {return RP}
{LB} {return LB}
{RB} {return RB}
{LC} {return LC}
{RC} {return RC}
\n {}
[\t\r ]+ {}
%%
int main(int argc, char **argv){
    char *file_path;
    if(argc < 2){
        fprintf(stderr, "Usage: %s <file_path>\n", argv[0]);
        return EXIT_FAIL;
    } else if(argc == 2){
        file_path = argv[1];
        if(!(yyin = fopen(file_path, "r"))){
            perror(argv[1]);
            return EXIT_FAIL;
        }
        yylex();
        return EXIT_OK;
    } else{
        fputs("Too many arguments! Expected: 2.\n", stderr);
        return EXIT_FAIL;
    }
}
