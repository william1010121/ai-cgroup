# Restrict-AI — `rbox`

A cgroup-style resource limiter for AI coding agents (Claude Code / Codex) on macOS.

macOS has no cgroups, and `ulimit` cannot hard-cap RAM. So when an AI agent kicks
off a runaway build or test, it can freeze the whole machine. `rbox` runs those
commands inside a **per-project** OrbStack container with **hard CPU/RAM caps**
backed by real cgroup v2.

The AI itself stays on macOS — only the heavy commands get sandboxed.

## Install

```bash
./install.sh     # CLI + global config + Claude/Codex skills
rbox build       # build the sandbox image (first time only)
```

Requires [OrbStack](https://orbstack.dev). Ensure `~/.local/bin` is on your `PATH`.

## Use

```bash
cd your-project
rbox init                # create .rbox.toml
rbox npm run build
rbox uv run pytest
```

| Command | Purpose |
|---|---|
| `rbox <cmd...>` | run inside this project's sandbox |
| `rbox init` | create `.rbox.toml` |
| `rbox status` | container state + live CPU/RAM usage |
| `rbox ls` | all rbox containers across every project |
| `rbox stop` / `rbox rm` | stop / remove this project's container |
| `rbox build` | (re)build the image |

## Per-project isolation

Every project gets its own container (`rbox-<name>-<pathhash>`) and its own quota.
One project blowing its memory cap does not affect another.

`.rbox.toml`:

```toml
cpus   = 4
memory = "6g"
pids   = 512
image  = "rbox:local"
isolate_node_modules = false
```

Resolution order: `<project>/.rbox.toml` → `~/.config/rbox/default.toml` → built-in
(4 cpus / 6g). Editing the file automatically recreates the container with the new caps.

## What must NOT go through rbox

`git`, `gh`, `ssh`, `docker`, `orb`, `security`, `brew` — these depend on the macOS
Keychain, the launchd SSH agent, or host-only paths, and will fail in the container.
The installed skills teach both Claude and Codex this distinction.

## Verified behaviour

Measured on macOS 26.3 / Apple Silicon, 10 cpu / 24GB:

| Guarantee | Result |
|---|---|
| CPU cap | 8 busy loops under `cpus=4` → pinned at **399%**, not 1000% |
| RAM cap | 8GB allocation under `memory=6g` → OOM-killed, **exit 137** |
| Fork bomb | contained by `pids-limit`, host survives |
| Isolation | project A OOM-killed while project B kept running untouched |
| Write-back | files created in the sandbox land on the host owned by you |

**Note on `--memory`:** Docker's `--memory` alone does *not* hard-cap — a 400MB write
under a 256MB limit succeeded in testing. `rbox` always pairs it with
`--memory-swap` set to the same value, which is what makes the limit real.

## Limitations

1. OrbStack VM ceiling is **10 cpu / 12GB**; per-container caps cannot exceed it.
   Raise with `orbctl config set memory_mib <n>` then restart OrbStack.
2. Quotas are per container, so several busy projects can oversubscribe the VM.
   Use `rbox ls` and `rbox stop` idle ones.
3. **Not a security boundary** — it prevents accidents, not malicious escape.
   The container runs as root and has network access.
4. The AI's own file reads/writes are unrestricted; only commands run through
   `rbox` are capped. Pair with Claude Code's permission settings for file control.
5. The skills *guide* the AI rather than force it, so a command may occasionally
   slip through unsandboxed. This is deliberate: hard interception would break
   `git`/`gh`, which is the worse failure.
