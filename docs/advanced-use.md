# Advanced Use

This section covers more advanced features of Glide.
Most parsers can be written without these features.

## Context Value

The context value is threaded through each parser, and can be used to store state or configuration.
For most parsers it can be set to `Nil`.

For example, imagine a contextual grammar that allows `a`s and `b`s in any order, but requires the same number of each.
This can be implemented with the `ctx` combinator for receiving and `ctx_put` for setting the context value.

```gleam
fn a_and_b() {
  use <- glide.ctx_put(fn(_) { 0 })
  use <- drop(ops.many(ops.choice([a(), b()])))
  use count <- do(glide.ctx())
  case count == 0 {
    True -> pure(Nil)
    False -> glide.fail_msg("Expected equal number of a and b")
  }
}

fn a() {
  use <- drop(glide.token("a"))
  use <- glide.ctx_put(fn(x) { x + 1 })
  pure(Nil)
}

fn b() {
  use <- drop(glide.token("b"))
  use <- glide.ctx_put(fn(x) { x - 1 })
  pure(Nil)
}

a_and_b()
|> glide.run(text.new("aababbab"), 0)
// -> Ok(Nil)

a_and_b()
|> glide.run(text.new("aababab"), 0)
// -> Error("Expected equal number of a and b")
```

## Position

The position in the input can be read with the `glide.pos` parser, which consumes no input and returns the current position.
This is useful for attaching position information to AST nodes.

For example:

```gleam
type Spanned(a) {
    Spanned(a, glide.Span)
}

fn spanned(p) {
    use start <- do(glide.pos())
    use x <- do(p)
    use end <- do(glide.pos())
    pure(Spanned(x, glide.Span(start, end)))
}
```

## Custom Streams

Custom stream types are useful when parsing arbitrary data types, or when a lexer step is required.
The only requirement to produce a custom stream type is to implement a value of the `glide.ParserInput` type.

This type has three functions:

- ```gleam
  fn get(s, #(Int, Int)) -> Result(#(t, s, #(Int, Int)), Nil)
  ```

  This function takes the current stream type (`s`) and a line/column position, and returns
  the next token, the new stream, and the new line/column, or `Error(Nil)` at EOF.

- ```gleam
  fn render_token(t) -> String
  ```

  This function takes a token and returns a string representation of it to be displayed when prettyprinting
  an error message.

- ```gleam
  fn render_span(s, Span) -> #(String, String, String)
  ```

  This function takes the original stream data and a span, then returns a 'context window' into the stream.
  The first string is some context before the span, the second is the span itself, and the third is some context after the span.
  This function can be tricky to implement, but is necessary to map line/column positions to the original stream data.

  If you don't care about prettyprinting errors, this function could return `#("", "", "")` for all inputs.

For a practical example of implementing a stream type, [see how it works for strings](./src/glide/text.gleam#L12).
