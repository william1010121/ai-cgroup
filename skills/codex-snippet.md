
## Resource Sandbox (rbox)

macOS has no cgroups, so a runaway build can freeze the machine. `rbox` runs a
command inside a per-project OrbStack container with hard CPU/RAM caps.

**Use `rbox <cmd>` for** builds, tests, installs, compiles: `npm`/`pnpm`/`yarn`/
`bun` install|build|test, `uv run`, `pytest`, `python`, `cargo`, `make`,
`go build`, `tsc`, `webpack`, `vite` — anything spawning parallel jobs or
allocating large memory. Run `rbox init` first if `.rbox.toml` is missing.

**Never wrap** `git`, `gh`, `ssh`, `docker`, `orb`, `security`, `brew` — they
need the macOS Keychain / launchd SSH socket / host paths and will fail in the
container. Skip it for trivial commands (`ls`, `cat`, `grep`, `rg`, `find`).

**exit 137** = OOM-killed at the RAM cap, not a code bug. Don't blindly retry;
suggest raising `memory` in the project's `.rbox.toml`.
**"Docker daemon not reachable"** = OrbStack stopped; run `orb start`.

Manage with `rbox status` (this project), `rbox ls` (all projects), `rbox stop`.
