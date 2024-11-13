//// Parser combinators for constructing layout, such as `many` and `choice`.

import gleam/list
import gleam/result
import gleam/set
import glide.{type Parser, do, drop, pure}

/// Try to apply a parser, returning `Nil` if it fails without consuming input.
/// 
/// ## Examples
/// 
/// ```gleam
/// ops.maybe(token("a"))
/// |> run(text.new("a"), Nil)
/// // -> Ok(Ok("a"))
/// ```
/// 
/// ```gleam
/// ops.maybe(token("a"))
/// |> run(text.new("b"), Nil)
/// // -> Ok(Error(Nil))
/// ```
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
/// 
/// ## Examples
/// 
/// ```gleam
/// ops.choice([token("a"), token("b")])
/// |> run(text.new("a"), Nil)
/// // -> Ok("a")
/// ```
/// 
/// ```gleam
/// ops.choice([text.match("foo"), text.match("bar")])
/// |> run(text.new("f123"), Nil)
/// // -> Error(ParseError(Pos(1, 1), Token("f"), Set([Msg("Regex failed")]))
/// ```
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
      use #(t, _, _) <- result.try(glide.get_token(in, pos))
      Error(glide.ParseError(pos, glide.Token(t), err))
    }
  }
}

/// Parse zero or more `p`.
/// 
/// ## Examples
/// 
/// ```gleam
/// ops.many(token("a"))
/// |> run(text.new("aaa"), Nil)
/// // -> Ok(["a", "a", "a"])
/// ```
/// 
/// ```gleam
/// ops.many(token("a"))
/// |> run(text.new("bbb"), Nil)
/// // -> Ok([])
/// ```
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

/// Parse one or more `p`.
/// 
/// ## Examples
/// 
/// ```gleam
/// ops.some(token("a"))
/// |> run(text.new("aaa"), Nil)
/// // -> Ok(["a", "a", "a"])
/// ```
/// 
/// ```gleam
/// ops.some(token("a"))
/// |> run(text.new("bbb"), Nil)
/// // -> Error(ParseError(Pos(1, 1), Token("b"), set.insert(set.new(), Token("a"))))
/// ```
pub fn some(p: Parser(a, t, s, c, e)) -> Parser(List(a), t, s, c, e) {
  use x <- do(p)
  many(p) |> glide.map(fn(xs) { [x, ..xs] })
}

/// Parse one or more `p` separated by a delimiter.
/// 
/// ## Examples
/// 
/// ```gleam
/// ops.sep_by_1(token("a"), token(","))
/// |> run(text.new("a,a,a"), Nil)
/// // -> Ok(["a", "a", "a"])
/// ```
pub fn sep1(
  p: Parser(a, t, s, c, e),
  by by: Parser(b, t, s, c, e),
) -> Parser(List(a), t, s, c, e) {
  use x <- do(p)
  use xs <- do(many(do(by, fn(_) { p })))
  pure([x, ..xs])
}

/// Zero or more parsers separated by a delimiter.
pub fn sep(
  p: Parser(a, t, s, c, e),
  by by: Parser(b, t, s, c, e),
) -> Parser(List(a), t, s, c, e) {
  choice([sep1(p, by), pure([])])
}

/// Parse `p` between `open` and `close`, returning the result of `p`.
/// 
/// ## Examples
/// 
/// ```gleam
/// ops.between(token("("), token("a"), token(")"))
/// |> run(text.new("(a)"), Nil)
/// // -> Ok("a")
/// ```
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
