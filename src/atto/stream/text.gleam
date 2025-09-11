import atto
import atto/error
import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/set
import gleam/string
import gleam/string_tree

pub type Text

/// Specialized `Parser` for simple text parsers without state.
pub type Parser(a) =
  atto.Parser(a, Int, Text, Text, Pos, Nil, Nil)

/// Specialized `run` for simple text parsers.
pub fn run(p: Parser(a), src: String) {
  atto.run(p, stream(), new(src, Nil))
}

/// Specialized `error.render` for simple text parsers.
pub fn render(
  err: atto.Msg(Int, Text, Text, Pos, Nil, Nil),
  src: String,
  name: option.Option(String),
) {
  error.render(
    err,
    renderer(fn(_) { string_tree.new() }),
    error.pretty_options,
    from_string(src),
    name,
  )
}

/// Create a state from a string input.
pub fn new(src: String, ctx: c) -> atto.State(Text, Pos, c) {
  atto.State(from_string(src), Pos(1, 1), ctx)
}

/// Create a text stream interface.
pub fn stream() -> atto.Stream(Int, Text, Text, Pos, c) {
  atto.make_stream(
    get: get,
    gets: gets,
    gets_while: gets_while,
    cmp_pos: cmp,
    len: size,
    eq_tok: fn(a, b) { a == b },
    eq_toks: fn(a, b) { a == b },
  )
}

