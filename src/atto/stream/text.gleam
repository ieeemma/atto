import atto
import atto/error
import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import gleam/string_tree

/// Specialized `Parser` for simple text parsers without state.
pub type Parser(a) =
  atto.Parser(a, String, String, List(String), Pos, Nil, Nil)

/// Specialized `run` for simple text parsers.
pub fn run(p: Parser(a), src: String) {
  atto.run(p, stream(), new(src, Nil))
}

/// Specialized `error.render` for simple text parsers.
pub fn render(
  err: atto.Msg(String, String, List(String), Pos, Nil, Nil),
  src: String,
  name: option.Option(String),
) {
  error.render(
    err,
    renderer(fn(_) { string_tree.new() }),
    error.pretty_options,
    string.to_graphemes(src),
    name,
  )
}

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

/// Create a text rendering interface.
pub fn renderer(
  err: fn(e) -> string_tree.StringTree,
) -> error.Renderer(String, String, List(String), Pos, c, e) {
  error.make_renderer(
    tok: fn(t) { t |> string.inspect |> string_tree.from_string },
    toks: fn(ts) { ts |> string.inspect |> string_tree.from_string },
    src: string_tree.from_strings,
    pos: fn(p: Pos) {
      string_tree.from_strings([
        int.to_string(p.line),
        ":",
        int.to_string(p.col),
      ])
    },
    err: err,
    window: fn(p: Pos, part, src) {
      let n = case part {
        atto.Token(_) -> 1
        atto.Tokens(ts) -> string.length(ts)
        _ -> 0
      }
      let assert Ok(line) =
        string.concat(src)
        |> string.split("\n")
        |> list.drop(p.line - 1)
        |> list.first

      let #(before, line) = split(line, p.col - 1)
      let #(current, after) = split(line, n)
      error.Window(
        before |> string.to_graphemes,
        current |> string.to_graphemes,
        after |> string.to_graphemes,
      )
    },
  )
}

fn split(str, n) {
  #(string.drop_end(str, string.length(str) - n), string.drop_start(str, n))
}

pub type Pos {
  Pos(line: Int, col: Int)
}

pub fn get(state: atto.State(List(String), Pos, c)) {
  use <- bool.guard(list.is_empty(state.src), Error(Nil))
  let assert [t, ..src] = state.src
  let pos = case t {
    "\n" -> Pos(state.pos.line + 1, 1)
    _ -> Pos(state.pos.line, state.pos.col + 1)
  }
  Ok(#(t, atto.State(..state, src: src, pos: pos)))
}

pub fn gets(state: atto.State(List(String), Pos, c), n: Int) {
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
  use <- atto.label("one of " <> string.inspect(cs))
  atto.satisfy(fn(c) { cs |> string.contains(c) })
}

/// Parse zero or more whitespace characters.
pub fn spaces() -> atto.Parser(String, String, ts, s, p, c, e) {
  use <- atto.label("spaces")
  atto.many(char_of(" \n\r\t")) |> atto.map(string.concat)
}

/// Parse one or more whitespace characters.
pub fn spaces_1() -> atto.Parser(String, String, ts, s, p, c, e) {
  use <- atto.label("spaces")
  atto.many_1(char_of(" \n\r\t")) |> atto.map(string.concat)
}

/// Parse `p`, then skip trailing whitespace.
pub fn lexeme(p) -> atto.Parser(a, String, ts, s, p, c, e) {
  p |> atto.that(spaces())
}

/// Parse a string, then skip trailing whitespace.
pub fn symbol(s) -> atto.Parser(String, String, String, s, p, c, e) {
  atto.string(s) |> lexeme
}

/// Parse a string not followed by another parser, with optional whitespace.
pub fn reserved(s, p) -> atto.Parser(String, String, String, s, p, c, e) {
  use <- atto.label(s)
  atto.string(s)
  |> atto.that(atto.not_followed_by(p))
  |> atto.try
  |> lexeme
}

/// Parse a keyword.
pub fn keyword(s) -> atto.Parser(String, String, String, s, p, c, e) {
  reserved(s, alphanum())
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

fn integer_helper() {
  atto.choice(
    atto.char("0")
      |> atto.that(atto.not_followed_by(digit())),
    digit_nonzero()
      |> atto.both(atto.many(digit()))
      |> atto.map2(atto.cons)
      |> atto.map(string.concat),
  )
}

/// Parse an integer.
pub fn integer() -> atto.Parser(Int, String, ts, s, p, c, e) {
  use <- atto.label("integer")
  use n <- atto.bind(integer_helper())
  n |> int.parse |> result.unwrap(0) |> atto.pure
}

/// Parse a floating point number.
pub fn float() -> atto.Parser(Float, String, ts, s, p, c, e) {
  use <- atto.label("float")
  use n <- atto.bind(integer_helper())
  use _ <- atto.bind(atto.char("."))
  use m <- atto.bind(integer_helper())
  { n <> "." <> m } |> float.parse |> result.unwrap(0.0) |> atto.pure
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
    atto.string("\\" <> end) |> atto.map(fn(_) { end }),
    atto.string("\\\\") |> atto.map(fn(_) { "\\" }),
    atto.string("\\f") |> atto.map(fn(_) { "\f" }),
    atto.string("\\n") |> atto.map(fn(_) { "\n" }),
    atto.string("\\r") |> atto.map(fn(_) { "\r" }),
    atto.string("\\t") |> atto.map(fn(_) { "\t" }),
    atto.string("\\") |> atto.this(atto.fail("invalid escape")),
    atto.satisfy(fn(c) { c != end }),
  ])
}
