import atto
import gleam/list

// A direct translation of
// https://hackage.haskell.org/package/megaparsec-4.0.0/docs/src/Text-Megaparsec-Expr.html#makeExprParser

pub type Operator(a, t, ts, s, p, c, e) {
  InfixN(atto.Parser(fn(a, a) -> a, t, ts, s, p, c, e))
  InfixL(atto.Parser(fn(a, a) -> a, t, ts, s, p, c, e))
  InfixR(atto.Parser(fn(a, a) -> a, t, ts, s, p, c, e))
  Prefix(atto.Parser(fn(a) -> a, t, ts, s, p, c, e))
  Postfix(atto.Parser(fn(a) -> a, t, ts, s, p, c, e))
}

pub fn parser(levels, term: atto.Parser(a, t, ts, s, p, c, e)) {
  list.fold(levels, term, add_prec_level)
}

fn add_prec_level(term, ops) {
  let #(r, l, n, pre, post) =
    list.fold_right(ops, #([], [], [], [], []), split_op)
  let term = p_term(atto.one_of(pre), term, atto.one_of(post))

  use <- atto.label("operator")
  use x <- atto.bind(term)
  atto.one_of([
    p_infix_r(atto.one_of(r), term, x),
    p_infix_l(atto.one_of(l), term, x),
    p_infix_n(atto.one_of(n), term, x),
    atto.pure(x),
  ])
}

fn p_term(prefix, term, postfix) {
  use pre <- atto.bind(atto.option_or(prefix, fn(x) { x }))
  use x <- atto.bind(term)
  use post <- atto.bind(atto.option_or(postfix, fn(x) { x }))
  atto.pure(x |> pre |> post)
}

fn p_infix_n(op, p, x) {
  use f <- atto.bind(op)
  use y <- atto.bind(p)
  atto.pure(f(x, y))
}

fn p_infix_l(op, p, x) {
  use f <- atto.bind(op)
  use y <- atto.bind(p)
  let r = f(x, y)
  atto.choice(p_infix_l(op, p, r), atto.pure(r))
}

fn p_infix_r(op, p, x) {
  use f <- atto.bind(op)
  use r <- atto.bind(p)
  use y <- atto.bind(atto.choice(p_infix_r(op, p, r), atto.pure(r)))
  atto.pure(f(x, y))
}

fn split_op(ops, op) {
  case op, ops {
    InfixR(op), #(r, l, n, pre, post) -> #([op, ..r], l, n, pre, post)
    InfixL(op), #(r, l, n, pre, post) -> #(r, [op, ..l], n, pre, post)
    InfixN(op), #(r, l, n, pre, post) -> #(r, l, [op, ..n], pre, post)
    Prefix(op), #(r, l, n, pre, post) -> #(r, l, n, [op, ..pre], post)
    Postfix(op), #(r, l, n, pre, post) -> #(r, l, n, pre, [op, ..post])
  }
}
