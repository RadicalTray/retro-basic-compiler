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
- limitations: doesn't support empty files, and nested expressions

- IMPORTANT: handle newline/eof at the end there is no guarantee that there's a newline

Grammar
```
program: line+
line: line_number statement newline
statement:
        | assignment
        | if
        | print
        | goto
        | stop

assignment: id '=' expression
# NEEDS WORK
expression: (id | constant) ('+' | '-') (id | constant)

if: 'IF' condition line_number
condition: (id | constant) ('<' | '<=' | '=' | '>=' | '>') (id | constant)

print: 'PRINT' id

goto: 'GOTO' line_number

stop: 'STOP'

line_number: 0 ... 1000
constant: 0 ... 100
id: A ... Z
```
