# Rust

These rules are requirements for Rust work, not preferences: apply "least code" only among designs that meet them. Meet each rule's intent. Code that passes the gate but defeats a rule's purpose, such as matching `Ok(()) | Err(_)` to drop an error, is a violation. If a rule can't be met, name it and the reason in your report instead of working around it.

## Workflow

- In a repository with `scripts/agent-verify`, done means it exits 0. Elsewhere run `cargo fmt --all --check`, `cargo clippy --workspace --all-targets --all-features -- -D warnings` and `cargo test --workspace --all-features`. Start a new workspace with `git clone ~/code/rust-template <dir>`, then `git remote remove origin` and `git config core.hooksPath .githooks`; replace `crates/ledger` with your crate and run `cargo generate-lockfile` and `cargo fetch --locked`. Add each further crate with `cargo new --lib crates/<name>` (or `--bin`) and then `cargo fetch`: a crate directory holding only a manifest or only source breaks the whole workspace, so never create a crate one file at a time.
- In an existing repository without `scripts/agent-verify`, follow its conventions and change only what the task needs: report a pre-existing bug you find instead of fixing it in the same change. Mutate only your change there (`git diff <base> > /tmp/change.diff`, then `cargo mutants --in-diff /tmp/change.diff`), because a whole package of a large codebase takes hours. Where its lints require docs, such as `#![deny(missing_docs)]`, write each required doc in the style of its neighbours (what the item does, its default, its interactions with related items): docs the build requires are the exemption `~/.claude/CLAUDE.md` makes for required machine-read text, and zero comments still holds for everything else.
- The gate runs offline. Add dependencies with `cargo add`, which updates the lockfile; in a workspace of more than one crate, declare each dependency once in the root `[workspace.dependencies]`, with default features off, and inherit it in members as `name = { workspace = true, features = [...] }`; after editing `Cargo.toml` by hand, run `cargo fetch` without `--locked`. You can't edit `deny.toml`: if a crate fails its license check, choose another or stop and report.
- When tests or logic change, run `cargo mutants --test-tool nextest --all-features --jobs <a quarter of the cores, at least 1> --file '<crate>/src/**/*.rs'` before reporting done; after fixing a missed mutant, rerun with `--iterate`, which retests only the mutants not yet caught. The pre-push hook runs a full pass with cargo-deny and the gate's self-test and can take up to 30 minutes, so give `git push` that long.
- Before reporting done, check the diff against each rule here and in `~/.claude/CLAUDE.md`, one at a time, and report every deviation with its reason. Give review subagents both files as their rubric.
- Measure a performance requirement on the platform CI runs (for a system-tool baseline on Linux CI, GNU coreutils).

## Design

- Model mutually exclusive states as enums carrying data. Parse untrusted input once at the boundary into precise types (newtypes with private fields and fallible constructors, or std types such as `NonZeroUsize`), resolving implied values such as "no flag means all" there too; interior code takes the parsed types. Name each limit the spec sets as a `const` defined once and use it in the checks and messages; tests state the spec's literal value, so a wrong constant fails them. Add each `const` in the same edit as its first use, because the per-edit gate rejects an unused one.
- Return `Result` for operational failures; panic only on bugs, via `expect("<which invariant failed>")`, and never inside a function that returns `Result` or `Option`: propagate the error there, or restructure so the types carry the invariant (match or iterate instead of indexing). The gate's `unwrap_in_result` catches only `expect` on the function's own return type, such as `Result::expect` in a function returning `Result`.
- A library has a closed error enum per concern (thiserror, or a hand-written `Display` when that is simpler), never one crate-wide catch-all. A binary has one error enum whose variants name the failed step and carry the source error, with one `Display`; never `(String, E)`, a `String` or `Box<dyn Error>` as error context.
- In a library's public API, keep struct fields private behind accessors, so they can change without a breaking release; data a caller matches on belongs in enum variants.
- A server's accept loop only accepts and spawns: it never awaits a write, a read or a timeout for one connection, which would stall every other client and shutdown.
- Handle an error where its meaning is known: a broken pipe means success only at the stdout write, not for every error.
- Match your own enums exhaustively, without `_` arms or catch-all bindings such as `other => other` over a `Result` that holds them; a binding arm over a foreign type such as `io::Result` is fine. In a crate others depend on across releases (its `publish` setting is not `false`), mark each new public enum that may grow, errors included, `#[non_exhaustive]`, so adding a variant later is not a breaking change; another crate then matches it with a final `_` arm, the one exception to exhaustive matching. Adding a variant or `#[non_exhaustive]` to an existing exhaustive public enum, changing or removing a public item, or adding a required parameter breaks callers: prefer a compatible design, such as a new item, and when a break is unavoidable, release a new major version. Set the version the change requires, and confirm it with `cargo semver-checks --baseline-rev <previous release tag>` when that tool is installed.
- Implement public signatures exactly as the spec gives them; propose a generalization such as a `Borrow<Q>` lookup in your report instead of making it, and say so if a given signature can't pass the gate.
- When a synchronous binary spreads work over threads or reorders output, put that logic in `src/lib.rs` behind `impl Read`/`impl Write` parameters and keep `main.rs` to argument parsing and wiring, so tests drive ordering and bounds deterministically instead of by timing. This does not apply to an async server: its protocol belongs in a library crate that does no I/O, and its connection handling stays in the binary.
- Escalate abstraction only as needed: concrete type, then enum, then generic, then `dyn`. No trait with a single implementation unless it is a true external boundary; no macro where a function works.
- Borrow unless the value is stored or consumed. Restructure instead of cloning to satisfy the borrow checker. A small crate-internal enum or struct of borrowed data, such as a parsed `Command<'_>` holding `&[u8]` fields, derives `Clone, Copy`, or pedantic `needless_pass_by_value` rejects passing it by value. A public type implements the common traits that hold for it (`Debug`, `Clone`, `PartialEq`, `Eq`, `Hash`, `Default`); add `Copy` to a public type only if it will stay small, because removing it later breaks callers. Mark `#[must_use]` a public function whose ignored result loses data or hides a failure, such as a `try_pop` returning `Option`. A type that holds values the spec calls secret implements `Debug` by hand and prints none of them, for example `f.debug_struct("Store").field("len", &self.entries.len()).finish_non_exhaustive()`.
- Turn off a dependency's default features and enable only the ones the code uses, confirming each by removing it and re-running the tests. When a lint recommends a crate, satisfy it in std instead (for `naive_bytecount`, `lines += u64::from(byte == b'\n')` inside the existing pass) unless a measurement shows the crate is needed.
- Fix a complexity failure by flattening first (`let … else`, `?`, guard clauses), then deleting, then extracting along a named seam.