/// Create a text rendering interface.
pub fn renderer(
  err: fn(e) -> string_tree.StringTree,
) -> error.Renderer(Int, Text, Text, Pos, c, e) {
  error.make_renderer(
    tok: fn(t) {
      string.from_utf_codepoints([
        string.utf_codepoint(t) |> result.lazy_unwrap(fn() { panic }),
      ])
      |> string_tree.from_string
    },
    toks: fn(ts) { ts |> to_string |> string_tree.from_string },
    src: fn(src) { src |> to_string |> string_tree.from_string },
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
        atto.Tokens(ts) -> size(ts)
        _ -> 0
      }
      let assert Ok(line) =
        src
        |> to_string
        |> string.split("\n")
        |> list.drop(p.line - 1)
        |> list.first

      let #(before, line) = split(line, p.col - 1)
      let #(current, after) = split(line, n)
      error.Window(
        before |> string_tree.from_string,
        current |> string_tree.from_string,
        after |> string_tree.from_string,
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

pub fn get(state: atto.State(Text, Pos, c)) {
  use <- bool.guard(size(state.src) > 0, Error(Nil))
  let #(t, src, line, col) = get_(state.src, state.pos.line, state.pos.col)
  Ok(#(t, atto.State(..state, src: src, pos: Pos(line, col))))
}

pub fn gets(state: atto.State(Text, Pos, c), n: Int) {
  use <- bool.guard(size(state.src) >= n, Error(Nil))
  let #(ts, src, line, col) = gets_(state.src, state.pos.line, n, state.pos.col)
  Ok(#(ts, atto.State(..state, src: src, pos: Pos(line, col))))
}

pub fn gets_while(state: atto.State(Text, Pos, c), f: fn(Int) -> Bool) {
  let #(ts, src, line, col) =
    gets_while_(state.src, f, state.pos.line, state.pos.col)
  #(ts, atto.State(..state, src: src, pos: Pos(line, col)))
}

fn cmp(a: Pos, b: Pos) {
  case int.compare(a.line, b.line) {
    order.Eq -> int.compare(a.col, b.col)
    x -> x
  }
}

@external(erlang, "ffi/text", "get")
@external(javascript, "./ffi/text.mjs", "get")
fn get_(text: Text, line: Int, col: Int) -> #(Int, Text, Int, Int)

@external(erlang, "ffi/text", "gets")
@external(javascript, "./ffi/text.mjs", "gets")
fn gets_(text: Text, n: Int, line: Int, col: Int) -> #(Text, Text, Int, Int)

@external(erlang, "ffi/text", "gets")
@external(javascript, "./ffi/text.mjs", "gets")
fn gets_while_(
  text: Text,
  f: fn(Int) -> Bool,
  line: Int,
  col: Int,
) -> #(Text, Text, Int, Int)

@external(erlang, "ffi/text", "size")
@external(javascript, "./ffi/text.mjs", "size")
fn size(text: Text) -> Int

/// Convert text to a string
@external(erlang, "ffi/text", "to_string")
@external(javascript, "./ffi/text.mjs", "toString")
pub fn to_string(text: Text) -> String

/// Convert a string to text
@external(erlang, "ffi/text", "from_string")
@external(javascript, "./ffi/text.mjs", "fromString")
pub fn from_string(string: String) -> Text

/// Convert a char to a singleton string
pub fn char_to_string(c: Int) -> String {
  string.from_utf_codepoints([
    c |> string.utf_codepoint |> result.lazy_unwrap(fn() { panic }),
  ])
}

fn is_one_of(str) {
  let set =
    str
    |> string.to_utf_codepoints
    |> list.map(string.utf_codepoint_to_int)
    |> set.from_list
  fn(c) { set.contains(set, c) }
}

pub fn char(c) -> atto.Parser(Int, Int, ts, s, p, c, e) {
  let assert [c] = c |> string.to_utf_codepoints
  let c = c |> string.utf_codepoint_to_int
  atto.satisfy(fn(c2) { c == c2 })
}

/// Parse a character from a set of characters.
pub fn char_of(cs) -> atto.Parser(Int, Int, ts, s, p, c, e) {
  use <- atto.label("one of " <> string.inspect(cs))
  atto.satisfy(is_one_of(cs))
}

/// Parse a character not from a set of characters.
pub fn not_char_of(cs) -> atto.Parser(Int, Int, ts, s, p, c, e) {
  use <- atto.label("not one of " <> string.inspect(cs))
  let p = is_one_of(cs)
  atto.satisfy(fn(c) { !p(c) })
}

/// Parse zero or more whitespace characters.
pub fn spaces() -> atto.Parser(Text, Int, Text, s, p, c, e) {
  use <- atto.label("spaces")
  atto.take_while(is_one_of(" \n\r\t"))
}

/// Parse one or more whitespace characters.
pub fn spaces_1() -> atto.Parser(Text, Int, Text, s, p, c, e) {
  use <- atto.label("spaces")
  atto.take_while_1(is_one_of(" \n\r\t"))
}

/// Parse `p`, then skip trailing whitespace.
pub fn lexeme(p) -> atto.Parser(a, Int, Text, s, p, c, e) {
  p |> atto.that(spaces())
}

/// Parse a string, then skip trailing whitespace.
pub fn symbol(s) -> atto.Parser(Text, Int, Text, s, p, c, e) {
  s |> from_string |> atto.string |> lexeme
}

/// Parse a string not followed by another parser, with optional whitespace.
pub fn reserved(s, p) -> atto.Parser(Text, Int, Text, s, p, c, e) {
  use <- atto.label(s)
  atto.string(s |> from_string)
  |> atto.that(atto.not_followed_by(p))
  |> atto.try
  |> lexeme
}

/// Parse a keyword.
pub fn keyword(s) -> atto.Parser(Text, Int, Text, s, p, c, e) {
  reserved(s, alphanum())
}

/// Parse a lowercase ASCII character.
pub fn lower() -> atto.Parser(Int, Int, ts, s, p, c, e) {
  use <- atto.label("lower")
  atto.satisfy(fn(ch) { ch >= 97 && ch <= 122 })
}

/// Parse a uppercase ASCII character.
pub fn upper() -> atto.Parser(Int, Int, ts, s, p, c, e) {
  use <- atto.label("upper")
  atto.satisfy(fn(ch) { ch >= 65 && ch <= 90 })
}

/// Parse an ASCII letter character.
pub fn alpha() -> atto.Parser(Int, Int, ts, s, p, c, e) {
  use <- atto.label("alpha")
  atto.choice(lower(), upper())
}

/// Parse an ASCII digit character.
pub fn digit() -> atto.Parser(Int, Int, ts, s, p, c, e) {
  use <- atto.label("digit")
  atto.satisfy(fn(ch) { ch >= 48 && ch <= 57 })
}

/// Parse a non-zero ASCII digit character.
pub fn digit_nonzero() -> atto.Parser(Int, Int, ts, s, p, c, e) {
  use <- atto.label("non-zero digit")
  atto.satisfy(fn(ch) { ch >= 49 && ch <= 57 })
}

/// Parse an ASCII letter or digit character. 
pub fn alphanum() -> atto.Parser(Int, Int, ts, s, p, c, e) {
  use <- atto.label("alphanum")
  atto.choice(alpha(), digit())
}

fn integer_helper() -> atto.Parser(String, Int, Text, s, p, c, e) {
  atto.choice(
    char("0")
      |> atto.map(char_to_string)
      |> atto.that(atto.not_followed_by(digit())),
    { digit_nonzero() |> atto.map(char_to_string) }
      |> atto.both(
        atto.take_while(fn(ch) { ch >= 48 && ch <= 57 }) |> atto.map(to_string),
      )
      |> atto.map2(fn(x, y) { x <> y }),
  )
}

/// Parse an integer.
pub fn integer() -> atto.Parser(Int, Int, Text, s, p, c, e) {
  use <- atto.label("integer")
  use n <- atto.bind(integer_helper())
  n |> int.parse |> result.unwrap(0) |> atto.pure
}

/// Parse a floating point number.
pub fn float() -> atto.Parser(Float, Int, Text, s, p, c, e) {
  use <- atto.label("float")
  use n <- atto.bind(integer_helper())
  use _ <- atto.bind(char("."))
  use m <- atto.bind(integer_helper())
  { n <> "." <> m } |> float.parse |> result.unwrap(0.0) |> atto.pure
}

/// Parse an integer or floating point number.
pub fn integer_or_float() -> atto.Parser(Float, Int, Text, s, p, c, e) {
  atto.choice(integer() |> atto.map(int.to_float), float())
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
