import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/set

// TODO: opaque, error printing

/// The current state of the parser, containing the source `s`,
/// position `p`, and context `c`.
pub type State(s, p, c) {
  State(src: s, pos: p, ctx: c)
}

/// The stream interface, allowing the parser to consume input.
pub type Stream(t, ts, s, p, c) {
  Stream(
    /// Pop a token from the stream, advancing the position.
    /// Returns `Error(Nil)` if the stream is empty.
    get: fn(State(s, p, c)) -> Result(#(t, State(s, p, c)), Nil),
    /// Get a chunk of tokens from the stream, advancing the position.
    /// Returns `Error(Nil)` if the stream has fewer tokens than required.
    gets: fn(State(s, p, c), Int) -> Result(#(ts, State(s, p, c)), Nil),
    /// Get the length of a chunk.
    len: fn(ts) -> Int,
    /// Compare two positions.
    cmp_pos: fn(p, p) -> order.Order,
    /// Check if two tokens are equal.
    eq_tok: fn(t, t) -> Bool,
    /// Check if two token chunks are equal.
    eq_toks: fn(ts, ts) -> Bool,
  )
}

/// Create a new stream interface.
pub fn make_stream(
  get get,
  gets gets,
  len len,
  cmp_pos cmp_pos,
  eq_tok eq_tok,
  eq_toks eq_toks,
) -> Stream(t, ts, s, p, c) {
  Stream(get, gets, len, cmp_pos, eq_tok, eq_toks)
}

/// A parsing error message, containing the position of the error,
/// the found token, and the expected set.
pub type Msg(t, ts, s, p, c, e) {
  Msg(pos: p, found: MsgPart(t, ts, e), expected: set.Set(MsgPart(t, ts, e)))
}

/// An item in a parsing error message.
pub type MsgPart(t, ts, e) {
  Token(t)
  Tokens(ts)
  Custom(e)
  Name(String)
  EOF
  None
}

fn merge(
  a: Msg(t, ts, s, p, c, e),
  b: Msg(t, ts, s, p, c, e),
  stream: Stream(t, ts, s, p, c),
) -> Msg(t, ts, s, p, c, e) {
  case stream.cmp_pos(a.pos, b.pos) {
    order.Gt -> a
    order.Lt -> b
    // TODO: This is a hack around not_followed_by taking `None` as the preferred
    // error msg. Will this have any negative consequences?
    order.Eq ->
      Msg(
        a.pos,
        case a.found {
          None -> b.found
          a -> a
        },
        set.union(a.expected, b.expected),
      )
  }
}

/// Did a parser consume input?
pub type Consumed {
  Consumed
  Empty
}

/// A reply from running a parser, containing the result of `#(value, new_state)`,
/// a parsing error message, and a flag indicating if input was consumed.
pub type Reply(a, t, ts, s, p, c, e) =
  #(Result(#(a, State(s, p, c)), Nil), Msg(t, ts, s, p, c, e), Consumed)

fn merge_into(
  reply: Reply(a, t, ts, s, p, c, e),
  stream: Stream(t, ts, s, p, c),
  m: Msg(t, ts, s, p, c, e),
  c: option.Option(Consumed),
) -> Reply(a, t, ts, s, p, c, e) {
  #(reply.0, merge(reply.1, m, stream), case reply.0 {
    Ok(_) -> reply.2
    Error(_) -> option.unwrap(c, reply.2)
  })
}

/// A parser, parameterized by:
/// - result `a`
/// - token `t`
/// - token chunk `ts`
/// - source `s`
/// - position `p`
/// - context value `c`
/// - error value `e`
/// This contains a function to run the parser, advancing the state
/// and producing a value or error.
pub type Parser(a, t, ts, s, p, c, e) {
  Parser(
    run: fn(Stream(t, ts, s, p, c), State(s, p, c)) ->
      Reply(a, t, ts, s, p, c, e),
  )
}

/// Run a parser against a stream interface and initial state.
/// On success, this returns `Ok(result)` and on failure
/// this returns `Error(error_message)`.
pub fn run(p: Parser(a, t, ts, s, p, c, e), stream, state) {
  let #(res, msg, _) = p.run(stream, state)
  res |> result.map(fn(x) { x.0 }) |> result.replace_error(msg)
}

/// Run a parser against a stream interface and initial state.
/// On success, this returns `Ok(#(result, final_state))` and on failure
/// this returns `Error(error_message)`.
pub fn run_state(p: Parser(a, t, ts, s, p, c, e), stream, state) {
  let #(res, msg, _) = p.run(stream, state)
  res |> result.replace_error(msg)
}

