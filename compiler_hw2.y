/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_hw_common.h" //Extern variables that communicate with lex
    #define MAX_SYMBOL_NUM 1000

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;
    int yyscope = 0;
    int yyaddr = 0;
    int line_count = 0;

    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", line_count+1, s);
    }

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol(char *, int, int, char *, char *);
    static char * lookup_symbol(char *);
    static void dump_symbol();
    
    struct symbol{
        char *name;
        char *type;
        int addr;
        int line;
        char *sign;
        struct symbol *next;
    };
    typedef struct symbol symbol;
    symbol *symboltable[MAX_SYMBOL_NUM];
%}

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    /* ... */
}

/* Token without return */
%token VAR NEWLINE
%token INT FLOAT BOOL STRING
%token INC DEC
%token GEQ LEQ EQL NEQ '>' '<'
%token '=' ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token IF ELSE FOR 
%token SWITCH CASE DEFAULT
%token PRINT PRINTLN
%token PACKAGE FUNC RETURN
%token TRUE FALSE

%token '+' '-' 
%token '*' '/' '%'
%token LOR LAND '!'

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT 
%token <s_val> IDENT

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type  /* use in type declaration */
%type <s_val> FuncOpen /* function name */
%type <s_val> ReturnType /* function return type */
%type <s_val> ParameterList
%type <s_val> Expression Term1 Term2 Term3 Term4    /* return type to check operation */
%type <s_val> UnaryExpr PrimaryExpr Operand Literal ConversionExpr  /* return type to check operation */
%type <s_val> unary_op com_op add_op mul_op assign_op   /* return type to check operation */

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%
/* Function */
Program
    : GlobalStatementList
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : PackageStmt NEWLINE { line_count = yylineno; }
    | FunctionDeclStmt  { line_count = yylineno+1; }
    | NEWLINE   { line_count = yylineno; }
;

PackageStmt
    : PACKAGE IDENT { printf("package: %s\n",$2); }
;

FunctionDeclStmt
    : FuncInfo FuncBlock  { }
;

FuncInfo
    : FuncOpen '(' ParameterList ')' ReturnType { char *temp;
                                                    printf("func_signature: (%s)%s\n", $3, $5);
                                                    asprintf(&temp, "(%s)%s", $3, $5);
                                                    insert_symbol($1, -1, yyscope-1, "func", temp); }
    | FuncOpen '(' ')' ReturnType   { char *temp;
                                        printf("func_signature: ()%s\n", $4);
                                        asprintf(&temp, "()%s", $4);
                                        insert_symbol($1, -1, yyscope-1, "func", temp); }
;

FuncOpen
    : FUNC IDENT    { printf("func: %s\n", $2);
                        yyscope++;
                        create_symbol();
                        $$ = $2; }
;

ParameterList
    : IDENT Type { char *type;
                    switch($2[0])
                    {
                        case 'i': type = "I"; break;
                        case 'f': type = "F"; break;
                        case 'b': type = "B"; break;
                        case 's': type = "S"; break;
                        default: type = "V"; break;
                    }
                    printf("param %s, type: %s\n", $1, type);
                    insert_symbol($1, yyaddr, yyscope, $2, "-"); 
                    yyaddr++;
                    $$ = type; }
    | ParameterList ',' IDENT Type  { char *type;
                                        switch($4[0])
                                        {
                                            case 'i': type = "I"; break;
                                            case 'f': type = "F"; break;
                                            case 'b': type = "B"; break;
                                            case 's': type = "S"; break;
                                            default: type = "V"; break;
                                        }
                                        printf("param %s, type: %s\n", $3, type);
                                        insert_symbol($3, yyaddr, yyscope, $4, "-"); 
                                        yyaddr++;
                                        char *temp;
                                        asprintf(&temp, "%s%s", $1, type);
                                        $$ = temp; }
;

ReturnType
    : INT   { $$ = "I"; }
    | FLOAT { $$ = "F"; }
    | BOOL  { $$ = "B"; }
    | STRING    { $$ = "S"; }
    | /* void */    { $$ = "V"; }
