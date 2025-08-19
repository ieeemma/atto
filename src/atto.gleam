import core.{parse_test}
import gleam/io
import gleam/string

pub fn main() -> Nil {
  echo parse_test() |> string.inspect |> io.println
}
