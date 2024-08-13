import gleam/list
import gleam/result
import gleam/set.{type Set}
import gleam/string

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
/// It provides functions to get and peek the stream.
pub type ParserInput(t, s) {
  ParserInput(
    src: s,
    get: fn(s, Pos) -> Result(#(t, s, Pos), Nil),
    peek: fn(s) -> Result(t, Nil),
  )
}

/// Create a parser input from a string.
/// The token type is a character, and the stream type is a list of graphemes.
pub fn string_input(src: String) -> ParserInput(String, List(String)) {
  let get = fn(x: List(String), p: Pos) {
    case x {
      ["\n", ..ts] -> Ok(#("\n", ts, Pos(p.line + 1, p.col)))
      [t, ..ts] -> Ok(#(t, ts, Pos(p.line, p.col + 1)))
      [] -> Error(Nil)
    }
  }
  ParserInput(string.to_graphemes(src), get, list.first)
}

fn get(
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
pub opaque type Parser(a, t, s, c, e) {
  Parser(
    run: fn(ParserInput(t, s), Pos, c) ->
      Result(#(a, ParserInput(t, s), Pos, c), ParseError(e, t)),
  )
}

/// For simplicity, this type alias is enough.
pub type StringParser(a) =
  Parser(a, String, List(String), Nil, Nil)

/// Lift a value into the parser context
pub fn pure(x: a) -> Parser(a, t, s, c, e) {
  Parser(fn(in, pos, ctx) { Ok(#(x, in, pos, ctx)) })
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