/// A parser that fails and consumes no input.
pub fn empty() -> Parser(a, t, ts, s, p, c, e) {
  fn(_, state: State(s, p, c)) {
    #(Error(Nil), Msg(state.pos, None, set.new()), Empty)
  }
  |> Parser
}

/// A parser that fails with a message and consumes no input.
pub fn fail(msg) -> Parser(a, t, ts, s, p, c, e) {
  fn(_, state: State(s, p, c)) {
    #(Error(Nil), Msg(state.pos, Name(msg), set.new()), Empty)
  }
  |> Parser
}

/// A parser that fails with a custom value and consumes no input.
pub fn fail_with(value) -> Parser(a, t, ts, s, p, c, e) {
  fn(_, state: State(s, p, c)) {
    #(Error(Nil), Msg(state.pos, Custom(value), set.new()), Empty)
  }
  |> Parser
}

/// A parser that succeeds with a value and consumes no input.
/// This is often used at the end of a `use` syntax block to
/// return a value.
/// 
/// ## Examples
/// 
/// ```gleam
/// atto.pure(42)
/// // -> Ok(42)
/// ```
/// 
/// ```gleam
/// {
///   use x <- atto.bind(...)
///   use xs <- atto.bind(atto.many(...))
///   atto.pure([x ..xs])
/// }
/// ```
pub fn pure(x: a) -> Parser(a, t, ts, s, p, c, e) {
  fn(_, state: State(s, p, c)) {
    #(Ok(#(x, state)), Msg(state.pos, None, set.new()), Consumed)
  }
  |> Parser
}

/// Bind the result of a parser to a new parser, allowing parsers to be
/// chained together.
/// This is useful with `use` syntax.
/// 
/// ## Examples
/// 
/// ```gleam
/// atto.bind(digit(), fn(x) { atto.pure(x + 1) })
/// // "5" -> Ok(6)
/// ```
/// 
/// ```gleam
/// {
///   use a <- atto.bind(digit())
///   use b <- atto.bind(digit())
///   atto.pure(int.max(a, b))
/// }
/// // "64" -> Ok(6)
/// ```
pub fn bind(
  p: Parser(a, t, ts, s, p, c, e),
  f: fn(a) -> Parser(b, t, ts, s, p, c, e),
) -> Parser(b, t, ts, s, p, c, e) {
  fn(stream, state) {
    case p.run(stream, state) {
      #(Error(_), err, c) -> #(Error(Nil), err, c)
      #(Ok(#(a, state)), err, c) ->
        f(a).run(stream, state) |> merge_into(stream, err, option.Some(c))
    }
  }
  |> Parser
}

/// Choose between two parsers.
/// If the first succeeds or fails while consuming input, it is preferred.
/// To ignore any errors in the first parser, wrap it in [`atto.try`](#try).
/// 
/// > Hint: The function [`atto.one_of`](#one_of) is usually preferred over `choice`.
/// 
/// ## Examples
/// 
/// ```gleam
/// atto.choice(atto.char("foo"), atto.char("bar"))
/// // "bar" -> Ok("bar")
/// ```
/// 
/// ```gleam
/// atto.choice(
///   // `try` is required to backtrack even if one `a` has been parsed.
///   atto.many(atto.char("a")) |> atto.try,
///   atto.string("abc"),
/// )
/// ```
pub fn choice(
  a: Parser(a, t, ts, s, p, c, e),
  b: Parser(a, t, ts, s, p, c, e),
) -> Parser(a, t, ts, s, p, c, e) {
  fn(stream, state) {
    case a.run(stream, state) {
      #(Error(_), err, Empty) ->
        b.run(stream, state) |> merge_into(stream, err, option.None)
      a -> a
    }
  }
  |> Parser
}

/// Wrap a parser, but backtrack if it fails, allowing arbitrary lookahead.
/// See [atto.choice](#choice) for more details.
pub fn try(p: Parser(a, t, ts, s, p, c, e)) -> Parser(a, t, ts, s, p, c, e) {
  fn(stream, state) {
    case p.run(stream, state) {
      #(Error(_), err, Consumed) -> #(
        Error(Nil),
        Msg(..err, pos: state.pos),
        Empty,
      )
      a -> a
    }
  }
  |> Parser
}

