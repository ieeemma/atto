# glide

Robust and extensible parser-combinators for Gleam.

```glide
fn number() {
  use digits <- do(glide.match("[1-9][0-9]*"))
  let assert Ok(n) = int.from_string(digits)
  n
}

fn number_list() {
  glide.between(
    glide.token("["),
    glide.sep(number, by: glide.token(",")),
    glide.token("]"),
  )
}

glide.run(number_list, text.new("[1,23,5]", Nil))
// -> Ok([1, 23, 5])

```

## Features

- Combinators for building parsers, such as `many`, `sep`, and `between`.
- Beautiful error messages.
- Custom stream type support, so `glide` works with a lexer step or on non-string data.
- Custom context value for contextual grammars.

## Resources

- [Introduction](INTRO.md) for a quick start on writing parsers.
- [Documentation](https://hexdocs.pm/party/).
- [JSON parser example](./test/json_test.gleam) in tests.
