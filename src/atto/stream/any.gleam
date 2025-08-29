import atto
import gleam/bool
import gleam/list
import gleam/order

pub type Parser(a, t, p) =
  atto.Parser(a, List(t), List(t), List(t), p, Nil, Nil)

/// Create a state from a list of tokens.
pub fn new(src: List(t), pos: p, ctx: c) -> atto.State(List(t), p, c) {
  atto.State(src, pos, ctx)
}

/// Create a stream interface for a list of tokens.
pub fn stream(
  advance: fn(List(t), p) -> p,
  compare: fn(p, p) -> order.Order,
  eq: fn(t, t) -> Bool,
) -> atto.Stream(t, List(t), List(t), p, c) {
  atto.make_stream(
    get: get(advance),
    gets: gets(advance),
    cmp_pos: compare,
    len: list.length,
    eq_tok: eq,
    eq_toks: eq_toks(eq),
  )
}

fn get(advance) {
  fn(state: atto.State(List(t), p, c)) {
    case state.src {
      [] -> Error(Nil)
      [t, ..ts] -> Ok(#(t, atto.State(ts, advance([t], state.pos), state.ctx)))
    }
  }
}

fn gets(advance) {
  fn(state: atto.State(List(t), p, c), n: Int) {
    use <- bool.guard(list.length(state.src) < n, Error(Nil))
    let ts1 = list.take(state.src, n)
    let ts2 = list.drop(state.src, n)
    Ok(#(ts1, atto.State(ts2, advance(ts1, state.pos), state.ctx)))
  }
}

fn eq_toks(eq) {
  fn(a: List(t), b: List(t)) {
    case list.strict_zip(a, b) {
      Ok(x) -> list.map(x, fn(y) { eq(y.0, y.1) }) |> list.all(fn(z) { z })
      Error(_) -> False
    }
  }
}