/// Lazily evaluate a parser, allowing it to be defined in terms of itself.
/// 
/// > Hint: prefer [`atto.label`](#label) as it functions the same.
pub fn lazy(
  f: fn() -> Parser(a, t, ts, s, p, c, e),
) -> Parser(a, t, ts, s, p, c, e) {
  fn(stream, state) { f().run(stream, state) }
  |> Parser
}

/// Label a parser with an expected string.
/// This improves error messages by providing context about what was expected.
/// 
/// ## Examples
///
/// ```gleam
/// atto.label(atto.char("a"), "an 'a' character")
/// // "b" -> Error("expected an 'a' character")
/// ```
pub fn label(
  expected: String,
  f: fn() -> Parser(a, t, ts, s, p, c, e),
) -> Parser(a, t, ts, s, p, c, e) {
  fn(stream, state) {
    case f().run(stream, state) {
      #(Error(_), msg, Empty) -> #(
        Error(Nil),
        Msg(..msg, expected: set.new() |> set.insert(Name(expected))),
        Empty,
      )
      a -> a
    }
  }
  |> Parser
}

/// Label a parser with an expected string.
/// This variant can be used within a pipe chain.
pub fn label_inline(p, expected) {
  label(expected, fn() { p })
}

/// Parse the next token using a match function, and a set of expected results.
///
/// > Hint: This function is very low-level, consider [`atto.char`](#char) or [`atto.satisfy`](#satisfy).
pub fn token(f, expected) -> Parser(a, t, ts, s, p, c, e) {
  fn(stream: Stream(t, ts, s, p, c), state) {
    case stream.get(state) {
      Ok(#(t, state2)) -> {
        let msg = Msg(state.pos, Token(t), expected)
        case f(t) {
          Ok(a) -> #(Ok(#(a, state2)), msg, Consumed)
          Error(Nil) -> #(Error(Nil), msg, Empty)
        }
      }
      Error(_) -> #(Error(Nil), Msg(state.pos, EOF, expected), Empty)
    }
  }
  |> Parser
}

/// Parse a token using a predicate function.
/// 
/// ## Examples
/// 
/// ```
/// atto.satisfy(fn(t) { t == "x" })
/// // "x" -> Ok("x")
/// // "y" -> Error("expected token matching predicate")
/// ```
pub fn satisfy(f) -> Parser(t, t, ts, s, p, c, e) {
  token(
    fn(t) {
      case f(t) {
        True -> Ok(t)
        False -> Error(Nil)
      }
    },
    set.new() |> set.insert(Name("token matching predicate")),
  )
}

/// Parse an exact token.
/// 
/// ## Examples
/// 
/// ```
/// atto.char("a")
/// // "abc" -> Ok("a")
/// ```
pub fn char(c) -> Parser(t, t, ts, s, p, c, e) {
  fn(stream: Stream(t, ts, s, p, c), state) {
    token(
      fn(t) {
        case stream.eq_tok(t, c) {
          True -> Ok(t)
          False -> Error(Nil)
        }
      },
      set.new() |> set.insert(Token(c)),
    ).run(stream, state)
  }
  |> Parser
}

/// Parse any token.
pub fn any() -> Parser(t, t, ts, s, p, c, e) {
  fn(stream: Stream(t, ts, s, p, c), state) {
    token(Ok, set.new() |> set.insert(Name("any token"))).run(stream, state)
  }
  |> Parser
}

/// Parse an exact chunk of tokens.
/// 
/// ## Examples
///
/// ```gleam
/// atto.string("foo")
/// // "foobar" -> Ok("foo")
/// ```
pub fn string(ts1: ts) -> Parser(ts, t, ts, s, p, c, e) {
  let singleton = fn(a) { set.new() |> set.insert(a) }
  fn(stream: Stream(t, ts, s, p, c), state) {
    case stream.gets(state, stream.len(ts1)) {
      Ok(#(ts2, state2)) -> {
        let msg = Msg(state.pos, Tokens(ts2), singleton(Tokens(ts1)))
        case stream.eq_toks(ts1, ts2) {
          True -> #(Ok(#(ts2, state2)), msg, Consumed)
          False -> #(Error(Nil), msg, Empty)
        }
      }
      Error(_) -> #(
        Error(Nil),
        Msg(state.pos, EOF, singleton(Tokens(ts1))),
        Empty,
      )
    }
  }
  |> Parser
}

