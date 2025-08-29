import atto
import atto/stream/text
import gleam/set
import gleam/string

pub fn new_test() {
  assert text.new("hello world", Nil)
    == atto.State(string.to_graphemes("hello world"), text.Pos(1, 1), Nil)
}

pub fn get_test() {
  assert text.get(text.new("hello", Nil))
    == Ok(#("h", atto.State(string.to_graphemes("ello"), text.Pos(1, 2), Nil)))

  assert text.get(text.new("", Nil)) == Error(Nil)
}

pub fn gets_test() {
  assert text.gets(text.new("hello", Nil), 3)
    == Ok(#("hel", atto.State(string.to_graphemes("lo"), text.Pos(1, 4), Nil)))

  assert text.gets(text.new("hello", Nil), 10) == Error(Nil)

  assert text.gets(text.new("", Nil), 0)
    == Ok(#("", atto.State(string.to_graphemes(""), text.Pos(1, 1), Nil)))

  assert text.gets(text.new("", Nil), 10) == Error(Nil)
}

fn singleton(x) {
  set.new() |> set.insert(x)
}

pub fn char_of_test() {
  assert text.char_of("abc") |> text.run("a") == Ok("a")
  assert text.char_of("abc") |> text.run("z")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("z"),
      atto.Name("one of \"abc\"") |> singleton,
    ))
}

pub fn spaces_test() {
  assert text.spaces() |> text.run("   ") == Ok("   ")
  assert text.spaces() |> text.run("a") == Ok("")
}

pub fn spaces_1_test() {
  assert text.spaces_1() |> text.run("   ") == Ok("   ")
  assert text.spaces_1() |> text.run("a")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("a"),
      atto.Name("spaces") |> singleton,
    ))
}

pub fn lexeme_test() {
  let p = text.char_of("abc") |> text.lexeme
  assert atto.run_state(p, text.stream(), text.new("a   ", Nil))
    == Ok(#("a", atto.State([], text.Pos(1, 5), Nil)))
}

pub fn symbol_test() {
  let p = text.symbol("foo") |> text.lexeme

  assert atto.run_state(p, text.stream(), text.new("foo   ", Nil))
    == Ok(#("foo", atto.State([], text.Pos(1, 7), Nil)))

  assert text.run(p, "bar")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Tokens("bar"),
      atto.Tokens("foo") |> singleton,
    ))
}

pub fn reserved_test() {
  let p = text.reserved("foo")

  assert atto.run_state(p, text.stream(), text.new("foo   ", Nil))
    == Ok(#("foo", atto.State([], text.Pos(1, 7), Nil)))

  assert text.run(p, "foobar")
    == Error(atto.Msg(text.Pos(1, 1), atto.None, atto.Name("foo") |> singleton))

  assert text.run(p, "bar")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Tokens("bar"),
      atto.Name("foo") |> singleton,
    ))
}

pub fn alpha_test() {
  let p = text.alpha()

  assert text.run(p, "abc") == Ok("a")
  assert text.run(p, "Abc") == Ok("A")
  assert text.run(p, "1bc")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("1"),
      atto.Name("alpha") |> singleton,
    ))
}

pub fn digit_test() {
  let p = text.digit()

  assert text.run(p, "123") == Ok("1")
  assert text.run(p, "abc")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("a"),
      atto.Name("digit") |> singleton,
    ))
}

pub fn digit_nonzero_test() {
  let p = text.digit_nonzero()

  assert text.run(p, "123") == Ok("1")
  assert text.run(p, "0bc")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("0"),
      atto.Name("non-zero digit") |> singleton,
    ))
}

pub fn alphanum_test() {
  let p = text.alphanum()

  assert text.run(p, "abc") == Ok("a")
  assert text.run(p, "123") == Ok("1")
  assert text.run(p, "!@#")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("!"),
      atto.Name("alphanum") |> singleton,
    ))
}

pub fn integer_test() {
  let p = text.integer()

  assert text.run(p, "123") == Ok(123)
  assert text.run(p, "0") == Ok(0)
  assert text.run(p, "abc")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("a"),
      atto.Name("integer") |> singleton,
    ))
}

pub fn float_test() {
  let p = text.float()

  assert text.run(p, "123.45") == Ok(123.45)
  assert text.run(p, "0.0") == Ok(0.0)
  assert text.run(p, "abc")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("a"),
      atto.Name("float") |> singleton,
    ))
}

pub fn signed_test() {
  let p = text.signed(text.integer(), fn(x) { -x })

  assert text.run(p, "123") == Ok(123)
  assert text.run(p, "+123") == Ok(123)
  assert text.run(p, "-123") == Ok(-123)
  assert text.run(p, "abc")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("a"),
      set.from_list([atto.Name("integer"), atto.Token("+"), atto.Token("-")]),
    ))
}

pub fn char_literal_test() {
  let p = text.char_literal()

  assert text.run(p, "'a'") == Ok("a")
  assert text.run(p, "'\\n'") == Ok("\n")
  assert text.run(p, "'\\''") == Ok("'")
  assert text.run(p, "'\\z'")
    == Error(atto.Msg(text.Pos(1, 3), atto.Name("invalid escape"), set.new()))
  assert text.run(p, "abc")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("a"),
      atto.Token("'") |> singleton,
    ))
}

pub fn string_literal_test() {
  let p = text.string_literal()

  assert text.run(p, "\"hello\"") == Ok("hello")
  assert text.run(p, "\"hello\\nworld\"") == Ok("hello\nworld")
  assert text.run(p, "\"hello\\\"world\"") == Ok("hello\"world")
  assert text.run(p, "\"hello\\\\world\"") == Ok("hello\\world")
  assert text.run(p, "\"hello\\zworld\"")
    == Error(atto.Msg(text.Pos(1, 8), atto.Name("invalid escape"), set.new()))
  assert text.run(p, "abc")
    == Error(atto.Msg(
      text.Pos(1, 1),
      atto.Token("a"),
      atto.Token("\"") |> singleton,
    ))
}
