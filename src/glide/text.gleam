//// Functions for parsing over strings.

import gleam/list
import gleam/regex
import gleam/set
import gleam/string
import glide.{type Parser, type ParserInput, type Pos, type Span}

/// Create a new parser input from a string.
/// Note: currently, this function lacks a JavaScript-specific implementation,
/// so performance will be poor.
pub fn new(source: String) -> ParserInput(String, String) {
  glide.ParserInput(source, text_get, string.inspect, text_render)
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
/// Note that zero-width matches can be dangerous, as they can cause infinite loops.
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
pub fn match(regex: String) -> Parser(String, String, String, c, e) {
  let r = case regex.from_string("^" <> regex) {
    Ok(r) -> r
    Error(e) -> panic as e.error
  }
  fn(in: ParserInput(String, String), pos, ctx) {
    case regex.scan(r, in.src) {
      [] ->
        case glide.get_token(in, pos) {
          Ok(#(t, _, pos2)) ->
            Error(glide.ParseError(
              glide.Span(pos, pos2),
              glide.Token(t),
              set.new(),
            ))
          Error(_) ->
            Error(glide.ParseError(
              glide.Span(pos, pos),
              glide.Msg("EOF"),
              set.new(),
            ))
        }
      [m, ..] -> {
        let x = m.content
        let xs = string.drop_left(in.src, string.length(m.content))
        let p = advance_pos_string(pos, x)
        Ok(#(x, glide.ParserInput(..in, src: xs), p, ctx))
      }
    }
  }
  |> glide.Parser
}

fn advance_pos_string(p: Pos, x) {
  case string.pop_grapheme(x) {
    Ok(#("\n", x)) -> advance_pos_string(glide.Pos(p.idx + 1, p.line + 1, 1), x)
    Ok(#(_, x)) ->
      advance_pos_string(glide.Pos(p.idx + 1, p.line, p.col + 1), x)
    Error(_) -> p
  }
}