;

FuncBlock
    : '{' StatementList RBRACE {}
;

StatementList
    : StatementList Statement
    |
;

Statement
    : DeclartionStmt NEWLINE    { line_count = yylineno;}
    | SimpleStmt NEWLINE    { line_count = yylineno; }
    | Block { line_count = yylineno+1; }
    | IfStmt    { line_count = yylineno+1; }
    | ForStmt   { line_count = yylineno+1; }
    | SwitchStmt    { line_count = yylineno+1; }
    | CaseStmt  { line_count = yylineno+1; }
    | PrintStmt NEWLINE { line_count = yylineno; }
    | ReturnStmt NEWLINE    { line_count = yylineno; }
    | NEWLINE   { line_count = yylineno; }
;

ReturnStmt
    : RETURN    { printf("return\n"); }
    | RETURN Expression { printf("%creturn\n", $2[0]); }
;

SimpleStmt 
    : AssignStmt 
    | ExprStmt
    | IncDecStmt
;

DeclartionStmt
    : VAR IDENT Type '=' Expression { insert_symbol($2, yyaddr, yyscope, $3, "-"); 
                                            yyaddr++;}
    | VAR IDENT Type    { insert_symbol($2, yyaddr, yyscope, $3, "-"); 
                            yyaddr++;}
;

AssignStmt
    : Expression assign_op Expression   { if(strcmp($1, $3) != 0)
                                            {
                                                char *str;
                                                asprintf(&str, "invalid operation: ASSIGN (mismatched types %s and %s)", $1, $3);
                                                yyerror(str);
                                            }
                                            printf("%s\n", $2); }
;

assign_op
    : '='   { $$ = "ASSIGN";}
    | ADD_ASSIGN    { $$ = "ADD"; }
    | SUB_ASSIGN    { $$ = "SUB"; }
    | MUL_ASSIGN    { $$ = "MUL"; }
    | QUO_ASSIGN    { $$ = "QUO"; }
    | REM_ASSIGN    { $$ = "REM"; }
;

ExprStmt
    : Expression
;

IncDecStmt
    : Expression INC    { printf("INC\n"); }
    | Expression DEC    { printf("DEC\n"); }
;

IfStmt
    : IF Condition Block 
    | IF Condition Block ELSE IfStmt
    | IF Condition Block ELSE Block
;

Condition
    : Expression    { if(strcmp($1, "bool") != 0)
                        {
                            char *str;
                            asprintf(&str, "non-bool (type %s) used as for condition", $1);
                            yyerror(str);
                        } }
;

ForStmt
    : FOR Condition Block
    | FOR ForClause Block
;

ForClause
    : InitStmt ';' Condition ';' PostStmt
;

InitStmt
    : SimpleStmt
;

PostStmt
    : SimpleStmt
;

SwitchStmt
    : SWITCH Expression Block
;

CaseStmt
    : CASECondition Block
    | DEFAULT ':' Block
;

CASECondition
    : CASE INT_LIT ':'  { printf("case %d\n", $2); }
;

Block
    : LBRACE StatementList RBRACE {}
;

PrintStmt
    : PRINT '(' Expression ')'  { printf("PRINT %s\n", $3); }
    | PRINTLN '(' Expression ')'    { printf("PRINTLN %s\n", $3); }
;

/* 5-2 Expression */
Expression
    : Expression LOR Term1  { if( strcmp($1, "bool") != 0 )
                                {
                                    char *str;
                                    asprintf(&str, "invalid operation: (operator LOR not defined on %s)", $1);
                                    yyerror(str);
                                }
                                else if( strcmp($3, "bool") != 0 )
                                {
                                    char *str;
                                    asprintf(&str, "invalid operation: (operator LOR not defined on %s)", $3);
                                    yyerror(str);
                                }
                                printf("LOR\n");
                                $$ = "bool"; }
    | Term1 {$$ = $1;}
