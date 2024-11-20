//// Functions for parsing over strings.

import gleam/list
import gleam/regex
import gleam/set
import gleam/string
import glide.{type Parser, type ParserInput}
import glide/error.{type Pos, type Span}

/// Create a new parser input from a string.
/// Note: currently, this function lacks a JavaScript-specific implementation,
/// so performance will be poor.
pub fn new(source: String) -> ParserInput(String, String) {
  glide.ParserInput(source, text_get, text_render)
}

fn text_get(s, lc: #(Int, Int)) {
  case string.pop_grapheme(s) {
    Ok(#("\n", ts)) -> Ok(#("\n", ts, #(lc.0 + 1, 1)))
    Ok(#(t, ts)) -> Ok(#(t, ts, #(lc.0, lc.1 + 1)))
    Error(_) -> Error(Nil)
  }
}

fn text_render(s, span: Span) {
  let lines = string.split(s, "\n")
  let l1 = get_line(lines, span.start.line - 1)
  let l2 = get_line(lines, span.end.line - 1)
  #(
    string.slice(l1, 0, span.start.col - 1),
    string.slice(s, span.start.idx, span.end.idx - span.start.idx),
    string.slice(l2, span.end.col - 1, string.length(l2)),
  )
}

fn get_line(s, i) {
  let assert Ok(l) = list.first(list.drop(s, i))
  l
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
  let r = case regex.from_string("^" <> regex) {
    Ok(r) -> r
    Error(e) -> panic as e.error
  }
  fn(in: ParserInput(String, String), pos, ctx) {
    case regex.scan(r, in.src) {
      [] -> {
        let span = case glide.get_token(in, pos) {
          Ok(#(_, _, pos2)) -> error.Span(pos, pos2)
          Error(_) -> error.Span(pos, pos)
        }
        Error(error.ParseError(span, error.Msg("Regex failed"), set.new()))
      }
      [m] -> {
        let x = m.content
        let xs = string.drop_left(in.src, string.length(m.content))
        let p = advance_pos_string(pos, x)
        case string.length(x) {
          0 ->
            Error(error.ParseError(
              error.Span(pos, pos),
              error.Msg("Zero-length match"),
              set.new(),
            ))
          _ -> Ok(#(x, glide.ParserInput(..in, src: xs), p, ctx))
        }
      }
      [_, ..] -> panic as "Multiple scan matches"
    }
  }
  |> glide.Parser
}

fn advance_pos_string(p: Pos, x) {
  case string.pop_grapheme(x) {
    Ok(#("\n", x)) -> advance_pos_string(error.Pos(p.idx + 1, p.line + 1, 1), x)
    Ok(#(_, x)) ->
      advance_pos_string(error.Pos(p.idx + 1, p.line, p.col + 1), x)
    Error(_) -> p
  }
}
