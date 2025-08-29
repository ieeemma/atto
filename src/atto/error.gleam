import atto
import gleam/bool
import gleam/int
import gleam/list
import gleam/option
import gleam/set
import gleam/string
import gleam/string_tree.{type StringTree}

/// The renderer interface, allowing a parse error to be rendered to a string.
pub type Renderer(t, ts, s, p, c, e) {
  Renderer(
    /// Render a single token.
    tok: fn(t) -> StringTree,
    /// Render a chunk of tokens.
    toks: fn(ts) -> StringTree,
    /// Render a portion of source.
    src: fn(s) -> StringTree,
    /// Render a position.
    pos: fn(p) -> StringTree,
    /// Render a custom error component.
    err: fn(e) -> StringTree,
    /// Map a position and token type to a context window within the source code.
    window: fn(p, atto.MsgPart(t, ts, e), s) -> Window(s),
  )
}

/// Create a new renderer interface.
pub fn make_renderer(
  tok tok,
  toks toks,
  src src,
  pos pos,
  err err,
  window window,
) -> Renderer(t, ts, s, p, c, e) {
  Renderer(tok, toks, src, pos, err, window)
}

/// A window into the source code, with a before, current, and after section.
pub type Window(s) {
  Window(before: s, current: s, after: s)
}

/// How to render a parse error.
pub type RenderOptions {
  RenderOptions(color: Bool, unicode: Bool)
}

/// The default rendering options, enables all features.
pub const pretty_options = RenderOptions(True, True)

pub fn render(
  err: atto.Msg(t, ts, s, p, c, e),
  render: Renderer(t, ts, s, p, c, e),
  opts: RenderOptions,
  src: s,
  name: option.Option(String),
) -> String {
  err |> render_tree(render, opts, src, name) |> string_tree.to_string
}

pub fn render_tree(
  err: atto.Msg(t, ts, s, p, c, e),
  render: Renderer(t, ts, s, p, c, e),
  opts: RenderOptions,
  src,
  name,
) {
  // The prefix as `filename:pos: parse error`
  let prefix =
    case name {
      option.Some(name) ->
        string_tree.from_string(name) |> string_tree.append(":")
      option.None -> string_tree.new()
    }
    |> string_tree.append_tree(render.pos(err.pos))
    |> string_tree.append(": ")
    |> color_if(gray, opts)
    |> string_tree.append_tree(
      string_tree.from_string("parse error") |> color_if(red, opts),
    )
    |> string_tree.append("\n")
    |> string_tree.prepend_tree(unicode("╭╴ ", "", opts))
    |> string_tree.append_tree(unicode("│\n", "\n", opts))

  // The message as `expected one of ... but found ...`
  let msg = {
    let expect =
      err.expected |> set.to_list |> list.map(fn(p) { render_part(p, render) })
    let len = expect |> list.map(string_tree.byte_size) |> int.sum
    let e = case len > 20 {
      True ->
        expect
        |> list.map(fn(e) {
          e |> string_tree.prepend_tree(unicode("│  • ", " - ", opts))
        })
        |> string_tree.join("\n")
        |> string_tree.prepend(":\n")
        |> string_tree.append("\n")
        |> string_tree.append_tree(unicode("│ ", "", opts))

      False ->
        expect
        |> string_tree.join(", ")
        |> string_tree.prepend(" ")
        |> string_tree.append(" ")
    }

    let found = err.found |> render_part(render)

    case list.length(expect) {
      0 -> [string_tree.from_string("unexpected "), found]
      1 -> [
        string_tree.from_string("expected"),
        e,
        string_tree.from_string("but found "),
        found,
      ]
      _ -> [
        string_tree.from_string("expected one of"),
        e,
        string_tree.from_string("but found "),
        found,
      ]
    }
    |> string_tree.concat
    |> string_tree.prepend_tree(unicode("│ ", "", opts))
    |> string_tree.append_tree(unicode("\n│\n", "\n\n", opts))
  }

  // The view of the source code
  let src = {
    let win = render.window(err.pos, err.found, src)
    let before = win.before |> render.src
    let current = win.current |> render.src
    let after = win.after |> render.src

    let show_arrow =
      !opts.color
      || { current |> string_tree.to_string |> string.trim |> string.is_empty }

    let end = case show_arrow {
      True -> "├  "
      False -> "╰╴ "
    }

    let line =
      string_tree.concat([before, current |> color_if(red, opts), after])
      |> string_tree.prepend_tree(unicode(end, ">  ", opts))

    let col = before |> string_tree.byte_size

    let gap =
      string_tree.from_strings(list.repeat(" ", col + 2))
      |> string_tree.prepend_tree(unicode("\n│", "\n ", opts))

    let arrow = case opts.unicode, string_tree.byte_size(current) {
      True, 0 -> string_tree.from_string("╷")
      True, 1 -> string_tree.from_string("╷")
      True, n -> string_tree.from_strings(["╭", string.repeat("─", n - 1)])
      False, n -> string_tree.from_string(string.repeat("^", n))
    }

    let gap2 = case opts.unicode {
      True ->
        string_tree.from_strings(["\n╰", string.repeat("─", col + 2), "╯"])
      False -> string_tree.new()
    }

    case show_arrow {
      True -> [line, gap, arrow, gap2]
      False -> [line]
    }
    |> string_tree.concat()
  }

  string_tree.concat([prefix, msg, src])
}

fn unicode(unicode, default, opts: RenderOptions) {
  bool.guard(opts.unicode, string_tree.from_string(unicode), fn() {
    string_tree.from_string(default)
  })
}

fn color_if(tree, c, opts: RenderOptions) {
  bool.guard(!opts.color, tree, fn() { color(tree, c) })
}

fn color(tree, c) {
  tree |> string_tree.prepend(c) |> string_tree.append(reset)
}

fn render_part(part, render: Renderer(t, ts, s, p, c, e)) {
  case part {
    atto.Token(t) -> render.tok(t)
    atto.Tokens(ts) -> render.toks(ts)
    atto.Custom(c) -> render.err(c)
    atto.Name(n) -> n |> string_tree.from_string
    atto.EOF -> "EOF" |> string_tree.from_string
    atto.None -> "none" |> string_tree.from_string
  }
}

const red = "\u{001b}[31m"

const gray = "\u{001b}[30m"

const reset = "\u{001b}[0m"
