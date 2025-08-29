import atto
import atto/expr
import atto/stream/text
import gleam/int

pub fn expression() {
  expr() |> atto.that(atto.eof())
}

fn expr() {
  let op = fn(n) { text.reserved(n, text.char_of("+-*/")) }
  let bin = fn(n, f) { expr.InfixL(op(n) |> atto.this(atto.pure(f))) }
  let pre = fn(n, f) { expr.Prefix(op(n) |> atto.this(atto.pure(f))) }
  let post = fn(n, f) { expr.Postfix(op(n) |> atto.this(atto.pure(f))) }

  let table = [
    [pre("-", int.negate), pre("+", fn(x) { x })],
    [post("++", fn(x) { x + 1 }), post("--", fn(x) { x - 1 })],
    [bin("*", fn(x, y) { x * y }), bin("/", fn(x, y) { x / y })],
    [bin("+", fn(x, y) { x + y }), bin("-", fn(x, y) { x - y })],
  ]

  use <- atto.label("expression")
  expr.parser(table, term())
}

fn term() {
  use <- atto.label("term")
  atto.choice(
    expr() |> atto.between(text.symbol("("), text.symbol(")")),
    text.integer() |> text.lexeme,
  )
}
