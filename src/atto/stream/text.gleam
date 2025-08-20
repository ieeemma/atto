import atto
import gleam/bool
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string

/// Create a state from a string input.
pub fn new(src: String, ctx: c) -> atto.State(List(String), Pos, c) {
  atto.State(string.to_graphemes(src), Pos(1, 1), ctx)
}

/// Create a text stream interface.
pub fn text_stream() -> atto.Stream(String, List(String), List(String), Pos, c) {
  atto.make_stream(
    get: get,
    gets: gets,
    cmp_pos: cmp,
    len: list.length,
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
  gets_rec(state, n, [])
}

fn gets_rec(state, n, acc) {
  use <- bool.guard(n == 0, Ok(#([], state)))
  use #(t, state) <- result.try(get(state))
  gets_rec(state, n - 1, [t, ..acc])
}

fn cmp(a: Pos, b: Pos) {
  case int.compare(a.line, b.line) {
    order.Eq -> int.compare(a.col, b.col)
    x -> x
  }
}
