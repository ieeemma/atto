//// Parser combinators for parsing arbitrary stream types.

import gleam/result
import gleam/set.{type Set}

/// A position in the input stream.
pub type Pos {
  Pos(line: Int, col: Int)
}

/// An error that occurred during parsing.
pub type ParseError(e, t) {
  ParseError(pos: Pos, got: ErrorPart(t), expected: Set(ErrorPart(t)))
  Custom(pos: Pos, value: e)
}

/// An expected or found component of an error.
pub type ErrorPart(t) {
  Token(t)
  Msg(String)
}

/// An input to the parser.
/// This type is parameterised by the token type `t` and the token stream `s`.
/// It stores a stream value and a function to get the next token from the stream.
pub type ParserInput(t, s) {
  ParserInput(src: s, get: fn(s, Pos) -> Result(#(t, s, Pos), Nil))
}

/// Get the next token from the input stream.
/// 
/// ## Examples
/// 
/// ```gleam
/// get(text.new("foo"), Pos(1, 1))
/// // -> Ok(#("f", text.new("oo"), Pos(1, 2))
/// ```
pub fn get_token(
  in: ParserInput(t, s),
  pos: Pos,
) -> Result(#(t, ParserInput(t, s), Pos), ParseError(e, t)) {
  case in.get(in.src, pos) {
    Ok(#(t, src, pos2)) -> Ok(#(t, ParserInput(..in, src:), pos2))
    Error(_) -> Error(ParseError(pos, Msg("EOF"), set.new()))
  }
}

/// Parser monad.
/// This type is parameterised by the result `a`, the token `t`, the stream `s`, 
/// a custom context `c`, and the error type `e`.
pub type Parser(a, t, s, c, e) {
  Parser(
    run: fn(ParserInput(t, s), Pos, c) ->
      Result(#(a, ParserInput(t, s), Pos, c), ParseError(e, t)),
  )
}

/// Run a parser against an input stream, returning a result or an error.
/// 
/// ## Examples
/// 
/// ```gleam
/// ops.many(ops.choice([token("a"), token("b")]))
/// |> run(text.new("aaba"), Nil)
/// // -> Ok(["a", "a", "b", "a"])
/// ```
pub fn run(
  p: Parser(a, t, s, c, e),
  in: ParserInput(t, s),
  ctx: c,
) -> Result(a, ParseError(e, t)) {
  p.run(in, Pos(1, 1), ctx)
  |> result.map(fn(x) { x.0 })
}

/// Lift a value into the parser context.
pub fn pure(value: a) -> Parser(a, t, s, c, e) {
  Parser(fn(in, pos, ctx) { Ok(#(value, in, pos, ctx)) })
}

/// Fail with a custom error value.
pub fn fail(error: e) -> Parser(a, t, s, c, e) {
  Parser(fn(_, pos, _) { Error(Custom(pos, error)) })
}

/// Fail with a message.
pub fn fail_msg(msg: String) -> Parser(a, t, s, c, e) {
  Parser(fn(_, pos, _) { Error(ParseError(pos, Msg(msg), set.new())) })
}

/// Get the current position in the input stream.
/// 
/// ## Examples
/// 
/// ```gleam
/// {
///   use <- drop(token("a"))
///   use p1 <- do(pos())
///   use <- drop(token("b"))
///   use p2 <- do(pos())
///   pure(#(p1, p2))
/// }
/// |> run(text.new("ab"), Nil)
/// // -> Ok((Pos(1, 2), Pos(1, 3)))
/// ```
pub fn pos() -> Parser(Pos, t, s, c, e) {
  Parser(fn(in, pos, ctx) { Ok(#(pos, in, pos, ctx)) })
}

/// Get the current context value.
pub fn ctx() -> Parser(c, t, s, c, e) {
  Parser(fn(in, pos, ctx) { Ok(#(ctx, in, pos, ctx)) })
}

/// Modify the current context within a parser.
/// 
/// ## Examples
/// 
/// ```gleam
/// {
///   use <- with_ctx(fn(x) { x + 1 })
///   usw x <- ctx()
///   pure(x)
/// }
/// |> run(text.new(""), 5)
/// // -> Ok(6)
/// ```
pub fn ctx_put(
  f: fn(c) -> c,
  p: fn() -> Parser(a, t, s, c, e),
) -> Parser(a, t, s, c, e) {
  Parser(fn(in, pos, ctx) { p().run(in, pos, f(ctx)) })
}

/// Map a function over the result of a parser.
/// 
/// ## Examples
/// 
/// ```gleam
/// pure(5) |> map(fn(x) { x + 1 })
/// |> run(text.new(""), Nil)
/// // -> Ok(6)
/// ```
/// 
/// ```gleam
/// fail("oops!") |> map(fn(x) { x + 1 })
/// |> run(text.new(""), 5)
/// // -> Error(Custom(Pos(1, 1), "oops!"))
pub fn map(p: Parser(a, t, s, c, e), f: fn(a) -> b) -> Parser(b, t, s, c, e) {
  do(p, fn(x) { pure(f(x)) })
}

/// Compose two parsers. This can be used with `use` syntax.
/// 
/// ## Examples
/// 
/// ```gleam
/// {
///   use a <- do(token("a"))
///   use b <- do(token("b"))
///   pure(#(a, b))
/// }
/// |> run(text.new("ab"), Nil)
/// // -> Ok(("a", "b"))
/// ```
pub fn do(
  p: Parser(a, t, s, c, e),
  f: fn(a) -> Parser(b, t, s, c, e),
) -> Parser(b, t, s, c, e) {
  fn(in, pos, ctx) {
    result.try(p.run(in, pos, ctx), fn(x) { f(x.0).run(x.1, x.2, x.3) })
  }
  |> Parser
}

/// Compose two parsers, discarding the result of the first.
/// This is just a wrapper for `do` for convenient syntax with `use`.
/// 
/// ## Examples
/// 
/// ```gleam
/// use <- drop(token("a"))
/// ```
pub fn drop(
  p: Parser(a, t, s, c, e),
  q: fn() -> Parser(b, t, s, c, e),
) -> Parser(b, t, s, c, e) {
  do(p, fn(_) { q() })
}

/// Parse a token if it matches a predicate.
/// This should be labelled with `label` to provide a useful error message.
/// 
/// ## Examples
/// 
/// ```gleam
/// satisfy(fn(c) { c == "5" })
/// |> run(text.new("5"), Nil)
/// // -> Ok("5")
/// ```
/// 
/// ```gleam
/// {
///   use <- label("digit")
///   satisfy(fn(c) { "0" <= c && c <= "9" })
/// }
/// |> run(text.new("a"), Nil)
/// // -> Error(ParseError(Pos(1, 1), Token("a"), set.insert(set.new(), Msg("digit")))
/// ```
pub fn satisfy(f: fn(t) -> Bool) -> Parser(t, t, s, c, e) {
  fn(in: ParserInput(t, s), pos, ctx) {
    case get_token(in, pos) {
      Ok(#(t, in2, pos2)) ->
        case f(t) {
          True -> Ok(#(t, in2, pos2, ctx))
          False -> Error(ParseError(pos, Token(t), set.new()))
        }
      Error(e) -> Error(e)
    }
  }
  |> Parser
}

/// Parse any token.
pub fn any() -> Parser(t, t, s, c, e) {
  use <- label("any token")
  satisfy(fn(_) { True })
}

/// Parse a specific token.
/// This is a convenience wrapper around `satisfy`.
pub fn token(token: t) -> Parser(t, t, s, c, e) {
  satisfy(fn(t) { token == t })
}

/// Label a parser.
/// When this parser fails without consuming input, the 'expected' message
/// is set to this message.
/// 
/// ## Examples
/// 
/// ```gleam
/// {
///   use <- label("foo")
///   satisfy(fn(c) { c == "5" })
/// }
/// |> run(text.new("6"), Nil)
/// // -> Error(ParseError(Pos(1, 1), Token("6"), set.insert(set.new(), Msg("foo")))
/// ```
pub fn label(
  name: String,
  f: fn() -> Parser(a, t, s, c, e),
) -> Parser(a, t, s, c, e) {
  fn(in, pos, ctx) {
    let p = f()
    case p.run(in, pos, ctx) {
      Error(ParseError(pos2, got, _)) if pos == pos2 ->
        Error(ParseError(pos2, got, set.insert(set.new(), Msg(name))))
      x -> x
    }
  }
  |> Parser
}

/// Matches the end of input.
/// This should be placed at the end of the parser chain to ensure
/// that the entire input is consumed.
pub fn eof() -> Parser(Nil, t, s, c, e) {
  fn(in, pos, ctx) {
    case get_token(in, pos) {
      Ok(#(t, _, _)) ->
        Error(ParseError(pos, Token(t), set.insert(set.new(), Msg("EOF"))))
      Error(_) -> Ok(#(Nil, in, pos, ctx))
    }
  }
  |> Parser
}