;

Term1
    : Term1 LAND Term2  { if( strcmp($1, "bool") != 0 )
                            {
                                char *str;
                                asprintf(&str, "invalid operation: (operator LAND not defined on %s)", $1);
                                yyerror(str);
                            }
                            else if( strcmp($3, "bool") != 0 )
                            {
                                char *str;
                                asprintf(&str, "invalid operation: (operator LAND not defined on %s)", $3);
                                yyerror(str);
                            }
                            $$ = "bool";
                            printf("LAND\n"); }
    | Term2 { $$ = $1; }
;

Term2
    : Term2 com_op Term3    { if(strcmp($1, $3) != 0)
                                {
                                    char *str;
                                    asprintf(&str, "invalid operation: %s (mismatched types %s and %s)", $2, $1, $3);
                                    yyerror(str);
                                }
                                $$ = "bool";
                                printf("%s\n", $2); }
    | Term3 { $$ = $1; }
;

Term3
    : Term3 add_op Term4 { if( strcmp($1, $3) )
                            {
                                char *str;
                                asprintf(&str, "invalid operation: %s (mismatched types %s and %s)", $2, $1, $3);
                                yyerror(str);
                                $$ = "ERROR";
                            }
                            else $$ = $1;
                            printf("%s\n", $2);}
    | Term4 { $$ = $1; }
;

Term4
    : Term4 mul_op UnaryExpr    { if(strcmp($2, "REM") == 0)
                                    {
                                        if(strcmp($1, "int32") != 0)
                                        {
                                            char *str;
                                            asprintf(&str, "invalid operation: (operator REM not defined on %s)", $1);
                                            yyerror(str);
                                            $$ = "ERROR";
                                        }
                                        else if(strcmp($3, "int32") != 0)
                                        {
                                            char *str;
                                            asprintf(&str, "invalid operation: (operator REM not defined on %s)", $3);
                                            yyerror(str);
                                            $$ = "ERROR";
                                        }
                                    }
                                    else if( strcmp($1, $3) )
                                    {
                                        char *str;
                                        asprintf(&str, "invalid operation: %s (mismatched type %s and %s)", $2, $1, $3);
                                        yyerror(str);
                                        $$ = "ERROR";
                                    }
                                    else $$ = $1;
                                    printf("%s\n", $2); }
    | UnaryExpr { $$ = $1;}
;

UnaryExpr
    : PrimaryExpr   { $$ = $1;}
    | unary_op UnaryExpr    { printf("%s\n", $1); 
                                $$ = $2; }
;

PrimaryExpr
    : Operand   { $$ = $1; }
    | ConversionExpr    { $$ = $1; }
;

Operand
    : Literal   { $$ = $1; }
    | IDENT { $$ = lookup_symbol($1);; }
    | IDENT '(' ')' { $$ = lookup_symbol($1); }
    | IDENT '(' Argument ')'    { $$ = lookup_symbol($1); }
    | '(' Expression ')'    { $$ = $2; }
;

Argument
    : Expression 
    | Argument ',' Expression
;

ConversionExpr
    : Type '(' Expression ')'   { char *ans;
                                    asprintf(&ans, "%c2%c", $3[0], $1[0]);
                                    $$ = $1;
                                    printf("%s\n", ans); }
;

Literal
    : INT_LIT   { printf("INT_LIT %d\n", $1); 
                    $$ = "int32"; }
    | FLOAT_LIT { printf("FLOAT_LIT %f\n", $1); 
                    $$ = "float32"; }
    | BOOL_LIT  { $$ = "bool"; }
    | '"' STRING_LIT '"'    { printf("STRING_LIT %s\n", $2);
                                $$ = "string"; }
;

BOOL_LIT
    : TRUE  { printf("TRUE 1\n"); }
    | FALSE { printf("FALSE 0\n"); }
;

unary_op
    : '+'   { $$ = "POS"; }
    | '-'   { $$ = "NEG"; }
    | '!'   { $$ = "NOT"; }
