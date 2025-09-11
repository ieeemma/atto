import atto
import atto/stream/text
import gleam/result
import gleam/set
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn empty_test() {
  assert atto.empty() |> text.run("")
    == Error(atto.Msg(text.Pos(1, 1), atto.None, set.new()))
}

pub fn fail_test() {
  assert atto.fail("foo") |> text.run("")
    == Error(atto.Msg(text.Pos(1, 1), atto.Name("foo"), set.new()))
}

pub fn fail_with_test() {
  assert atto.fail_with(5) |> atto.run(text.stream(), text.new("", Nil))
    == Error(atto.Msg(text.Pos(1, 1), atto.Custom(5), set.new()))
}

pub fn pure_test() {
  assert atto.pure(5) |> text.run("") == Ok(5)
  assert atto.pure("foo") |> text.run("") == Ok("foo")
  assert atto.pure(Nil) |> text.run("") == Ok(Nil)
}

pub fn bind_test() {
  assert atto.pure(5) |> atto.bind(fn(x) { atto.pure(x + 1) }) |> text.run("")
    == Ok(6)
  assert atto.fail("foo") |> atto.bind(fn(_) { atto.pure(5) }) |> text.run("")
    == Error(atto.Msg(text.Pos(1, 1), atto.Name("foo"), set.new()))

  assert {
      use a <- atto.bind(text.char("a"))
      use b <- atto.bind(text.char("b"))
      atto.pure(text.char_to_string(a) <> text.char_to_string(b))
    }
    |> text.run("ab")
    == Ok("ab")
}

pub fn choice_test() {
  let p = atto.choice(text.char("a"), text.char("b"))
  assert p |> text.run("a") |> result.map(text.char_to_string) == Ok("a")
  assert p |> text.run("b") |> result.map(text.char_to_string) == Ok("b")
  assert p |> text.run("c")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token(99),
      set.from_list([atto.Token(97), atto.Token(98)]),
    ))

  let p =
    atto.choice(
      atto.seq([atto.char("a"), atto.char("b")]),
      atto.seq([atto.char("a"), atto.char("c")]),
    )
  assert p |> text.run("ab") == Ok(["a", "b"])
  assert p |> text.run("ac")
    == Error(atto.Msg(
      text.Pos(1, 2),
      atto.Token("c"),
      set.from_list([atto.Token("b")]),
    ))
}

pub fn try_test() {
  let p = atto.try(atto.seq([atto.char("a"), atto.char("b")]))
  assert p |> text.run("ab") == Ok(["a", "b"])
  assert p |> text.run("ac")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("c"),
      set.from_list([atto.Token("b")]),
    ))
}

pub fn label_test() {
  let p = {
    use <- atto.label("foo")
    atto.char("a")
  }
  assert p |> text.run("a") == Ok("a")
  assert p |> text.run("b")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("b"),
      atto.Name("foo") |> singleton,
    ))
}

pub fn token_test() {
  let p =
    atto.token(
      fn(t) {
        case t {
          "a" | "b" -> Ok(t)
          _ -> Error(Nil)
        }
      },
      set.from_list([atto.Token("a"), atto.Token("b")]),
    )
  assert p |> text.run("a") == Ok("a")
  assert p |> text.run("b") == Ok("b")
  assert p |> text.run("c")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("c"),
      set.from_list([atto.Token("a"), atto.Token("b")]),
    ))
}

pub fn satisfy_test() {
  let p = atto.satisfy(fn(c) { c == "a" || c == "b" })
  assert p |> text.run("a") == Ok("a")
  assert p |> text.run("b") == Ok("b")
  assert p |> text.run("c")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("c"),
      atto.Name("token matching predicate") |> singleton,
    ))
}

pub fn char_test() {
  assert atto.char("a") |> text.run("a") == Ok("a")
  assert atto.char("a") |> text.run("b")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("b"),
      atto.Token("a") |> singleton,
    ))
}

pub fn any_test() {
  assert atto.any() |> text.run("a") == Ok("a")
  assert atto.any() |> text.run("")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.EOF,
      atto.Name("any token") |> singleton,
    ))
}

pub fn string_test() {
  assert atto.string("foo") |> text.run("foo") == Ok("foo")
  assert atto.string("foo") |> text.run("bar")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Tokens("bar"),
      atto.Tokens("foo") |> singleton,
    ))
  assert atto.string("foo") |> text.run("fo")
    == Error(atto.Msg(text.Pos(1, 1), atto.EOF, atto.Tokens("foo") |> singleton))
}

pub fn eof_test() {
  assert atto.eof() |> text.run("") == Ok(Nil)
  assert atto.eof() |> text.run("a")
    == Error(atto.Msg(text.Pos(1, 1), atto.Token("a"), atto.EOF |> singleton))
}