## Performance

These defaults are pre-approved exceptions to "optimize only with measurement"; apply them on any path that runs once per input item:

- For batch output, lock stdout once, wrap it in `BufWriter`, write with `write!` or `write_all` and return the final `flush()`; each `println!` line is its own write syscall. Output that must stream (interactive tools, pipelines read live, logs) flushes per record. Wrap files in `BufReader`/`BufWriter` for small reads and writes.
- Don't allocate per item: reuse one buffer (`read_until` then `clear`), `write!` into an existing `String`, don't `collect` only to iterate again, and use `with_capacity` when the size is known. When building an owned key is costly, look up with `get_mut` and copy the key only on first insert; otherwise use the entry API.
- Build expensive objects such as a `Regex` once, outside the loop. Stay in `&[u8]` for byte input instead of validating UTF-8.
- Take the top N with `select_nth_unstable(n)` guarded by `n < len` (it panics at `n == len`, so test that case), then sort only those N; use `sort_unstable` when equal elements need no order; replace hidden O(n) work in loops (`Vec::remove(0)`, `Vec::contains`) with `VecDeque`, a set or `swap_remove`.
- In a lock-free structure, keep independently contended atomics, such as a queue's head and tail, on separate cache lines with a `#[repr(align(128))]` wrapper type, because atomics sharing a line make every core that touches one invalidate the other.
- Spread work over threads dynamically: spawn `min(jobs, items)` workers that each claim the next item from a shared `AtomicUsize::fetch_add` counter or a channel, never a static partition such as `step_by(workers)`, so one slow item cannot idle the others. `std::thread::available_parallelism()` can fail; fall back to 1 thread instead of failing the run.

Escalate further only when the spec asks for speed or a profile shows the hotspot, and report the measured gain:

- A hash map on a hot path with trusted keys uses `rustc_hash::FxHashMap` (Apache-2.0 or MIT, no dependencies; about 1.3-1.9x faster than std on short keys, depending on the workload). Keep std's SipHash for attacker-controlled keys. foldhash is Zlib-licensed and fails `deny.toml`.
- Store many small keys in one contiguous arena with indices instead of a `Vec` each; accumulate per thread and merge once instead of locking shared state per item; use an enum or generics instead of `Box<dyn>` in hot loops.
- When the spec sets a performance target, benchmark the release build on realistic input (median of several runs, compared in one session against the previous version), profile before optimizing past the defaults (`samply record`, installed with `cargo install --locked samply`, or `perf` on Linux), and keep the fastest correct version. Never change tests, benchmark inputs or build flags to win.

## Binaries

The template's gate rejects comments, including doc comments (give clap help with `#[command(about = "…")]` and `#[arg(help = "…")]`), `println!`, `eprintln!`, `process::exit` outside `main`, `let _ =` on must-use or drop types, unused `Result`s and `.ok()`, and `#[cfg]` on anything but `test` and non-negated features. `let _x =`, `drop(result)`, `.is_ok()` and `unwrap_or_default()` pass the gate but break the Design rules. This shape, from a line-counting CLI, passes the gate and mutation testing:

