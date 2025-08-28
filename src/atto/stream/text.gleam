import atto
import gleam/bool
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string

pub type Parser(a) =
  atto.Parser(a, String, String, List(String), Pos, Nil, Nil)

/// Create a state from a string input.
pub fn new(src: String, ctx: c) -> atto.State(List(String), Pos, c) {
  atto.State(string.to_graphemes(src), Pos(1, 1), ctx)
}

/// Create a text stream interface.
pub fn stream() -> atto.Stream(String, String, List(String), Pos, c) {
  atto.make_stream(
    get: get,
    gets: gets,
    cmp_pos: cmp,
    len: string.length,
    eq_tok: fn(a, b) { a == b },
    eq_toks: fn(a, b) { a == b },
  )
}

pub type Pos {
  Pos(line: Int, col: Int)
}

fn get(state: atto.State(List(String), Pos, c)) {
  use <- bool.guard(list.is_empty(state.src), Error(Nil))
  let assert [t, ..src] = state.src
  let pos = case t {
    "\n" -> Pos(state.pos.line + 1, 1)
    _ -> Pos(state.pos.line, state.pos.col + 1)
  }
  Ok(#(t, atto.State(..state, src: src, pos: pos)))
}

fn gets(state: atto.State(List(String), Pos, c), n: Int) {
  // TODO: this is very inefficient
  gets_rec(state, n, [])
  |> result.map(fn(x) { #(string.concat(x.0 |> list.reverse), x.1) })
}

fn gets_rec(state, n, acc) {
  use <- bool.guard(n == 0, Ok(#(acc, state)))
  use #(t, state) <- result.try(get(state))
  gets_rec(state, n - 1, [t, ..acc])
}

fn cmp(a: Pos, b: Pos) {
  case int.compare(a.line, b.line) {
    order.Eq -> int.compare(a.col, b.col)
    x -> x
  }
}

/// Parse a character from a set of characters.
pub fn char_of(cs) -> atto.Parser(String, String, ts, s, p, c, e) {
  use <- atto.label("one of '" <> cs <> "'")
  atto.satisfy(fn(c) { cs |> string.contains(c) })
}

/// Parse zero or more whitespace characters.
pub fn spaces() -> atto.Parser(List(String), String, ts, s, p, c, e) {
  use <- atto.label("spaces")
  atto.many(char_of(" \n\r\t"))
}

/// Parse one or more whitespace characters.
pub fn spaces_1() -> atto.Parser(List(String), String, ts, s, p, c, e) {
  use <- atto.label("spaces")
  atto.many_1(char_of(" \n\r\t"))
}

/// Parse `p`, then skip trailing whitespace.
pub fn lexeme(p) -> atto.Parser(a, String, ts, s, p, c, e) {
  p |> atto.that(spaces())
}

/// Parse a string, then skip trailing whitespace.
pub fn symbol(s) -> atto.Parser(String, String, String, s, p, c, e) {
  atto.string(s) |> lexeme
}

/// Parse a reserved word (eg. keyword) not followed by another identifier.
pub fn reserved(s) -> atto.Parser(String, String, String, s, p, c, e) {
  use <- atto.label(s)
  atto.string(s)
  |> atto.that(atto.not_followed_by(alphanum()))
  |> atto.try
  |> lexeme
}

/// Parse a lowercase ASCII character.
pub fn lower() -> atto.Parser(String, String, ts, s, p, c, e) {
  use <- atto.label("lower")
  atto.satisfy(ord(fn(ch) { ch >= 97 && ch <= 122 }))
}

/// Parse a uppercase ASCII character.
pub fn upper() -> atto.Parser(String, String, ts, s, p, c, e) {
  use <- atto.label("upper")
  atto.satisfy(ord(fn(ch) { ch >= 65 && ch <= 90 }))
}

/// Parse an ASCII letter character.
pub fn alpha() -> atto.Parser(String, String, ts, s, p, c, e) {
  use <- atto.label("alpha")
  atto.choice(lower(), upper())
}

/// Parse an ASCII digit character.
pub fn digit() -> atto.Parser(String, String, ts, s, p, c, e) {
  use <- atto.label("digit")
  atto.satisfy(ord(fn(ch) { ch >= 48 && ch <= 57 }))
}

/// Parse a non-zero ASCII digit character.
pub fn digit_nonzero() -> atto.Parser(String, String, ts, s, p, c, e) {
  use <- atto.label("non-zero digit")
  atto.satisfy(ord(fn(ch) { ch >= 49 && ch <= 57 }))
}

/// Parse an ASCII letter or digit character. 
pub fn alphanum() -> atto.Parser(String, String, ts, s, p, c, e) {
  use <- atto.label("alphanum")
  atto.choice(alpha(), digit())
}

/// Parse an integer.
pub fn integer() -> atto.Parser(Int, String, ts, s, p, c, e) {
  use <- atto.label("integer")
  use cs <- atto.bind(atto.choice(
    atto.char("0")
      |> atto.that(atto.not_followed_by(digit()))
      |> atto.map(fn(x) { [x] }),
    digit_nonzero()
      |> atto.both(atto.many(digit()))
      |> atto.map2(atto.cons),
  ))
  string.concat(cs) |> int.parse |> result.unwrap(0) |> atto.pure
}

/// Parse a floating point number.
pub fn float() -> atto.Parser(Float, String, ts, s, p, c, e) {
  use <- atto.label("float")
  use n <- atto.bind(integer())
  use _ <- atto.bind(atto.char("."))
  use m <- atto.bind(integer())
  atto.pure({ { n * 10 + m } |> int.to_float } /. 10.0)
}

/// Wrap a parser such that it can be signed.
/// When it is prefixed by `-`, the result is negated.
pub fn signed(p, negate) -> atto.Parser(a, String, ts, s, p, c, e) {
  atto.one_of([
    atto.char("+") |> atto.this(p),
    atto.char("-") |> atto.this(p) |> atto.map(negate),
    p,
  ])
}

/// Parse a character literal.
pub fn char_literal() -> atto.Parser(String, String, String, s, p, c, e) {
  inner("'") |> atto.between(atto.char("'"), atto.char("'"))
}

/// Parse a string literal.
pub fn string_literal() -> atto.Parser(String, String, String, s, p, c, e) {
  atto.many(inner("\""))
  |> atto.map(string.concat)
  |> atto.between(atto.char("\""), atto.char("\""))
}

fn ord(f) {
  fn(c) {
    case string.to_utf_codepoints(c) {
      [x] -> x |> string.utf_codepoint_to_int |> f
      _ -> False
    }
  }
}

fn inner(end) {
  atto.one_of([
    atto.string("\\\"") |> atto.map(fn(_) { "\"" }),
    atto.string("\\\\") |> atto.map(fn(_) { "\\" }),
    atto.string("\\f") |> atto.map(fn(_) { "\f" }),
    atto.string("\\n") |> atto.map(fn(_) { "\n" }),
    atto.string("\\r") |> atto.map(fn(_) { "\r" }),
    atto.string("\\t") |> atto.map(fn(_) { "\t" }),
    atto.satisfy(fn(c) { c != end }),
  ])
}
