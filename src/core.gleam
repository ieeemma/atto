import gleam/int
import gleam/option
import gleam/order
import gleam/set
import gleam/string

pub type State(s, p, c) {
  State(src: s, pos: p, ctx: c)
}

pub type Stream(t, ts, s, p, c) {
  Stream(
    get: fn(State(s, p, c)) -> Result(#(t, State(s, p, c)), Nil),
    gets: fn(State(s, p, c), Int) -> Result(#(ts, State(s, p, c)), Nil),
    len: fn(ts) -> Int,
    cmp_pos: fn(p, p) -> order.Order,
    eq_toks: fn(ts, ts) -> Bool,
  )
}

pub type Msg(t, ts, s, p, c, e) {
  Msg(pos: p, found: MsgPart(t, ts, e), expected: set.Set(MsgPart(t, ts, e)))
}

pub type MsgPart(t, ts, e) {
  Token(t)
  Tokens(ts)
  Custom(e)
  EOF
  None
}

pub fn merge(
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

pub type Consumed {
  Consumed
  Empty
}

pub type Reply(a, t, ts, s, p, c, e) {
  Yes(result: a, state: State(s, p, c), msg: Msg(t, ts, s, p, c, e))
  No(msg: Msg(t, ts, s, p, c, e))
}

pub type ParseResult(a, t, ts, s, p, c, e) =
  #(Reply(a, t, ts, s, p, c, e), Consumed)

fn merge_into(
  result: ParseResult(a, t, ts, s, p, c, e),
  stream: Stream(t, ts, s, p, c),
  msg1: Msg(t, ts, s, p, c, e),
  c1: option.Option(Consumed),
) -> ParseResult(a, t, ts, s, p, c, e) {
  case result {
    #(Yes(_, _, msg2) as y, c2) -> #(
      Yes(..y, msg: merge(msg1, msg2, stream)),
      c2,
    )
    #(No(msg2), c2) -> #(No(merge(msg1, msg2, stream)), option.unwrap(c1, c2))
  }
}

pub type Parser(a, t, ts, s, p, c, e) =
  fn(Stream(t, ts, s, p, c), State(s, p, c)) ->
    ParseResult(a, t, ts, s, p, c, e)

pub fn empty() -> Parser(a, t, ts, s, p, c, e) {
  fn(_, state: State(s, p, c)) { #(No(Msg(state.pos, None, set.new())), Empty) }
}

pub fn pure(x: a) -> Parser(a, t, ts, s, p, c, e) {
  fn(_, state) { #(Yes(x, state, Msg(state.pos, None, set.new())), Consumed) }
}

pub fn bind(
  p: Parser(a, t, ts, s, p, c, e),
  f: fn(a) -> Parser(b, t, ts, s, p, c, e),
) -> Parser(b, t, ts, s, p, c, e) {
  fn(stream, state) {
    case p(stream, state) {
      #(No(err), c) -> #(No(err), c)
      #(Yes(a, state, err), c) ->
        f(a)(stream, state) |> merge_into(stream, err, option.Some(c))
    }
  }
}

pub fn choice(
  a: Parser(a, t, ts, s, p, c, e),
  b: Parser(a, t, ts, s, p, c, e),
) -> Parser(a, t, ts, s, p, c, e) {
  fn(stream, state) {
    case a(stream, state) {
      #(No(err1), Empty) ->
        b(stream, state) |> merge_into(stream, err1, option.None)
      a -> a
    }
  }
}

pub fn try(p: Parser(a, t, ts, s, p, c, e)) -> Parser(a, t, ts, s, p, c, e) {
  fn(stream, state) {
    case p(stream, state) {
      #(No(err), Consumed) -> #(No(err), Empty)
      a -> a
    }
  }
}

pub fn token(
  f: fn(t) -> Result(a, Nil),
  expected: set.Set(MsgPart(t, ts, e)),
) -> Parser(a, t, ts, s, p, c, e) {
  fn(stream: Stream(t, ts, s, p, c), state) {
    case stream.get(state) {
      Ok(#(t, state)) -> {
        let msg = Msg(state.pos, Token(t), expected)
        case f(t) {
          Ok(a) -> #(Yes(a, state, msg), Consumed)
          Error(_) -> #(No(msg), Empty)
        }
      }
      Error(_) -> #(No(Msg(state.pos, EOF, expected)), Empty)
    }
  }
}

pub fn string(ts1: ts) -> Parser(ts, t, ts, s, p, c, e) {
  let singleton = fn(a) { set.new() |> set.insert(a) }
  fn(stream: Stream(t, ts, s, p, c), state) {
    case stream.gets(state, stream.len(ts1)) {
      Ok(#(ts2, state)) -> {
        let msg = Msg(state.pos, Tokens(ts2), singleton(Tokens(ts1)))
        case stream.eq_toks(ts1, ts2) {
          True -> #(Yes(ts2, state, msg), Consumed)
          False -> #(No(msg), Empty)
        }
      }
      Error(_) -> #(No(Msg(state.pos, EOF, singleton(Tokens(ts1)))), Empty)
    }
  }
}

fn string_stream() {
  Stream(
    fn(state: State(String, Int, c)) {
      case string.pop_grapheme(state.src) {
        Ok(#(h, t)) -> Ok(#(h, State(t, state.pos + 1, state.ctx)))
        Error(_) -> Error(Nil)
      }
    },
    fn(state: State(String, Int, c), n: Int) {
      let m = string.length(state.src)
      case n > m {
        True -> Error(Nil)
        False -> {
          let h = string.drop_end(state.src, m - n)
          let t = string.drop_start(state.src, n)
          Ok(#(h, State(t, state.pos + n, state.ctx)))
        }
      }
    },
    string.length,
    int.compare,
    fn(a, b) { a == b },
  )
}

pub fn parse_test() {
  let p =
    choice(
      try(bind(string("a"), fn(_) { string("b") })),
      bind(string("a"), fn(_) { string("c") }),
    )

  p(string_stream(), State("az", 0, Nil))
}