```rust
#[derive(Debug)]
enum Failure {
    ReadStdin(io::Error),
    ReadFile(PathBuf, io::Error),
    WriteStdout(io::Error),
}

impl fmt::Display for Failure {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ReadStdin(err) => write!(f, "stdin: {err}"),
            Self::ReadFile(path, err) => write!(f, "{}: {err}", path.display()),
            Self::WriteStdout(err) => write!(f, "stdout: {err}"),
        }
    }
}

impl std::error::Error for Failure {}

fn main() -> io::Result<ExitCode> {
    let Err(failure) = run(&Cli::parse()) else {
        return Ok(ExitCode::SUCCESS);
    };
    writeln!(io::stderr(), "rust-test: {failure}")?;
    Ok(ExitCode::FAILURE)
}

fn run(cli: &Cli) -> Result<(), Failure> {
    let mut counts = HashMap::new();
    if cli.files.is_empty() {
        count(io::stdin().lock(), &mut counts).map_err(Failure::ReadStdin)?;
    }
    for path in &cli.files {
        File::open(path)
            .and_then(|file| count(BufReader::new(file), &mut counts))
            .map_err(|err| Failure::ReadFile(path.clone(), err))?;
    }
    match print(&rank(counts, cli.top)) {
        Err(err) if err.kind() == io::ErrorKind::BrokenPipe => Ok(()),
        written => written.map_err(Failure::WriteStdout),
    }
}
```

`main` returns `io::Result<ExitCode>` so a failed diagnostic write propagates; `print` writes through `BufWriter::new(io::stdout().lock())` and returns its final `flush()`.

## Tests

- Unit tests sit behind `#[cfg(test)] mod tests;` in the parent, with the file at `src/tests.rs` for the crate root and `src/foo/tests.rs` for `src/foo.rs`; integration tests share `tests/it/`, where `main.rs` declares each sibling module once and siblings reach shared helpers through `crate::` (declaring a file twice fails `duplicate_mod`). Create each module's file before writing the `mod` line that declares it (`mod tests;`, and every sibling in `tests/it/main.rs`), because the per-edit gate compiles the parent at once and an undeclared file passes until then. In tests, assert returned values (`assert_eq!(cache.put(key, value), None)`) instead of discarding them. A binary needs an integration test that runs it through `env!("CARGO_BIN_EXE_<name>")`, or mutation testing reports `main` as untested. A library's own unit tests cover every boundary its spec names through its public API, asserting structured values (`assert_eq!(parse(b"1x"), Err(ParseError::UnexpectedByte { column: 2 }))`), because callers other than the binary rely on it; the binary's integration tests don't count toward them.
- Write tests first against stubs: give each new item its final signature and a body that compiles but returns a wrong value, never `todo!()` or `unimplemented!()`, which the gate rejects, so every edit compiles and each test fails for its own reason. Show each new test failing against a real fault. Assert the whole outcome (exact stdout, stderr and exit code; for a usage error, that stderr names the offending argument), not a prefix. Where the spec leaves text free, such as an error reason, assert the part it fixes and the error's variant, not a copy of the implementation's wording. For `--help`, assert exit 0, empty stderr and the usage line the spec gives; don't copy clap's full output into the test.
- A tool that reads files needs tests for a missing file, a file that opens but fails to read (a directory), a failed stdin read, a failed stdout write and a stdout whose reader has exited (broken pipe).
- Pedantic clippy checks integration tests too: helpers outside `#[test]` functions use `expect`, not `unwrap`, and strings are built with `join` or `write!`, not `format!` inside `collect` or `push_str`.
- Under the template's nextest profile (`terminate-after = 2` at 60 s) a hung test's process group is killed, but nothing bounds `cargo test`, so no test may be able to hang: feed a child's stdin from fixture files, never wait on a child that waits on you, and give every socket connect, read and write in a test a timeout. A test that starts a long-running child, such as a server, kills it and then waits for it when the test ends, panics included, through a guard whose `Drop` does both. Never bind a fixed port in a test: check a default such as the listen address by parsing arguments (`Cli::try_parse_from`) instead of over the network.
- Give every fixture under `CARGO_TARGET_TMPDIR` a name that no other test uses, prefixed with `std::process::id()`: `cargo test` runs tests as threads of one process, and concurrent runs share the directory. The suite must pass under both `cargo test` and nextest, although the gate runs only nextest.
- For a stdout whose reader has exited, drop the reader of `std::io::pipe()` and pass its writer as stdout. For a failed write, run the binary as `sh -c 'ulimit -f 0 && trap "" XFSZ && exec "$0" "$@"'` with stdout redirected to a file, which fails with EFBIG; std treats EBADF on stdout as success, so a closed or read-only descriptor doesn't work.
- cargo-mutants counts a timeout as a failure. A loop that stops when a comparison sees a repeating end-of-input value hangs once the comparison is mutated, so drive read loops by a pattern, `while let 1.. = reader.read_until(b'\n', &mut line)?`, or by an iterator that doesn't allocate per item.