/// Parse the end of input.
pub fn eof() -> Parser(Nil, t, ts, s, p, c, e) {
  fn(stream: Stream(t, ts, s, p, c), state: State(s, p, c)) {
    case stream.get(state) {
      Ok(#(t, _)) -> #(
        Error(Nil),
        Msg(state.pos, Token(t), set.new() |> set.insert(EOF)),
        Empty,
      )
      Error(_) -> #(Ok(#(Nil, state)), Msg(state.pos, EOF, set.new()), Empty)
    }
  }
  |> Parser
}

/// Debug the result of a parser.
pub fn debug(p: Parser(a, t, ts, s, p, c, e)) {
  fn(stream, state) { echo p.run(stream, state) }
  |> Parser
}

/// Debug the state of the parser.
pub fn debug_state() -> Parser(State(s, p, c), t, ts, s, p, c, e) {
  fn(_, state: State(s, p, c)) {
    #(Ok(#(state, state)), Msg(state.pos, None, set.new()), Empty)
  }
  |> Parser
}

/// Optionally parse a value, returning `Error(Nil)` if it failed without
/// consuming input.
/// 
/// ## Examples
///
/// ```gleam
/// atto.option(atto.char("a"))
/// // "a" -> Ok("a")
/// // "b" -> Error(Nil)
/// ```
pub fn option(p) -> Parser(Result(a, Nil), t, ts, s, p, c, e) {
  choice(p |> map(Ok), pure(Error(Nil)))
}

/// Optionally parse a value, returning `default` if it failed without
/// consuming input.
/// 
/// ## Examples
///
/// ```gleam
/// atto.option_or(atto.char("a"), "default")
/// // "a" -> Ok("a")
/// // "b" -> Ok("default")
/// ```
pub fn option_or(p, default) -> Parser(a, t, ts, s, p, c, e) {
  option(p) |> map(fn(x) { result.unwrap(x, default) })
}

/// Parse zero or more `p`.
/// 
/// ## Examples
///
/// ```gleam
/// atto.many(atto.char("a"))
/// // "aaa" -> Ok(["a", "a", "a"])
/// // "b" -> Ok([])
/// ```
pub fn many(p) -> Parser(List(a), t, ts, s, p, c, e) {
  choice(many_1(p), pure([]))
}

/// Parse one or more `p`.
/// 
/// ## Examples
///
/// ```gleam
/// atto.many_1(atto.char("a"))
/// // "aaa" -> Ok(["a", "a", "a"])
/// // "b" -> Error("expected 'a'"")
/// ```
pub fn many_1(p) -> Parser(List(a), t, ts, s, p, c, e) {
  use <- lazy()
  p |> both(many(p)) |> map2(cons)
}

/// Parse zero or more `p` separated by `sep`.
/// 
/// ## Examples
///
/// ```gleam
/// atto.sep_by(atto.char("a"), atto.char(","))
/// // "a,a,a" -> Ok(["a", "a", "a"])
/// // "b" -> Ok([])
/// ```
pub fn sep_by(p, sep) -> Parser(List(a), t, ts, s, p, c, e) {
  choice(sep_by_1(p, sep), pure([]))
}

/// Parse one or more `p` separated by `sep`.
/// 
/// ## Examples
///
/// ```gleam
/// atto.sep_by_1(atto.char("a"), atto.char(","))
/// // "a,a,a" -> Ok(["a", "a", "a"])
/// // "b" -> Error("expected 'a'")
/// ```
pub fn sep_by_1(p, sep) -> Parser(List(a), t, ts, s, p, c, e) {
  p |> both(many(sep |> this(p))) |> map2(cons)
}

/// Parse zero or more `p` separated and ended by `sep`.
/// 
/// ## Examples
///
/// ```gleam
/// atto.end_by(atto.char("a"), atto.char(";"))
/// // "a;a;a;" -> Ok(["a", "a", "a"])
/// // "b" -> Ok([])
/// ```
pub fn end_by(p, sep) -> Parser(List(a), t, ts, s, p, c, e) {
  many(p |> that(sep))
}

/// Parse one or more `p` separated and ended by `sep`.
/// 
/// ## Examples
///
/// ```gleam
/// atto.end_by_1(atto.char("a"), atto.char(";"))
/// // "a;a;a;" -> Ok(["a", "a", "a"])
/// // "b" -> Error("expected 'a'")
/// ```
pub fn end_by_1(p, sep) -> Parser(List(a), t, ts, s, p, c, e) {
  many_1(p |> that(sep))
}

/// Parse `p` surrounded by `before` and `after`.
/// 
/// ## Examples
///
/// ```gleam
/// atto.between(atto.char("("), atto.char("a"), atto.char(")"))
/// // "(a)" -> Ok("a")
/// // "(b)" -> Error("expected 'a'")
/// ```
pub fn between(p, before, after) -> Parser(a, t, ts, s, p, c, e) {
  before |> this(p) |> that(after)
}

