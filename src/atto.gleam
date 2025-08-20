import gleam/option
import gleam/order
import gleam/result
import gleam/set

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
    order.Eq -> Msg(..a, expected: set.union(a.expected, b.expected))
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
  #(reply.0, merge(m, reply.1, stream), case reply.0 {
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
/// On success, this returns `Ok(#(result, final_state))` and on failure
/// this returns `Error(error_message)`.
pub fn run(p: Parser(a, t, ts, s, p, c, e), stream, state) {
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
/// // -> 42
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
/// // "5" -> 6
/// ```
/// 
/// ```gleam
/// {
///   use a <- atto.bind(digit())
///   use b <- atto.bind(digit())
///   atto.pure(int.max(a, b))
/// }
/// // "64" -> 6
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
/// // "bar" -> "bar"
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
      #(Error(_), err, Consumed) -> #(Error(Nil), err, Empty)
      a -> a
    }
  }
  |> Parser
}

/// Label a parser with an expected string.
/// This improves error messages by providing context about what was expected.
/// 
/// ## Examples
///
/// ```gleam
/// atto.label(atto.char("a"), "an 'a' character")
/// // "b" -> Msg(expected: "an 'a' character")
/// ```
pub fn label(
  p: Parser(a, t, ts, s, p, c, e),
  expected: String,
) -> Parser(a, t, ts, s, p, c, e) {
  fn(stream, state) {
    case p.run(stream, state) {
      #(Error(_), msg, c) -> #(
        Error(Nil),
        Msg(..msg, expected: set.new() |> set.insert(Name(expected))),
        c,
      )
      a -> a
    }
  }
  |> Parser
}

/// Parse the next token using a match function, and a set of expected results.
///
/// > Hint: This function is very low-level, consider [`atto.char`](#char) or [`atto.satisfy`](#satisfy).
pub fn token(f, expected) -> Parser(a, t, ts, s, p, c, e) {
  fn(stream: Stream(t, ts, s, p, c), state) {
    case stream.get(state) {
      Ok(#(t, state)) -> {
        let msg = Msg(state.pos, Token(t), expected)
        case f(t) {
          Ok(a) -> #(Ok(#(a, state)), msg, Consumed)
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
/// // "x" -> "x"
/// // "y" -> Msg(expected: "token matching predicate")
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
/// // "abc" -> "a"
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
/// // "foobar" -> "foo"
/// ```
pub fn string(ts1: ts) -> Parser(ts, t, ts, s, p, c, e) {
  let singleton = fn(a) { set.new() |> set.insert(a) }
  fn(stream: Stream(t, ts, s, p, c), state) {
    case stream.gets(state, stream.len(ts1)) {
      Ok(#(ts2, state)) -> {
        let msg = Msg(state.pos, Tokens(ts2), singleton(Tokens(ts1)))
        case stream.eq_toks(ts1, ts2) {
          True -> #(Ok(#(ts2, state)), msg, Consumed)
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
