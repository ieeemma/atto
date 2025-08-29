# calculator

A calculator example for `atto`.

The program accepts expressions with the following syntax:

- Numbers (`123`)
- Infix operators (`+-*/`) with precedence
- Prefix operators (`+-`)
- Postfix increment and decrement operators (`++` and `--`)

```
$ echo "3 + 2 * (-3 + 7)++" | gleam run
13
```
