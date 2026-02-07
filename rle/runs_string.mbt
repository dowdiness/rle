///| String-specific operations for Runs

///|
/// String implements Mergeable - strings always merge
pub impl Mergeable for String with can_merge(_a : String, _b : String) -> Bool {
  true
}

///|
pub impl Mergeable for String with merge(a : String, b : String) -> String {
  a + b
}

///|
/// String implements HasLength
pub impl HasLength for String with length(self : String) -> Int {
  self.length()
}

///|
/// String implements Spanning - span = content_len = UTF-16 code unit count
pub impl Spanning for String with content_len(self : String) -> Int {
  self.length()
}

///|
/// String helper that uses view slicing with explicit error handling.
pub fn slice_string_view(
  text : String,
  start~ : Int,
  end~ : Int,
) -> Result[String, @builtin.CreatingViewError] {
  try text[start:end] catch {
    err => Err(err)
  } noraise {
    view => Ok(view.to_string())
  }
}

///|
/// String implements Sliceable via substring
pub impl Sliceable for String with slice(
  self : String,
  start~ : Int,
  end~ : Int,
) -> Result[String, RleError] {
  // Keep slicing consistent with length()/span indexing (UTF-16 code units).
  match slice_string_view(self, start~, end~) {
    Ok(value) => Ok(value)
    Err(err) =>
      match err {
        @builtin.IndexOutOfBounds =>
          Err(RleError::InvalidSlice(reason=SliceError::IndexOutOfBounds))
        @builtin.InvalidIndex =>
          Err(RleError::InvalidSlice(reason=SliceError::InvalidIndex))
      }
  }
}

///|
/// Create from string (single run)
pub fn Runs::from_string(text : String) -> Runs[String] {
  if text.is_empty() {
    Runs::new()
  } else {
    Runs([text])
  }
}

///|
/// Concatenate all runs into single string
pub fn Runs::to_string(self : Runs[String]) -> String {
  self.0
  .fold(init=StringBuilder::new(), fn(sb, s) {
    sb.write_string(s)
    sb
  })
  .to_string()
}

///|
/// Iterate over codepoints
pub fn Runs::iter_chars(self : Runs[String]) -> Iter[Char] {
  let chars : Array[Char] = []
  for run in self.0 {
    for c in run {
      chars.push(c)
    }
  }
  chars.iter()
}

///|
/// Create Rle from string
pub fn Rle::from_string(text : String) -> Rle[String] {
  Rle::from_runs(Runs::from_string(text))
}

///|
/// Concatenate all runs into single string
pub fn Rle::to_string(self : Rle[String]) -> String {
  self.runs.to_string()
}

///|
/// Iterate over codepoints
pub fn Rle::iter_chars(self : Rle[String]) -> Iter[Char] {
  self.runs.iter_chars()
}
