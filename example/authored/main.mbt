// AuthoredRun: a run of text attributed to a single author.
// Adjacent runs from the same author merge automatically.

///|
#derive(Debug, Eq)
struct AuthoredRun {
  author : String
  text : String
}

///|
impl @rle.Mergeable for AuthoredRun with fn can_merge(
  a : AuthoredRun,
  b : AuthoredRun,
) -> Bool {
  a.author == b.author
}

///|
impl @rle.Mergeable for AuthoredRun with fn merge(
  a : AuthoredRun,
  b : AuthoredRun,
) -> AuthoredRun {
  { author: a.author, text: a.text + b.text, }
}

///|
impl @rle.HasLength for AuthoredRun with fn length(self : AuthoredRun) -> Int32 {
  self.text.length()
}

///|
impl @rle.Spanning for AuthoredRun with fn span(self : AuthoredRun) -> Int32 {
  self.text.length()
}

///|
/// Sliceable via String's built-in Sliceable impl — validates bounds and
/// surrogate pair boundaries automatically.
impl @rle.Sliceable for AuthoredRun with fn slice(
  self : AuthoredRun,
  start~ : Int32,
  end~ : Int32,
) -> AuthoredRun raise @rle.RleError {
  let sliced = @rle.Sliceable::slice(self.text, start~, end~)
  { author: self.author, text: sliced, }
}

///|
fn authored(author : String, text : String) -> AuthoredRun {
  { author, text, }
}

///|
fn print_authored(run : AuthoredRun?) -> Unit {
  match run {
    Some(run) => println("Some({author: \{run.author}, text: \{run.text}})")
    None => println("None")
  }
}

///|
fn main raise {
  println("=== Same-Author Merge ===")
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::Rle()
  rle.append(authored("alice", "Hello"))
  rle.append(authored("alice", ", world"))
  rle.length() |> println //=> 1  (merged)
  print_authored(rle.get(0)) //=> Some({author: "alice", text: "Hello, world"})

  println("\n=== Different-Author Separation ===")
  let rle2 : @rle.Rle[AuthoredRun] = @rle.Rle::Rle()
  rle2.append(authored("alice", "Hello"))
  rle2.append(authored("bob", " world"))
  rle2.length() |> println //=> 2  (kept separate)
  print_authored(rle2.get(0)) //=> Some({author: "alice", text: "Hello"})
  print_authored(rle2.get(1)) //=> Some({author: "bob",   text: " world"})

  println("\n=== Split at Author Boundary ===")
  let (left, right) = rle2.split(5)
  left.length() |> println //=> 1
  right.length() |> println //=> 1
  print_authored(left.get(0)) //=> Some({author: "alice", text: "Hello"})
  print_authored(right.get(0)) //=> Some({author: "bob",   text: " world"})

  println("\n=== Range Across Runs ===")
  // "Hello" (alice, 0-4) + " world" (bob, 5-10)
  // range(3, 8) -> "lo" from alice, " wo" from bob
  rle2
  .range(start=3, end=8)
  .each(slice => {
    let r = slice.to_inner()
    println("\{r.author}: \{r.text}")
  })
  //=> alice: lo
  //=> bob:  wo

  println("\n=== From Array (same-author merges) ===")
  let runs = [
    authored("alice", "foo"),
    authored("alice", "bar"),
    authored("bob", "baz"),
  ]
  let rle3 = @rle.Rle::from_array(runs)
  rle3.length() |> println //=> 2  (alice merged, bob separate)
  print_authored(rle3.get(0)) //=> Some({author: "alice", text: "foobar"})
  print_authored(rle3.get(1)) //=> Some({author: "bob",   text: "baz"})
}
