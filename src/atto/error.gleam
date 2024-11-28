import gleam/list
import gleam/set
import gleam/string

import atto.{type ParseError, type ParserInput}

/// Prettyprint a parse error for display.
/// The `in` parameter must be the **original** input to the parser.
/// If `color` is `True`, the error message will contain ANSI color codes.
/// 
/// ## Examples
/// 
/// ```gleam
/// let in = gleam.text.new("7")
/// let assert Error(e) =
///   gleam.choice([gleam.token("5"), gleam.token("6")])
///   |> gleam.run(in, Nil)
/// gleam.pretty(e, in, False)
/// // -> Parse error: Expected one of "5", "6", got 7
/// ```
pub fn pretty(
  err: ParseError(e, t),
  in: ParserInput(t, s),
  color color: Bool,
) -> String {
  let color = case color {
    True -> red
    False -> fn(s) { s }
  }
  let msg = case err {
    atto.ParseError(_, got, exp) -> {
      let g = pretty_part(got, in)
      let e =
        set.to_list(exp)
        |> list.map(fn(e) { pretty_part(e, in) })
        |> string.join(", ")
      case set.size(exp) {
        0 -> "Unexpected token " <> g
        1 -> "Expected " <> e <> ", got " <> g
        _ -> "Expected one of " <> e <> ", got " <> g
      }
    }
    atto.Custom(_, value) -> string.inspect(value)
  }
  let #(before, mid, after) = in.render_span(in.src, err.span)
  let code = before <> color(mid) <> after
  let code =
    string.split(code, "\n")
    |> list.map(fn(l) { "    " <> l })
    |> string.join("\n")
  string.concat([color("Parse error:"), " ", msg, "\n\n", code])
}

fn pretty_part(part, in: ParserInput(t, s)) {
  case part {
    atto.Token(t) -> in.render_token(t)
    atto.Msg(s) -> s
  }
}

fn red(s) {
  "\u{001b}[31m" <> s <> "\u{001b}[0m"
}
