# json_parser

A JSON parser example for `atto`.

The program accepts JSON through stdin, which is parsed, formatted, and printed back:

```
$ echo '{"foo": [1, 2, null]}' | gleam run
{"foo": [1.0, 2.0, null]}
```
