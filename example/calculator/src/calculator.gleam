import atto/stream/text
import gleam/int
import gleam/io
import gleam/option
import gleam/string
import in

import parse.{expression}

pub fn main() {
  case in.read_chars(int.bitwise_shift_left(1, 32)) {
    Error(e) -> io.println_error(string.inspect(e))
    Ok(str) ->
      case text.run(expression(), str) {
        Error(e) -> io.println_error(text.render(e, str, option.None))
        Ok(n) -> io.println(int.to_string(n))
      }
  }
}
