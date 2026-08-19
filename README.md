# gpu-puzzle-campaign

A small, honest toolkit for running a **long, unattended GPU brute-force campaign**
against a Bitcoin "puzzle" address on Windows. It wraps a CUDA solver
([KeyHunt-Cuda](https://github.com/Qalander/KeyHunt-Cuda)) with the operational
layer that raw solvers leave out: a resumable ledger, self-healing auto-restart,
thermal-aware power scheduling, and clean pause/resume so it can share a machine
you actually use.

It does **not** ship a solver and it does **not** improve your odds. Read the
"Honest odds" section before you run anything.

## The thing that started this

Someone noticed a Bitcoin puzzle solver ran *faster on a Mac than on a Windows PC
with a much stronger NVIDIA GPU*, and concluded the Mac was better hardware. It
was not. The solver in question runs in the browser via **WebGPU**, and on Windows
those shaders compile through Direct3D 12 / HLSL, which generates poor code for the
256-bit modular arithmetic these hashes need (WGSL has no add-with-carry). On macOS
the same shaders compile through Metal, which handles it far better. Same card,
different shader backend. "GPU at 100%" only means busy, not fast: a bad kernel
keeps every core occupied while doing very little.

Compile the solver **natively with CUDA** and the browser bottleneck disappears:
on the test machine (RTX 4070 Ti) native was roughly **50 to 1000x** the browser
speed. That is the whole point. This repo is the tooling built around that native
solver so it can run for months without babysitting.

## Why these puzzles are brute-force only

The Bitcoin puzzle addresses that have **never spent** expose only their
`hash160` on-chain, not their public key. That rules out every fast method:
Kangaroo and BSGS solve the elliptic-curve discrete log and **need the public key**;
the secp256k1 endomorphism and point-negation tricks only help when searching the
whole keyspace, not a contiguous sub-range. So an unspent puzzle is
guess-key, derive-address, compare: `O(2^N)`, full stop. Only the puzzles whose
public keys were revealed (the ones that spent) are Kangaroo-able. This toolkit is
for the brute-force case.

## Honest odds (read this)

This is a **negative-expected-value lottery**. For puzzle 71 the key lives in a
`2^70` span. At ~2.5 Gkeys/s, exhausting it is on the order of **15,000 GPU-years**;
a few months of one card buys roughly a **1-in-40,000** chance. Running longer or
on a bigger GPU scales the odds and the electricity bill by the same factor, so the
break-even Bitcoin price stays in the **seven-figures-per-BTC** range regardless.
Run this for the engineering and the curiosity, not for the money. Do not point it
at anything other than the public puzzle addresses.

## Quickstart

1. Build the solver for your GPU. See [BUILD.md](BUILD.md).
2. `copy config.example.ps1 config.ps1` and edit `$Exe` (path to the solver) plus,
   if you like, the target and range.
3. One-off run: `powershell -File run-campaign.ps1` (Ctrl-C to stop).
4. Unattended, self-healing, reboot-safe:
   `powershell -File install-autostart.ps1`
5. Optional thermal cap (elevated): `powershell -File setup-powercap.ps1`.
6. Stop everything: `powershell -File stop-campaign.ps1`.

## How it works

- **run-campaign.ps1** sweeps the configured keyspace upward in `2^ChunkPow`-key
  chunks. After each chunk it appends a row to `ledger.csv` and writes the next
  start offset to `state.txt`. It therefore **never re-scans** and resumes exactly
  after any stop, crash, or reboot. A named mutex keeps it to one instance; a
  chunk that exits non-zero is retried; if the solver's `Found.txt` grows it writes
  `FOUND.flag` and stops.
- **guardian.ps1** relaunches the runner if it ever dies. Between the two, a solver
  crash is retried by the runner and a runner death is fixed by the guardian, with
  no elevation and no scheduled task required.
- **install-autostart.ps1** adds Startup-folder launchers so both come back after a
  reboot.
- **setup-powercap.ps1** (elevated) caps GPU power during work hours and releases it
  after, via two SYSTEM scheduled tasks. On the test card, capping to 240W during
  the day dropped temps well out of the throttle zone at no throughput cost, because
  daytime speed was limited by normal PC use, not power.
- **stop-campaign.ps1** removes the autostart and kills everything, keeping the
  ledger so you can resume later.

To pause for other work, run `stop-campaign.ps1`; to resume, run
`install-autostart.ps1` (or `run-campaign.ps1`). The ledger makes resume exact.

## Configuration

All machine-specific and target settings live in `config.ps1` (gitignored; copy
from `config.example.ps1`): solver path, target address, hex range start/end, chunk
exponent, and the GPU grid. Defaults target Bitcoin puzzle 71 from the upper half of
its range (starting high keeps you off the crowded bottom where most hunters begin).

## Attribution and license

The tooling in this repo is MIT licensed (see [LICENSE](LICENSE)). It is independent
of the solver it calls. **KeyHunt-Cuda is a separate GPLv3 project** by its authors;
this repo does not include or modify its source, it only invokes the compiled binary.
Build it yourself from the upstream project per [BUILD.md](BUILD.md).