;

com_op
    : '>'   { $$ = "GTR"; }
    | '<'   { $$ = "LTR"; }
    | GEQ   { $$ = "GEQ"; }
    | LEQ   { $$ = "LEQ"; }
    | EQL   { $$ = "EQL"; }
    | NEQ   { $$ = "NEQ"; }
;

add_op
    : '+'   { $$ = "ADD"; }
    | '-'   { $$ = "SUB"; }
;

mul_op
    : '*'   { $$ = "MUL"; }
    | '/'   { $$ = "QUO"; }
    | '%'   { $$ = "REM"; }
;

Type
    : INT   { $$ = "int32"; }
    | FLOAT { $$ = "float32"; }
    | BOOL  { $$ = "bool"; }
    | STRING    { $$ = "string"; }
;

LBRACE
    : '{'   { yyscope++;
                create_symbol();}
;

RBRACE
    : '}'   { dump_symbol();
                yyscope-=1; }
;
%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    yylineno = 0;
    create_symbol();
    yyparse();
    dump_symbol();

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}

static void create_symbol() {
    printf("> Create symbol table (scope level %d)\n", yyscope);
    symboltable[yyscope] = NULL;
}

static void insert_symbol(char *name, int addr, int scope, char *type, char *sign) {
    /* create new symbol */
    symbol *newtemp = malloc(sizeof(symbol));
    newtemp->name =  name;
    newtemp->type = type;
    newtemp->sign = sign;
    newtemp->addr = addr;
    newtemp->line = line_count+1;
    newtemp->next = NULL;

    /* enter to correct scope, ypu can't have teo same name in one scope*/
    symbol *temp = symboltable[scope];
    symbol *temp_ex = NULL;
    if(temp == NULL) symboltable[scope] = newtemp;
    else
    {
        while(temp != NULL)
        {
            if(strcmp(temp->name, newtemp->name) == 0)
            {
                char *str;
                asprintf(&str, "%s redeclared in this block. previous declaration at line %d", temp->name, temp->line);
                yyerror(str);
            }
            temp_ex = temp;
            temp = temp->next;
        }
        temp_ex->next = newtemp;
    }
    printf("> Insert `%s` (addr: %d) to scope level %d\n", name, addr, scope);
}

static char * lookup_symbol(char* name) {
    int find = 0;
    symbol *target = NULL;
    for(int scope = yyscope; scope>=0; scope-=1)
    {
        symbol *temp = symboltable[scope];
        while(temp != NULL)
        {
            if( strcmp(temp->name, name) == 0 )
            {
                target = temp;
                find = 1;
                break;
            }
            temp = temp->next;
        }
        if(find) break;
    }
    
    /* if we can't find the variable */
    if(!find)
    {
        char *str;
        asprintf(&str, "undefined: %s", name);
        yyerror(str);
        return "ERROR";
    }

    /* if the variable is function */
    if(strcmp("func", target->type) == 0)
    {
        printf("call: %s%s\n", target->name, target->sign);
        switch((target->sign)[strlen(target->sign)-1])
        {
            case 'I': return "int32"; break;
            case 'F': return "float32"; break;
            case 'B': return "bool"; break;
            case 'S': return "string"; break;
            default: return "void"; break;
        }
    }
    else printf("IDENT (name=%s, address=%d)\n", target->name, target->addr);
    return target->type;
}

static void dump_symbol() {
    printf("\n> Dump symbol table (scope level: %d)\n", yyscope);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Func_sig");
    
    symbol *temp = symboltable[yyscope];
    symbol *temp_ex = NULL;
    int count = 0;
    while(temp != NULL)
    {
        printf("%-10d%-10s%-10s%-10d%-10d%-10s\n",
            count, temp->name, temp->type, temp->addr, temp->line, temp->sign);
        temp_ex = temp;
        temp = temp->next;
        free(temp_ex);
        count++;
    }
    printf("\n");
}