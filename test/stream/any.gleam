import atto
import atto/stream/any
import gleam/int
import gleam/list

pub fn new_test() {
  assert any.new([1, 2, 3], 0, Nil) == atto.State([1, 2, 3], 0, Nil)
}

pub fn get_test() {
  let stream =
    any.stream(fn(ts, i) { i + list.length(ts) }, int.compare, fn(a, b) {
      a == b
    })

  assert stream.get(any.new([1, 2, 3], 0, Nil))
    == Ok(#(1, atto.State([2, 3], 1, Nil)))

  assert stream.get(any.new([], 0, Nil)) == Error(Nil)
}

pub fn gets_test() {
  let stream =
    any.stream(fn(ts, i) { i + list.length(ts) }, int.compare, fn(a, b) {
      a == b
    })

  assert stream.gets(any.new([1, 2, 3], 0, Nil), 2)
    == Ok(#([1, 2], atto.State([3], 2, Nil)))

  assert stream.gets(any.new([1, 2, 3], 0, Nil), 10) == Error(Nil)

  assert stream.gets(any.new([], 0, Nil), 0)
    == Ok(#([], atto.State([], 0, Nil)))

  assert stream.gets(any.new([], 0, Nil), 5) == Error(Nil)
}