/// Parse the first success of a list of parsers.
/// If any parser fails while consuming input, that error is returned.
/// 
/// > Hint: this is a fold over [`atto.choice`](#choice) and [`atto.empty`](#empty).
/// 
/// ## Examples
///
/// ```gleam
/// atto.one_of([atto.char("a"), atto.char("b"), atto.char("c")])
/// // "a" -> Ok("a")
/// // "b" -> Ok("b")
/// // "d" -> Error("expected a, b, or, c")
pub fn one_of(ps) -> Parser(a, t, ts, s, p, c, e) {
  // list.fold_right(ps, empty(), choice)
  case ps {
    [p, ..ps] -> list.fold(ps, p, choice)
    [] -> empty()
  }
}

/// Parse a list of parsers and collect their results.
/// If any parser fails, that error is returned.
/// 
/// > Hint: this is a fold over [`atto.bind`](#bind).
pub fn seq(ps: List(Parser(a, t, ts, s, p, c, e))) {
  list.fold_right(ps, pure([]), fn(acc, p) { p |> both(acc) |> map2(cons) })
}

/// Parse negative lookahead. This parser succeeds only if `p` fails.
/// 
/// ## Examples
/// 
/// ```gleam
/// atto.char("a") |> atto.not_followed_by
/// // "a" -> Error()
/// // "b" -> Ok(Nil)
/// ```
pub fn not_followed_by(p) -> Parser(Nil, t, ts, s, p, c, e) {
  choice(try(p) |> bind(fn(_) { empty() }), pure(Nil)) |> try
}

/// Parse two parsers, returning the second result.
pub fn this(p, q: Parser(a, t, ts, s, p, c, e)) {
  use _ <- bind(p)
  use x <- bind(q)
  pure(x)
}

/// Parse two parsers, returning the first result.
pub fn that(p: Parser(a, t, ts, s, p, c, e), q) {
  use x <- bind(p)
  use _ <- bind(q)
  pure(x)
}

/// Parse two parsers, returning both results.
pub fn both(
  p: Parser(a, t, ts, s, p, c, e),
  q: Parser(b, t, ts, s, p, c, e),
) -> Parser(#(a, b), t, ts, s, p, c, e) {
  use x <- bind(p)
  use y <- bind(q)
  pure(#(x, y))
}

/// Apply a function to the result of a parser.
/// 
/// ## Examples
/// 
/// ```gleam
/// digit() |> atto.map(fn(x) { x * 2 })
/// // "5" -> Ok(10)
/// ```
pub fn map(
  p: Parser(a, t, ts, s, p, c, e),
  f: fn(a) -> b,
) -> Parser(b, t, ts, s, p, c, e) {
  bind(p, fn(a) { pure(f(a)) })
}

/// Apply a function to a nested parse result.
pub fn map2(
  p: Parser(#(a1, a2), t, ts, s, p, c, e),
  f: fn(a1, a2) -> b,
) -> Parser(b, t, ts, s, p, c, e) {
  use #(a, b) <- bind(p)
  pure(f(a, b))
}

/// Apply a function to a nested parse result.
pub fn map3(
  p: Parser(#(#(a1, a2), a3), t, ts, s, p, c, e),
  f: fn(a1, a2, a3) -> b,
) -> Parser(b, t, ts, s, p, c, e) {
  use #(#(a, b), c) <- bind(p)
  pure(f(a, b, c))
}

/// Apply a function to a nested parse result.
pub fn map4(
  p: Parser(#(#(#(a1, a2), a3), a4), t, ts, s, p, c, e),
  f: fn(a1, a2, a3, a4) -> b,
) -> Parser(b, t, ts, s, p, c, e) {
  use #(#(#(a, b), c), d) <- bind(p)
  pure(f(a, b, c, d))
}

/// Apply a function to a nested parse result.
pub fn map5(
  p: Parser(#(#(#(#(a1, a2), a3), a4), a5), t, ts, s, p, c, e),
  f: fn(a1, a2, a3, a4, a5) -> b,
) -> Parser(b, t, ts, s, p, c, e) {
  use #(#(#(#(a, b), c), d), e) <- bind(p)
  pure(f(a, b, c, d, e))
}

/// Utility function to prepend an element to a list.
pub fn cons(x: a, xs: List(a)) -> List(a) {
  [x, ..xs]
}
