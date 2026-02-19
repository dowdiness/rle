// AuthoredRun: a run of text attributed to a single author.
// Adjacent runs from the same author merge automatically.

struct AuthoredRun {
  author : String
  text : String
} derive(Show, Eq)

impl @rle.Mergeable for AuthoredRun with can_merge(
  a : AuthoredRun,
  b : AuthoredRun,
) -> Bool {
  a.author == b.author
}

impl @rle.Mergeable for AuthoredRun with merge(
  a : AuthoredRun,
  b : AuthoredRun,
) -> AuthoredRun {
  { author: a.author, text: a.text + b.text }
}

impl @rle.HasLength for AuthoredRun with length(self : AuthoredRun) -> Int {
  self.text.length()
}

impl @rle.Spanning for AuthoredRun with span(self : AuthoredRun) -> Int {
  self.text.length()
}

impl @rle.Sliceable for AuthoredRun with slice(
  self : AuthoredRun,
  start~ : Int,
  end~ : Int,
) -> Result[AuthoredRun, @rle.RleError] {
  match @rle.slice_string_view(self.text, start~, end~) {
    Ok(sliced) => Ok({ author: self.author, text: sliced })
    Err(err) =>
      match err {
        @builtin.IndexOutOfBounds =>
          Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::IndexOutOfBounds))
        @builtin.InvalidIndex =>
          Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex))
      }
  }
}

fn authored(author : String, text : String) -> AuthoredRun {
  { author, text }
}

fn main {
  println("=== Same-Author Merge ===")
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  rle.append(authored("alice", "Hello")) |> println   //=> Ok(())
  rle.append(authored("alice", ", world")) |> println //=> Ok(())
  rle.length() |> println  //=> 1  (merged)
  rle.get(0) |> println    //=> Some({author: "alice", text: "Hello, world"})

  println("\n=== Different-Author Separation ===")
  let rle2 : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  rle2.append(authored("alice", "Hello")) |> println
  rle2.append(authored("bob", " world")) |> println
  rle2.length() |> println  //=> 2  (kept separate)
  rle2.get(0) |> println    //=> Some({author: "alice", text: "Hello"})
  rle2.get(1) |> println    //=> Some({author: "bob",   text: " world"})

  println("\n=== Split at Author Boundary ===")
  match rle2.split(5) {
    Ok((left, right)) => {
      left.length() |> println   //=> 1
      right.length() |> println  //=> 1
      left.get(0) |> println     //=> Some({author: "alice", text: "Hello"})
      right.get(0) |> println    //=> Some({author: "bob",   text: " world"})
    }
    Err(e) => e |> println
  }

  println("\n=== Range Across Runs ===")
  // "Hello" (alice, 0-4) + " world" (bob, 5-10)
  // range(3, 8) -> "lo" from alice, " wo" from bob
  match rle2.range(start=3, end=8) {
    Ok(iter) =>
      iter.each(fn(slice) {
        match slice.to_inner() {
          Ok(r) => println("\{r.author}: \{r.text}")
          Err(e) => e |> println
        }
      })
      //=> alice: lo
      //=> bob:  wo
    Err(e) => e |> println
  }

  println("\n=== From Array (same-author merges) ===")
  let runs = [
    authored("alice", "foo"),
    authored("alice", "bar"),
    authored("bob", "baz"),
  ]
  let rle3 = @rle.Rle::from_array(runs)
  rle3.length() |> println  //=> 2  (alice merged, bob separate)
  rle3.get(0) |> println    //=> Some({author: "alice", text: "foobar"})
  rle3.get(1) |> println    //=> Some({author: "bob",   text: "baz"})
}
