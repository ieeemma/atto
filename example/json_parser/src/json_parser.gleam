import atto/stream/text
import gleam/int
import gleam/io
import gleam/option
import gleam/string
import in

import format.{format}
import parse.{json_file}

pub fn main() {
  case in.read_chars(int.bitwise_shift_left(1, 32)) {
    Error(e) -> io.println_error(string.inspect(e))
    Ok(str) ->
      case text.run(json_file(), str) {
        Error(e) -> io.println_error(text.render(e, str, option.None))
        Ok(json) -> io.println(format(json))
      }
  }
}
