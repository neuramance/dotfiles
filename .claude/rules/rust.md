---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
---

# Rust

- In a repository with `scripts/agent-verify`, done means it exits 0. Elsewhere run `cargo fmt --check`, `cargo clippy --all-targets` and the tests. Start a new workspace with `git clone ~/code/rust-template <dir>`, then `git remote remove origin` and `git config core.hooksPath .githooks`; replace `crates/ledger` with your crate and run `cargo generate-lockfile` and `cargo fetch --locked`.
- The template's gate also rejects doc comments (give clap help with `#[command(about = "…")]` and `#[arg(help = "…")]`), `println!`, `eprintln!` and discarded results (write with `writeln!`, handle the error, return `ExitCode` from `main`), and `#[cfg]` on anything but `test` and non-negated features.
- The gate runs offline, so run `cargo fetch --locked` after changing dependencies. You can't edit `deny.toml`: if a crate fails its license check, choose another or stop and report. A binary needs an integration test that runs it through `env!("CARGO_BIN_EXE_<name>")`, or mutation testing reports `main` as untested. Give `git push` up to 10 minutes, because the pre-push hook runs mutation testing.
- Model mutually exclusive states as enums carrying data. Parse untrusted input once at the boundary into newtypes with private fields and fallible constructors; interior code takes the parsed types.
- Return `Result` for operational failures and panic only on bugs, via `expect("<which invariant failed>")`. Never discard an error or substitute a default for one.
- Libraries define closed error enums per concern with thiserror; binaries use one application error with context naming the failed step. No catch-all error enum.
- Match your own enums exhaustively, without `_` arms.
- Escalate abstraction only as needed: concrete type, then enum, then generic, then `dyn`. No trait with a single implementation; no macro where a function works.
- Borrow unless the value is stored or consumed. Restructure instead of cloning to satisfy the borrow checker.
- Search the workspace before adding a function, type or dependency. State why a new dependency is needed and confirm the crate exists.
- Fix a complexity failure by flattening first (`let … else`, `?`, guard clauses, branching pushed up to the caller), then deleting, then extracting along a named seam.
- Unit tests live in a sibling `tests.rs` behind `#[cfg(test)] mod tests;`; integration tests share one `tests/it/main.rs`. Every new test must fail against a real fault; show the failing run.
- Never edit lint configuration, `.lints-baseline`, gate scripts, snapshots or proptest regressions to get green. Stop and report the failure instead.
