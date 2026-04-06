```
10 A = 1
20 S = 0
30 IF 10 < A 70
40 S = S + A
50 A = A + 1
60 GOTO 30
70 PRINT S
80 STOP
```

A program in Retro Basic consists of lines.
Each line starts with line_number follows by a statement.
Statements are a) assignment b) if c) print d) goto e) stop.

An assignment is "id = exp" where id is {A..Z}.
An expression is binary op +/- between id and constant.
An if statement is "IF cond line_number", where cond is binary op {<,=} between id and constant.
A print statement is "PRINT id".
An goto statement is "GOTO line_num".
A stop statement is "STOP".
A constant is {0..100}.
line_num is {1..1000}

- give warning to invalid constant and line_num?
- dunno if IF > is supported, and if IF can compare between ids, and if expression can have multiple operations
- features: B-code/Retro-Basic interpreter

- limitations
    - no nested expressions (1 + 2 + 3)
    - line number and constant limits aren't enforced
    - stray newlines are allowed

Grammar
```text
eof: EOF

equal: '='
less: '<'
plus: '+'
minus: '-'
newline: '\n'

print: "PRINT"
goto: "GOTO"
stop: "STOP"
if: "IF"

number: NUMBER
identifier: UPPERCASE_CHARACTER

program: line* eof
line: number statement newline
statement:
        | assignment
        | if_statement
        | print_statement
        | goto_statement
        | stop_statement

assignment: id equal expression
expression:
         | value (plus | minus) value
         | value

if_statement: if condition line_number
condition: value less value

print_statement: print expression

goto_statement: goto number

stop_statement: stop

value:
    | identifier
    | number
```
