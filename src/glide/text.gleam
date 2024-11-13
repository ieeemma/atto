import gleam/regex
import gleam/set
import gleam/string
import glide.{type Parser, type ParserInput, type Pos}

/// Create a new parser input from a string.
// TODO: This needs a javascript-specific implementation, as
// the string slicing will likely be really inefficient.
pub fn new(src: String) -> ParserInput(String, String) {
  glide.ParserInput(src, text_get)
}

fn text_get(s, p: Pos) {
  case string.pop_grapheme(s) {
    Ok(#("\n", ts)) -> Ok(#("\n", ts, glide.Pos(p.line + 1, p.col)))
    Ok(#(t, ts)) -> Ok(#(t, ts, glide.Pos(p.line, p.col + 1)))
    Error(_) -> Error(Nil)
  }
}

/// Parse a regex, returning the matched string.
pub fn match(r: String) -> Parser(String, String, String, Nil, Nil) {
  case regex.from_string("^" <> r) {
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
