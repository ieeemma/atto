import atto/stream/text
import gleeunit
import parse.{expression}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn number_test() {
  assert expression() |> text.run("123") == Ok(123)
  assert expression() |> text.run("0") == Ok(0)
}

pub fn infix_operator_test() {
  assert expression() |> text.run("1 + 2") == Ok(3)
  assert expression() |> text.run("2 * 3") == Ok(6)
  assert expression() |> text.run("4 - 5") == Ok(-1)
  assert expression() |> text.run("6 / 2") == Ok(3)
  assert expression() |> text.run("1 + 2 * 3") == Ok(7)
}

pub fn prefix_operator_test() {
  assert expression() |> text.run("+1") == Ok(1)
  assert expression() |> text.run("-2") == Ok(-2)
  assert expression() |> text.run("3+ +1") == Ok(4)
  assert expression() |> text.run("-4- -2") == Ok(-2)
}

pub fn postfix_operator_test() {
  assert expression() |> text.run("1++") == Ok(2)
  assert expression() |> text.run("2--") == Ok(1)
  assert expression() |> text.run("3++ +1") == Ok(5)
  assert expression() |> text.run("-4-- -2") == Ok(-7)
}

pub fn parens_test() {
  assert expression() |> text.run("(1)") == Ok(1)
  assert expression() |> text.run("(2 + 3) * 4") == Ok(20)
  assert expression() |> text.run("-(5 + 6)") == Ok(-11)
}
