//// Functions for parsing over strings.

import gleam/regex
import gleam/set
import gleam/string
import glide.{type Parser, type ParserInput, type Pos}

/// Create a new parser input from a string.
/// Note: currently, this function lacks a JavaScript-specific implementation,
/// so performance will be poor.
pub fn new(source: String) -> ParserInput(String, String) {
  glide.ParserInput(source, text_get)
}

fn text_get(s, p: Pos) {
  case string.pop_grapheme(s) {
    Ok(#("\n", ts)) -> Ok(#("\n", ts, glide.Pos(p.line + 1, p.col)))
    Ok(#(t, ts)) -> Ok(#(t, ts, glide.Pos(p.line, p.col + 1)))
    Error(_) -> Error(Nil)
  }
}

/// Parse a regex, returning the matched string.
/// Zero-length matches will fail.
/// Note that a literal backslash in the regex must be double-escaped,
/// such as `\\\\b` to match the literal string `\b` rather than a word boundary.
/// 
/// ## Examples
/// 
/// ```gleam
/// text.match("[0-9]+(\\.[0-9]*)?")
/// |> glide.run(text.new("123.456"), Nil)
/// |> glide.map(float.parse)
/// |> glide.map(result.unwrap(0.0))
/// // -> Ok(123.456)
/// ```
pub fn match(regex: String) -> Parser(String, String, String, Nil, Nil) {
  case regex.from_string("^" <> regex) {
    Ok(r) -> fn(in: ParserInput(String, String), pos, ctx) {
      case regex.scan(r, in.src) {
        [] -> Error(glide.ParseError(pos, glide.Msg("Regex failed"), set.new()))
        [m] -> {
          let x = m.content
          let xs = string.drop_left(in.src, string.length(m.content))
          let p = advance_pos_string(pos, x)
          case string.length(x) {
            0 ->
              Error(glide.ParseError(
                pos,
                glide.Msg("Zero-length match"),
                set.new(),
              ))
            _ -> Ok(#(x, glide.ParserInput(..in, src: xs), p, ctx))
          }
        }
        [_, ..] -> panic as "Multiple scan matches"
      }
    }
    Error(e) -> fn(_, pos, _) {
      Error(glide.ParseError(pos, glide.Msg(e.error), set.new()))
    }
  }
  |> glide.Parser
}

fn advance_pos_string(p: Pos, x) {
  case string.pop_grapheme(x) {
    Ok(#("\n", x)) -> advance_pos_string(glide.Pos(p.line + 1, 1), x)
    Ok(#(_, x)) -> advance_pos_string(glide.Pos(p.line, p.col + 1), x)
    Error(_) -> p
  }
}
