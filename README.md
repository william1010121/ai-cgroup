<div align="center">

# ai-cgroup

**Hard CPU and RAM limits for AI coding agents on macOS.**

*Stop Claude Code and Codex from freezing your Mac with a runaway build.*

[![macOS](https://img.shields.io/badge/macOS-12%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-arm64-333333?logo=apple&logoColor=white)](https://support.apple.com/en-us/HT211814)
[![OrbStack](https://img.shields.io/badge/powered_by-OrbStack-FF6B35)](https://orbstack.dev)
[![cgroup v2](https://img.shields.io/badge/cgroup-v2-4A90D9?logo=linux&logoColor=white)](https://docs.kernel.org/admin-guide/cgroup-v2.html)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](bin/rbox)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

---

## The problem

You ask an AI agent to "run the tests." It fires off `make -j10`, or a webpack build
balloons to 20GB, and your Mac locks up — beachball, dead trackpad, hard reboot.

On Linux you would reach for **cgroups**. macOS has no cgroups, and `ulimit` cannot
hard-cap memory. There is no native way to constrain a process tree's CPU and RAM.

## The solution

`ai-cgroup` gives you `rbox`, a command prefix that runs anything inside a
**per-project container with real cgroup v2 limits**, backed by OrbStack's
lightweight Linux VM.

```bash
rbox npm run build     # capped at 4 CPU / 6GB — your Mac stays responsive
```

The AI agent itself keeps running natively on macOS. Only the heavy commands get
capped. Installed skills teach **Claude Code** and **Codex CLI** to apply this
automatically, and — just as importantly — to *never* wrap `git` or `gh`.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/william1010121/ai-cgroup/master/install.sh | bash
```

Requires [OrbStack](https://orbstack.dev) (`brew install orbstack`). The installer
checks for it, starts it if needed, and never installs anything behind your back.

It sets up the `rbox` CLI, a global default config, the Claude Code skill, and the
Codex `AGENTS.md` snippet (appended — your existing instructions are preserved and
backed up).

## Use

```bash
cd your-project
rbox init                # create .rbox.toml
rbox npm run build
rbox uv run pytest
```

| Command | Purpose |
| --- | --- |
| `rbox <cmd...>` | Run a command inside this project's capped sandbox |
| `rbox init` | Create `.rbox.toml` |
| `rbox status` | Container state + live CPU/RAM usage |
| `rbox ls` | Every rbox container across all projects |
| `rbox stop` / `rbox rm` | Stop / remove this project's container |
| `rbox build` | Rebuild the sandbox image |
| `rbox setup` | Re-run this project's `setup` script |

## Per-project limits

Each project gets its own container (`rbox-<name>-<pathhash>`) and its own quota.
One project hitting its memory cap cannot affect another.

```toml
# .rbox.toml
cpus   = 4
memory = "6g"
pids   = 512
image  = "rbox:local"
isolate_node_modules = false   # true = faster npm, but not visible to your IDE
```

Resolution: `<project>/.rbox.toml` → `~/.config/rbox/default.toml` → built-in
(4 CPU / 6GB). Edit the file and the container is automatically recreated with the
new caps.

## Custom toolchains (Lean, Rust, Go, ...)

The sandbox runs Linux, so your macOS toolchain cannot be mounted in — Mach-O
binaries fail with `Exec format error`. Instead, declare a `setup` script and a
cache volume, and `rbox` installs the Linux build inside the container on first
use:

```toml
# .rbox.toml — Lean 4
volumes = ["elan:/root/.elan"]
env     = ["ELAN_HOME=/root/.elan",
           "PATH=/root/.elan/bin:/usr/local/bin:/usr/bin:/bin"]
setup   = "curl -sSfL https://elan.lean-lang.org/elan-init.sh | sh -s -- -y --default-toolchain leanprover/lean4:v4.32.1"
```

```bash
rbox lake build     # first run installs Lean, later runs start in <1s
```

The toolchain lives in a named volume, so it survives `rbox rm` and is not
re-downloaded. `setup` runs once per container; `rbox setup` forces a re-run.

Ready-made recipes for **Lean**, **Rust**, and **Go** are in
[`examples/`](examples/) — copy one to your project as `.rbox.toml`.

## What must never go through rbox

`git` · `gh` · `ssh` · `docker` · `orb` · `security` · `brew`

These rely on the macOS Keychain, the launchd SSH agent, or host-only paths, and
will fail inside a container. The bundled agent skills encode this distinction, so
your AI knows to sandbox `npm test` but run `git commit` natively.

---

## Verified behaviour

Measured on macOS 26.3, Apple Silicon, 10 CPU / 24GB:

| Guarantee | Result |
| --- | --- |
| **CPU cap** | 8 busy loops under `cpus=4` → pinned at **399%**, not 1000% |
| **RAM cap** | 8GB allocation under `memory=6g` → OOM-killed, **exit 137** |
| **Fork bomb** | Contained by `pids-limit`; host survives |
| **Isolation** | Project A OOM-killed while project B ran untouched |
| **Write-back** | Files created in the sandbox appear on the host owned by you |
| **Real workflow** | `npm install` + `tsc` build completed; artifacts runnable on host |
| **Custom toolchain** | Lean 4.32.1 installed via `setup`; `lake build` succeeded (8 jobs) |

> [!IMPORTANT]
> Docker's `--memory` alone does **not** hard-cap. In testing, a 400MB write under a
> 256MB limit *succeeded*. `rbox` always pairs it with `--memory-swap` at the same
> value — that pairing is what makes the limit real.

## How it works

```
macOS host                  10 CPU / 24GB
└── OrbStack VM             10 CPU / 12GB   ← Linux kernel; cgroups live here
    ├── rbox-projA          4 CPU / 6GB     ← cgroup v2 enforced
    ├── rbox-projB          2 CPU / 2GB
    └── rbox-projC          4 CPU / 6GB
```

cgroups are a Linux kernel feature, so a Linux kernel is required — that is what the
VM provides. Because the VM has a fixed ceiling, macOS always retains headroom no
matter how badly a sandboxed command misbehaves.

## Limitations

1. The OrbStack VM ceiling (default 10 CPU / 12GB) bounds every container. Raise it
   with `orbctl config set memory_mib <n>` and restart OrbStack.
2. Quotas are per container, so several busy projects can oversubscribe the VM. Use
   `rbox ls` and stop idle ones. They contend inside the VM — macOS stays safe.
3. **Not a security boundary.** It prevents accidents, not malicious escape. The
   container runs as root with network access.
4. The AI's own file reads/writes are unrestricted; only commands run through `rbox`
   are capped. Combine with Claude Code's permission settings for file control.
5. Skills *guide* rather than force, so a command may occasionally slip through
   unsandboxed. This is deliberate — hard interception would break `git`/`gh`, a
   worse failure mode.

## FAQ

**Does this slow down my builds?**
Only by the cap you choose. `docker exec` adds ~60ms; OrbStack's file sharing is
fast (2000 small files read in 0.47s).

**Why not `ulimit` or `sandbox-exec`?**
`ulimit -v` does not reliably bound RSS on macOS and breaks many runtimes.
`sandbox-exec` controls file/network access, not CPU or memory.

**Does it work with Docker Desktop / Colima?**
It only needs a working Docker daemon with cgroup v2, so likely yes — but it is
developed and tested against OrbStack.

**Will it interfere with my AI agent's login?**
No. The agent stays on macOS, so Keychain credentials keep working.

---

<div align="center">

**Keywords** — macOS cgroup · cgroups for macOS · limit CPU and RAM on Mac ·
AI agent sandbox · Claude Code resource limits · Codex CLI sandbox ·
prevent runaway build freezing Mac · docker cpu memory limit macOS ·
per-project resource quota · OrbStack cgroup v2 · AI coding agent guardrails

MIT © [william1010121](https://github.com/william1010121)

</div>
