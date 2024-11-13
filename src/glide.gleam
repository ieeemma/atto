import gleam/result
import gleam/set.{type Set}

pub type Pos {
  Pos(line: Int, col: Int)
}

pub type ParseError(e, t) {
  ParseError(Pos, ErrorPart(t), Set(ErrorPart(t)))
  Custom(Pos, e)
}

pub type ErrorPart(t) {
  Token(t)
  Msg(String)
}

/// An input to the parser.
/// This type is parameterised by the token type `t` and the token stream `s`.
/// It provides a functions to get a token from the stream.
pub type ParserInput(t, s) {
  ParserInput(src: s, get: fn(s, Pos) -> Result(#(t, s, Pos), Nil))
}

pub fn get(
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

/// For simplicity, this type alias is enough.
pub type StringParser(a) =
  Parser(a, String, List(String), Nil, Nil)

pub fn run(
  p: Parser(a, t, s, c, e),
  in: ParserInput(t, s),
  ctx: c,
) -> Result(a, ParseError(e, t)) {
  p.run(in, Pos(1, 1), ctx)
  |> result.map(fn(x) { x.0 })
}

/// Lift a value into the parser context
pub fn pure(x: a) -> Parser(a, t, s, c, e) {
  Parser(fn(in, pos, ctx) { Ok(#(x, in, pos, ctx)) })
}

/// Fail with a custom error value
pub fn fail(err: e) -> Parser(a, t, s, c, e) {
  Parser(fn(_, pos, _) { Error(Custom(pos, err)) })
}

/// Fail with a given message
pub fn fail_msg(msg: String) -> Parser(a, t, s, c, e) {
  Parser(fn(_, pos, _) { Error(ParseError(pos, Msg(msg), set.new())) })
}

/// Get the current position in the input stream
pub fn pos() -> Parser(Pos, t, s, c, e) {
  Parser(fn(in, pos, ctx) { Ok(#(pos, in, pos, ctx)) })
}

/// Get the current context
pub fn ctx() -> Parser(c, t, s, c, e) {
  Parser(fn(in, pos, ctx) { Ok(#(ctx, in, pos, ctx)) })
}

/// Modify the current context within a parser
pub fn with_ctx(
  f: fn(c) -> c,
  p: Parser(a, t, s, c, e),
) -> Parser(a, t, s, c, e) {
  Parser(fn(in, pos, ctx) { p.run(in, pos, f(ctx)) })
}

/// Map over a parser
pub fn map(p: Parser(a, t, s, c, e), f: fn(a) -> b) -> Parser(b, t, s, c, e) {
  do(p, fn(x) { pure(f(x)) })
}

/// Compose two parsers
pub fn do(
  p: Parser(a, t, s, c, e),
  f: fn(a) -> Parser(b, t, s, c, e),
) -> Parser(b, t, s, c, e) {
  fn(in, pos, ctx) {
    result.try(p.run(in, pos, ctx), fn(x) { f(x.0).run(x.1, x.2, x.3) })
  }
  |> Parser
}

/// Compose two parsers, discarding the result of the first
pub fn drop(
  p: Parser(a, t, s, c, e),
  q: fn() -> Parser(b, t, s, c, e),
) -> Parser(b, t, s, c, e) {
  do(p, fn(_) { q() })
}

/// Parse a token if it matches a predicate.
/// This should be labelled!
pub fn satisfy(f: fn(t) -> Bool) -> Parser(t, t, s, c, e) {
  fn(in: ParserInput(t, s), pos, ctx) {
    case get(in, pos) {
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

/// Parse a single token.
pub fn any() -> Parser(t, t, s, c, e) {
  use <- label("any token")
  satisfy(fn(_) { True })
}

/// Parse a specific token.
pub fn token(t: t) -> Parser(t, t, s, c, e) {
  satisfy(fn(t2) { t == t2 })
}

/// Label a parser.
/// When this parser fails without consuming input, the 'expected' message
/// is set to this message.
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
pub fn eof() -> Parser(Nil, t, s, c, e) {
  fn(in, pos, ctx) {
    case get(in, pos) {
      Ok(#(t, _, _)) ->
        Error(ParseError(pos, Token(t), set.insert(set.new(), Msg("EOF"))))
      Error(_) -> Ok(#(Nil, in, pos, ctx))
    }
  }
  |> Parser
}
