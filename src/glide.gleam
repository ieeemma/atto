import gleam/regex
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
/// It provides a functions to get a token from the stream.
pub type ParserInput(t, s) {
  ParserInput(src: s, get: fn(s, Pos) -> Result(#(t, s, Pos), Nil))
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

/// Try to apply a parser, returning `Nil` if it fails without consuming input.
pub fn optional(p: Parser(a, t, s, c, e)) -> Parser(Result(a, Nil), t, s, c, e) {
  fn(in, pos, ctx) {
    case p.run(in, pos, ctx) {
      Ok(#(x, in2, pos2, ctx2)) -> Ok(#(Ok(x), in2, pos2, ctx2))
      Error(ParseError(pos2, _, _)) if pos == pos2 ->
        Ok(#(Error(Nil), in, pos, ctx))
      Error(e) -> Error(e)
    }
  }
  |> Parser
}

/// Zero or more parsers.
pub fn many(p: Parser(a, t, s, c, e)) -> Parser(List(a), t, s, c, e) {
  use x <- do(optional(p))
  case x {
    Ok(x) -> many(p) |> map(fn(xs) { [x, ..xs] })
    Error(_) -> pure([])
  }
}

/// One or more parsers.
pub fn some(p: Parser(a, t, s, c, e)) -> Parser(List(a), t, s, c, e) {
  use x <- do(p)
  many(p) |> map(fn(xs) { [x, ..xs] })
}

/// Try each parser in order, returning the first successful result.
/// If a parser fails but consumes input, that error is returned.
pub fn choice(ps: List(Parser(a, t, s, c, e))) -> Parser(a, t, s, c, e) {
  do_choice(ps, set.new())
}

fn do_choice(
  ps: List(Parser(a, t, s, c, e)),
  err: Set(ErrorPart(t)),
) -> Parser(a, t, s, c, e) {
  // TODO: whats the performance of wrapping in a parser? does it need to be?
  fn(in, pos, ctx) {
    case ps {
      [p, ..ps] ->
        case p.run(in, pos, ctx) {
          Error(ParseError(pos2, _, exp)) if pos == pos2 ->
            do_choice(ps, set.union(err, exp)).run(in, pos, ctx)
          x -> x
        }
      [] -> {
        use #(t, _, _) <- result.try(get(in, pos))
        Error(ParseError(pos, Token(t), err))
      }
    }
  }
  |> Parser
}

// TODO: This needs a javascript-specific implementation, as
// the string slicing will likely be really inefficient.
pub fn string_input(src: String) -> ParserInput(String, String) {
  ParserInput(src, string_input_get)
}

fn string_input_get(s: String, p: Pos) -> Result(#(String, String, Pos), Nil) {
  case string.pop_grapheme(s) {
    Ok(#("\n", ts)) -> Ok(#("\n", ts, Pos(p.line + 1, p.col)))
    Ok(#(t, ts)) -> Ok(#(t, ts, Pos(p.line, p.col + 1)))
    Error(_) -> Error(Nil)
  }
}

pub fn match(r: String) -> Parser(String, String, String, Nil, Nil) {
  case regex.from_string("^" <> r) {
    Ok(r) -> fn(in: ParserInput(String, String), pos, ctx) {
      case regex.scan(r, in.src) {
        [] -> Error(ParseError(pos, Msg("Regex failed"), set.new()))
        [m] -> {
          let x = m.content
          let xs = string.drop_left(in.src, string.length(m.content))
          let p = advance_pos_string(pos, x)
          Ok(#(x, ParserInput(..in, src: xs), p, ctx))
        }
        [_, ..] -> panic as "Multiple scan matches"
      }
    }
    Error(e) -> fn(_, pos, _) {
      Error(ParseError(pos, Msg(e.error), set.new()))
    }
  }
  |> Parser
}

fn advance_pos_string(p: Pos, x: String) -> Pos {
  case string.pop_grapheme(x) {
    Ok(#("\n", x)) -> advance_pos_string(Pos(p.line + 1, 1), x)
    Ok(#(_, x)) -> advance_pos_string(Pos(p.line, p.col + 1), x)
    Error(_) -> p
  }
  }
  |> Parser
}
