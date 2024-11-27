# Introduction to Glide

Glide is a parser combinator library for Gleam.
Glide makes it simple to develop robust parsers with pretty error handling, at the cost of some performance.
It is heavily inspired by [MegaParsec](https://hackage.haskell.org/package/megaparsec).

Glide can be installed through the Gleam CLI:

```
gleam add glide
```

## Getting Started

A parser combinator is a function that takes in some input and returns a result and the remaining input.
Conceptually, it works as follows:

```gleam
parse_number("123 foo !?") // -> #(123, " foo !?")
```

Like above, some Glide parsers consume input directly:

- `glide.token` matches a single input token. For strings, this is a character.
- `glide.satisfy` matches a token satisfying a predicate, such as `fn (ch) { ch == "a" || ch == "b" }`.
- `glide.any` matches any token.
- `glide.pure` matches nothing but returns a constant value.
- `glide.eof` matches the end of the input.
- `text.match` matches a regex against the textual input.
- `text_util.decimal` matches a decimal number.
- `text_util.string_lit` matches a string literal.

Other parsers combine simpler parsers:

- `glide.maybe(p)` tries to parse `p`, returning a `Result(a, Nil)`.
- `glide.many(p)` parses zero or more `p`s.
- `ops.choice(ps)` parses one of the parsers in `ps`, trying them in order.
- `glide.sep(p, by: sep)` parses `p` separated by `sep`.
- `glide.between(open, p, close)` parses `p` between `open` and `close`, returning `p`.
- `glide.map(p, f)` parses `p` and applies `f` to the result.

For example, a parser for a list of integers is defined as:

```gleam
let many_ints = ops.sep(text_util.decimal(), by: glide.token(","))
```

## Running Parsers

Parsers are run with `glide.run`, which takes a parser, input, and an initial context value.
This is usually `Nil` for simple parsers.

```gleam
glide.run(many_ints, text.new("1,2,3"), Nil)
// -> Ok([1, 2, 3])
```

When a parser fails, it returns a `Result` with an error message.
This message can be pretty-printed with `error.pretty`:

```gleam
let assert Error(e) = glide.run(many_ints, text.new("1,2,foo"), Nil)
error.pretty(e, color: False)
// -> Parse error: Expected decimal, got "f" ...
```

## Writing Parsers

This section is a demonstration of writing a simple parser for s-expressions.
The parser will accept lists, symbols, numbers, and null (renamed from `nil` to avoid
clashing with Gleam's `Nil`).
This means it should parse strings that look like the following:

```lisp
(def inc (x) (+ x 1))
(print (inc 3.2 . inc 5))
```

The formal grammar of this language is as follows:

```
sexpr ::= list | symbol | number
list ::= "(" list-rest
list-rest ::= ")" | "." sexpr ")" | sexpr list-rest
symbol ::= /[^s\]+/
number ::= /-?[0-9][1-9]*(\.[0-9]+)?/
```

First we need a datatype to store sexpression.
Each form becomes a constructor:

```gleam
type Sexpr {
  Cons(Sexpr, Sexpr)
  Symbol(String)
  Number(Float)
  Null
}
```

Then, we can write a function for each rule of the grammar.
The parser for an s-expression is a choice between three possible parsers:

```gleam
fn sexpr() {
  ops.choice([list(), number(), symbol()])
}
```

Let's look at the implementation of `symbol` first.

```gleam
fn symbol() {
  use <- glide.label("symbol")
  text.match("[^\\s().]+")
  |> ws()
  |> glide.map(Symbol)
}
```

The `label` combinator is added to give the parser a helpful name - this means that a user
sees 'Expected symbol' instead of 'Expected regex'.
The parser also suffixes `text.match` with the `text_util.ws()`, which parses whitespace after the symbol.
It's important to add this to all parsers that consume input directly (like `text.match`, `glide.satisfy`, etc) to make sure the parser 'skips over' whitespace.

The `number` parser is quite similar, instead using the `text_util.number` combinator:

```gleam
fn number() {
  use <- glide.label("number")
  text_util.number()
  |> ws()
  |> glide.map(Number)
}
```

The parser for lists is more complex, as it contains alternatives.
For each possibility, we can write a parser, then combine them with `ops.choice`.
This parser employs `use` syntax.
This is a convenient way to sequence parsers using `do()` for keeping a result and
`drop()` for ignoring it.
Using this syntax, returned values that aren't other parsers must be wrapped in `pure`.

```gleam

fn list() {
  use <- glide.label("list")
  use <- drop(glide.token("(") |> ws())
  list_rec()
}

fn list_rec() {
  ops.choice([list_end(), list_dot_end(), list_rest()])
}

fn list_end() {
  use <- drop(glide.token(")") |> ws())
  pure(Null)
}

fn list_dot_end() {
  use <- drop(glide.token(".") |> ws())
  use x <- do(sexpr())
  use <- drop(glide.token(")") |> ws())
  pure(x)
}

fn list_rest() {
  use x <- do(sexpr())
  use xs <- do(list_rec())
  pure(Cons(x, xs))
}
```

We can see this parser in action as follows:

```gleam
let in = text.new("(+ 1 2)")
glide.run(sexpr(), in, Nil)
|> should.equal(
  Ok(Cons(Symbol("+"), Cons(Number(1.0), Cons(Number(2.0), Null)))),
)
```

## Advanced Use

This section covers more advanced features of Glide.
Most parsers can be written without these features.

### Context Value

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

### Position

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

### Custom Streams

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
