import gleam/float
import gleam/int
import gleam/string
import glide.{type Parser, do, drop, label, pure, satisfy}
import glide/ops
import glide/text.{match}

// Utils

fn ord(char) {
  let assert [cp] = string.to_utf_codepoints(char)
  string.utf_codepoint_to_int(cp)
}

fn compose(f, g) {
  fn(x) { x |> f |> g }
}

// Char parsers

/// Parse a newline character.
pub fn newline() {
  use <- label("newline")
  satisfy(fn(c) { c == "\n" })
}

/// Parse zero or more ASCII whitespace characters.
pub fn spaces() {
  use <- label("spaces")
  match("[ \t\n]*")
}

/// Parse zero or more ASCII whitespace characters, returning
/// a parsed value.
/// This is useful for parsers that need to ignore whitespace.
/// 
/// ## Examples
/// 
/// ```gleam
/// glide.match("foo") |> text_utils.ws()
/// ```
pub fn ws(p) {
  use x <- do(p)
  use <- drop(spaces())
  pure(x)
}

/// Parse one or more ASCII whitespace characters.
pub fn spaces1() {
  use <- label("spaces")
  match("[ \t\n]+")
}

/// Parse zero or more horizontal ASCII whitespace characters.
pub fn hspaces() {
  use <- label("hspaces")
  match("[ \t]*")
}

/// Parse one or more horizontal ASCII whitespace characters.
pub fn hspaces1() {
  use <- label("hspaces")
  match("[ \t]+")
}

/// Parse an uppercase ASCII character.
pub fn upper() {
  use <- label("uppercase")
  satisfy(compose(ord, fn(ch) { ch >= 65 && ch <= 90 }))
}

/// Parse a lowercase ASCII character.
pub fn lower() {
  use <- label("lowercase")
  satisfy(compose(ord, fn(ch) { ch >= 97 && ch <= 122 }))
}

/// Parse an ASCII digit.
pub fn digit() {
  use <- label("digit")
  satisfy(compose(ord, fn(ch) { ch >= 48 && ch <= 57 }))
}

// Compound parsers

/// Parse a decimal number. See `signed` to parse a signed number.
/// 
/// ## Examples
/// 
/// ```gleam
/// signed(decimal(), int.negate)
/// |> run(text.new("-123"), Nil)
/// // -> Ok(-123)
/// ```
pub fn decimal() {
  use <- label("decimal")
  use n <- do(match("0|[1-9][0-9]*"))
  let assert Ok(n) = int.parse(n)
  pure(n)
}

/// Parse a binary number. Does not include a prefix such as `0b`.
/// 
/// ## Examples
/// 
/// ```gleam
/// {
///   use <- drop(glide.match("0b"))
///   binary()
/// }
/// |> run(text.new("0b10010"), Nil)
/// // -> Ok(18)
/// ```
pub fn binary() {
  use <- label("binary")
  use n <- do(match("[01]+"))
  let assert Ok(n) = int.base_parse(n, 2)
  pure(n)
}

/// Parse an octal number. Does not include a prefix such as `0x`.
/// 
/// ## Examples
/// 
/// ```gleam
/// {
///  use <- drop(glide.match("0x"))
///  hexadecimal()
/// }
/// |> run(text.new("0x1a"), Nil)
/// // -> Ok(26)
/// ```
pub fn hexadecimal() {
  use <- label("hexadecimal")
  use n <- do(match("[0-9a-fA-F]+"))
  let assert Ok(n) = int.base_parse(n, 16)
  pure(n)
}

/// Parse a float number. See `signed` to parse a signed number.
/// 
/// ## Examples
/// 
/// ```gleam
/// signed(float(), float.negate)
/// |> run(text.new("-123.456"), Nil)
/// // -> Ok(-123.456)
/// ```
pub fn float(sign sign: Bool) {
  use <- label("float")
  use s <- do(case sign {
    True -> ops.maybe(match("[+-]"))
    False -> pure(Error(Nil))
  })
  use n <- do(match("(0|[1-9][0-9]*)(\\.[0-9]*)?"))
  let assert Ok(n) = float.parse(n)
  case s {
    Ok("-") -> float.negate(n)
    _ -> n
  }
  |> pure
}

/// Given a parser for a number and a negation function, parse a signed number.
pub fn signed(
  p: Parser(a, String, String, c, e),
  negate: fn(a) -> a,
) -> Parser(a, String, String, c, e) {
  use <- label("signed")
  use sign <- do(ops.maybe(match("[+-]")))
  use x <- do(p)
  case sign {
    Ok("-") -> negate(x)
    _ -> x
  }
  |> pure
}

/// Parse a simple character literal, eg one without escape sequences.
pub fn simple_char_lit() {
  use <- label("character literal")
  satisfy(fn(c) { c != "\"" })
}

/// Parse a character literal as defined by the Gleam language.
pub fn char_lit() {
  use <- label("character literal")
  ops.choice([
    match("\\\\\"") |> glide.map(fn(_) { "\"" }),
    match("\\\\\\\\") |> glide.map(fn(_) { "\\" }),
    match("\\\\f") |> glide.map(fn(_) { "\u{000c}" }),
    match("\\\\n") |> glide.map(fn(_) { "\u{000a}" }),
    match("\\\\r") |> glide.map(fn(_) { "\u{000d}" }),
    match("\\\\t") |> glide.map(fn(_) { "\u{0009}" }),
    match("\\\\u\\{[0-9a-fA-F]{4}\\}")
      |> glide.map(fn(x) {
        let assert Ok(n) = int.base_parse(string.drop_left(x, 2), 16)
        let assert Ok(cp) = string.utf_codepoint(n)
        string.from_utf_codepoints([cp])
      }),
  ])
}

/// Parse a string literal using the given character parser.
pub fn string_lit(char: Parser(String, String, String, c, e)) {
  use <- label("string literal")
  ops.between(glide.token("\""), ops.many(char), glide.token("\""))
  |> glide.map(string.concat)
}
