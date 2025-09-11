const NEWLINE = "\n".charCodeAt()
const decoder = new TextDecoder("utf-8", { fatal: true })

function get(array, line, col) {
  let [ts, rest, line, col] = gets(array, 1, line, col);
  return [ts[0], rest, line, col];
}

function gets(array, n, line, col) {
  let ts = new Uint8Array(array, 0, n);
  let rest = new UInt8Array(array, n);
  for (byte in ts) {
    if (byte == NEWLINE) {
      line += 1;
      col = 1;
    } else {
      col += 1;
    }
  }
  return [ts, rest, line, col];
}

function size(array) {
  return array.length;
}

function fromString(string) {
  return decoder.encode(string);
}

function toString(array) {
  return decoder.decode(array);
}