pub fn debug_state_test() {
  {
    use st1 <- atto.bind(atto.debug_state())
    assert st1 == atto.State(["a", "b", "c"], text.Pos(1, 1), Nil)
    use _ <- atto.bind(atto.string("ab"))
    use st2 <- atto.bind(atto.debug_state())
    assert st2 == atto.State(["c"], text.Pos(1, 3), Nil)
    atto.pure(Nil)
  }
  |> text.run("abc")
}

pub fn option_test() {
  let p = atto.option(atto.char("a"))
  assert p |> text.run("a") == Ok(Ok("a"))
  assert p |> text.run("b") == Ok(Error(Nil))
}

pub fn option_or_test() {
  let p = atto.char("a") |> atto.option_or("z")
  assert p |> text.run("a") == Ok("a")
  assert p |> text.run("b") == Ok("z")
}

pub fn many_test() {
  let p = atto.many(text.digit())
  assert p |> text.run("123") == Ok(["1", "2", "3"])
  assert p |> text.run("67zz") == Ok(["6", "7"])
  assert p |> text.run("b") == Ok([])
}

pub fn many_1_test() {
  let p = atto.many_1(text.digit())
  assert p |> text.run("123") == Ok(["1", "2", "3"])
  assert p |> text.run("67") == Ok(["6", "7"])
  assert p |> text.run("b")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("b"),
      atto.Name("digit") |> singleton,
    ))
}

pub fn sep_by_test() {
  let p = text.digit() |> atto.sep_by(atto.char(","))
  assert p |> text.run("1,2,3") == Ok(["1", "2", "3"])
  assert p |> text.run("4,5,6") == Ok(["4", "5", "6"])
  assert p |> text.run("") == Ok([])
}

pub fn sep_by_1_test() {
  let p = text.digit() |> atto.sep_by_1(atto.char(","))
  assert p |> text.run("1,2,3") == Ok(["1", "2", "3"])
  assert p |> text.run("4,5,6") == Ok(["4", "5", "6"])
  assert p |> text.run("")
    == Error(atto.Msg(text.Pos(1, 1), atto.EOF, atto.Name("digit") |> singleton))
}

pub fn end_by_test() {
  let p = text.digit() |> atto.end_by(atto.char(";"))
  assert p |> text.run("1;2;3;") == Ok(["1", "2", "3"])
  assert p |> text.run("") == Ok([])
  assert p |> text.run("4;5;6")
    == Error(atto.Msg(text.Pos(1, 6), atto.EOF, atto.Token(";") |> singleton))
}

pub fn end_by_1_test() {
  let p = text.digit() |> atto.end_by_1(atto.char(";"))
  assert p |> text.run("1;2;3;") == Ok(["1", "2", "3"])
  assert p |> text.run("")
    == Error(atto.Msg(text.Pos(1, 1), atto.EOF, atto.Name("digit") |> singleton))
}

pub fn between_test() {
  let p = text.digit() |> atto.between(atto.char("["), atto.char("]"))
  assert p |> text.run("[1]") == Ok("1")
  assert p |> text.run("[3]") == Ok("3")
  assert p |> text.run("[7")
    == Error(atto.Msg(text.Pos(1, 3), atto.EOF, atto.Token("]") |> singleton))
}

pub fn one_of_test() {
  let p = atto.one_of([atto.char("a"), atto.char("b"), atto.char("c")])
  assert p |> text.run("a") == Ok("a")
  assert p |> text.run("b") == Ok("b")
  assert p |> text.run("c") == Ok("c")
  assert p |> text.run("d")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("d"),
      set.from_list([atto.Token("a"), atto.Token("b"), atto.Token("c")]),
    ))

  assert atto.one_of([atto.pure(5), atto.pure(10)])
    |> text.run("")
    == Ok(5)
}

pub fn seq_test() {
  let p = atto.seq([atto.char("a"), atto.char("b"), atto.char("c")])
  assert p |> text.run("abc") == Ok(["a", "b", "c"])
  assert p |> text.run("ab")
    == Error(atto.Msg(text.Pos(1, 3), atto.EOF, atto.Token("c") |> singleton))
}

pub fn not_followed_by_test() {
  let p = atto.not_followed_by(atto.char("a"))
  assert p |> text.run("a")
    == Error(atto.Msg(text.Pos(1, 1), atto.None, set.new()))
  assert p |> text.run("b") == Ok(Nil)
}

pub fn this_test() {
  assert { atto.char("a") |> atto.this(atto.char("b")) } |> text.run("ab")
    == Ok("b")
}

pub fn that_test() {
  assert { atto.char("a") |> atto.that(atto.char("b")) } |> text.run("ab")
    == Ok("a")
}

pub fn both_test() {
  assert { atto.char("a") |> atto.both(atto.char("b")) } |> text.run("ab")
    == Ok(#("a", "b"))
}

pub fn map_test() {
  assert atto.string("hello")
    |> atto.map(fn(c) { c <> "!" })
    |> text.run("hello")
    == Ok("hello!")
}

fn singleton(x) {
  set.new() |> set.insert(x)
}
