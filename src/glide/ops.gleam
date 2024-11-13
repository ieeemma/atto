import gleam/list
import gleam/result
import gleam/set
import glide.{type Parser, do, drop, pure}

/// Try to apply a parser, returning `Nil` if it fails without consuming input.
pub fn maybe(p: Parser(a, t, s, c, e)) -> Parser(Result(a, Nil), t, s, c, e) {
  fn(in, pos, ctx) {
    case p.run(in, pos, ctx) {
      Ok(#(x, in2, pos2, ctx2)) -> Ok(#(Ok(x), in2, pos2, ctx2))
      Error(glide.ParseError(pos2, _, _)) if pos == pos2 ->
        Ok(#(Error(Nil), in, pos, ctx))
      Error(e) -> Error(e)
    }
  }
  |> glide.Parser
}

/// Try each parser in order, returning the first successful result.
/// If a parser fails but consumes input, that error is returned.
pub fn choice(ps: List(Parser(a, t, s, c, e))) -> Parser(a, t, s, c, e) {
  fn(in, pos, ctx) { do_choice(ps, set.new(), in, pos, ctx) }
  |> glide.Parser
}

fn do_choice(ps: List(Parser(a, t, s, c, e)), err, in, pos, ctx) {
  case ps {
    [p, ..ps] -> {
      case p.run(in, pos, ctx) {
        Error(glide.ParseError(pos2, _, exp)) if pos == pos2 ->
          do_choice(ps, set.union(err, exp), in, pos, ctx)
        x -> x
      }
    }
    [] -> {
      use #(t, _, _) <- result.try(glide.get(in, pos))
      Error(glide.ParseError(pos, glide.Token(t), err))
    }
  }
}

/// Zero or more parsers.
pub fn many(p: Parser(a, t, s, c, e)) -> Parser(List(a), t, s, c, e) {
  do_many(p, [])
}

// TODO: make this better using cps
fn do_many(p, acc) {
  use x <- do(maybe(p))
  case x {
    Ok(x) -> do_many(p, [x, ..acc])
    Error(_) -> pure(list.reverse(acc))
  }
}

/// One or more parsers.
pub fn some(p: Parser(a, t, s, c, e)) -> Parser(List(a), t, s, c, e) {
  use x <- do(p)
  many(p) |> glide.map(fn(xs) { [x, ..xs] })
}

/// One or more parsers separated by a delimiter.
pub fn sep_by_1(
  p: Parser(a, t, s, c, e),
  sep: Parser(b, t, s, c, e),
) -> Parser(List(a), t, s, c, e) {
  use x <- do(p)
  use xs <- do(many(do(sep, fn(_) { p })))
  pure([x, ..xs])
}

/// Zero or more parsers separated by a delimiter.
pub fn sep_by(
  p: Parser(a, t, s, c, e),
  sep: Parser(b, t, s, c, e),
) -> Parser(List(a), t, s, c, e) {
  choice([sep_by_1(p, sep), pure([])])
}

/// Run a parser between two other parsers, returning the result of the middle
pub fn between(
  open: Parser(_, t, s, c, e),
  p: Parser(a, t, s, c, e),
  close: Parser(_, t, s, c, e),
) -> Parser(a, t, s, c, e) {
  use <- drop(open)
  use x <- do(p)
  use <- drop(close)
  pure(x)
}
