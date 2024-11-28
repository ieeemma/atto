# atto

Robust and extensible parser-combinators for Gleam.

```gleam
fn number() {
  use digits <- do(atto.match("[1-9][0-9]*"))
  let assert Ok(n) = int.from_string(digits)
  n
}

fn number_list() {
  atto.between(
    atto.token("["),
    atto.sep(number, by: atto.token(",")),
    atto.token("]"),
  )
}

atto.run(number_list, text.new("[1,23,5]", Nil))
// -> Ok([1, 23, 5])
```

## Features

- Combinators for building parsers, such as `many`, `sep`, and `between`.
- Beautiful error messages.
- Custom stream type support, so `atto` works with a lexer step or on non-string data.
- Custom context value for contextual grammars.

## Resources

- [Quick start guide](./docs/quick-start.md) on writing parsers.
- [Documentation](https://hexdocs.pm/atto/).
- [JSON parser example](./test/json_test.gleam) in tests.
