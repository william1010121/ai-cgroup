---
name: rbox
description: Run heavy or resource-intensive shell commands inside the current project's CPU/RAM-capped sandbox instead of directly on macOS. Use for builds, tests, installs, and compiles - npm/pnpm/yarn/bun install or build, pytest, uv run, cargo, make, go build, tsc, webpack, vite - anything that spawns parallel jobs or allocates large memory. Prevents a runaway process from freezing the Mac.
allowed-tools: Bash
---

# rbox - resource-capped command sandbox

macOS has no cgroups, so a runaway build can freeze the whole machine. `rbox`
runs a command inside a per-project OrbStack container with hard CPU/RAM caps
(cgroup v2). Each project has its own container and its own quota.

## Usage

Prefix the command:

```bash
rbox npm run build
rbox uv run pytest
rbox make -j4
```

If `.rbox.toml` does not exist in the project, run `rbox init` first.

## When to use rbox

Use it for anything that compiles, installs, tests, or bundles:

- `npm` / `pnpm` / `yarn` / `bun` - `install`, `build`, `test`, `ci`
- `uv run`, `uv sync`, `python`, `pytest`
- `cargo`, `make`, `go build`, `tsc`, `webpack`, `vite`, `esbuild`
- any script that fans out parallel work or loads a large dataset

## When NOT to use rbox

**Never wrap these** - they depend on macOS Keychain, the launchd SSH agent, or
host-only paths, and will fail inside the container:

- `git` (credentials in Keychain, `.gitconfig` is a host symlink)
- `gh` (auth in the macOS keyring)
- `ssh` / `scp` (`SSH_AUTH_SOCK` is a launchd socket)
- `docker`, `orb`, `orbctl`, `security`, `brew`, `defaults`

Also skip it for trivial commands - `ls`, `cat`, `grep`, `rg`, `find`, `sed`,
`echo`, `cd`. Running them directly is fine and faster.

## Interpreting failures

- **exit 137** means the command was OOM-killed for exceeding the RAM cap, not
  that the code is buggy. Do not blindly retry. Tell the user, and suggest
  raising `memory` in the project's `.rbox.toml`.
- **"Docker daemon not reachable"** means OrbStack is stopped. Tell the user to
  run `orb start`.

## Custom toolchains

If a command needs a toolchain the image lacks (Lean, Rust, Go, ...), do NOT try
to mount the host's copy — macOS binaries cannot run in the Linux sandbox. Add a
`setup` script plus a cache volume to `.rbox.toml`:

```toml
volumes = ["elan:/root/.elan"]
env     = ["PATH=/root/.elan/bin:/usr/local/bin:/usr/bin:/bin"]
setup   = "curl -sSfL https://elan.lean-lang.org/elan-init.sh | sh -s -- -y"
```

`setup` runs automatically on first use and is cached; `rbox setup` re-runs it.

## Managing sandboxes

```bash
rbox status   # this project's container state + live CPU/RAM usage
rbox ls       # all rbox containers across every project
rbox stop     # stop this project's container to free resources
```

Quotas are per container, so several busy projects can oversubscribe the
OrbStack VM (10 cpu / 12GB total). If things feel slow, `rbox ls` and stop
the idle ones.
