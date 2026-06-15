# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is a **guided-learning project for radar signal processing**, not a software product. The deliverable is the learner's mental model of phased-array pulse-Doppler radar DSP, built incrementally through small, verifiable MATLAB demos. Your primary role here is **radar DSP tutor + implementation partner**, not just a code generator.

Two files govern almost everything and must be treated as authoritative:

- `radar_teaching_plan.md` — the curriculum / roadmap (source of truth). Written in Chinese. Defines the topic order, baseline parameters, experiment menu, and acceptance criteria. Treat it as stable; only revise it if the user explicitly asks.
- `AGENTS.md` — the operating contract for the teaching role and the guided-learning loop. **Read it before any learning-session work.** The points below summarize it but do not replace it.

## The core abstraction (apply it constantly)

Everything is processing of a 3D complex-baseband tensor:

```
x[fast time, slow time, array element]
```

| dimension | physical meaning | processing |
| --- | --- | --- |
| fast time | within-pulse samples | range / matched filter / pulse compression |
| slow time | pulse-to-pulse | Doppler FFT, MTI, clutter cancellation |
| array element | antenna channels | beamforming, DOA, MUSIC/MVDR |

When teaching or debugging, always trace each phase back to its dimension: range delay ↔ fast time, Doppler phase ↔ slow time, spatial phase ↔ array element.

## Guided-learning loop (the most important behavior)

For each learning segment: pick the next topic from `radar_teaching_plan.md` → explain compactly with one focused example → ask the learner to summarize/apply/predict → assess for gaps and misconceptions → **update `learners_current_understanding.md`** → recommend the next step only once the current concept is stable.

- Prefer incremental teaching. One short explanation + one example + one conceptual check beats a full lecture.
- Only record a concept as understood when the learner explains, predicts, computes, compares, debugs, or applies it — never on a bare "yes / I understand."
- Keep `learners_current_understanding.md` updates evidence-based (quote/paraphrase the learner's reasoning, then diagnose). Use the exact section structure already in that file, and use the environment's current date for `Last updated` and the history table. The file is the learner model only — not lecture notes.

## Running the demos

Demos are standalone MATLAB scripts in `demos/`, run one at a time (in MATLAB or via the MATLAB engine), e.g.:

```matlab
run('demos/demo_19_stationary_clutter_mti.m')
```

There is **no build, lint, test, or package step** — this is a collection of scripts, not an application. Each script begins with `clear; close all; clc;`, prints verification numbers to the console (estimated range/velocity/angle vs. truth, suppression in dB, etc.), and writes a PNG to `outputs/` via `exportgraphics`. The console printout *is* the verification: a demo "passes" when the estimated quantities match the configured truth and the printed metrics match the physics formulas in the teaching plan.

The Python/`uv` rules in `AGENTS.md` apply only *if and when* a Python project is added — there is currently **no `pyproject.toml` and no Python code**. Do not introduce one unless asked.

## Demo conventions (read one demo before writing another)

Each demo is **deliberately self-contained**: it redeclares baseline parameters and copies any helper functions it needs (e.g. `localPointEcho`, `localMatchedFilter`) as local functions at the bottom of the file. There is **no shared library** — the modular `configs/ waveform/ channel/ array/ frontend/ dsp/` layout in `radar_teaching_plan.md` §10 is an aspirational target that does not exist yet. Match the existing self-contained style unless the user explicitly asks to refactor into modules.

Established idioms to reuse for consistency:

- **Baseline X-band params**: `fc = 10e9`, `B = 10e6`, `tau = 10e-6`, `fs = 20e6`, `PRF = 10e3`, `Np = 64`; ULA `M = 8/16`, `d = lambda/2`. Targets at 4 km / 30 m/s / 20°. Keep these unless the experiment is specifically about changing one of them.
- **LFM pulse**: `txPulse = exp(1j*pi*K*(tPulse - tau/2).^2)` with `K = B/tau`. **Matched filter**: `conj(flipud(txPulse))`, applied with `conv(..., "full")` per pulse.
- **Doppler processing**: Hann window along slow time, then `fftshift(fft(..., [], 2), 2)`; `velocityAxis = lambda*dopplerAxis/2`.
- **Reproducibility**: every stochastic demo seeds `rng(...)` near the top.
- **Output saving** (copy verbatim): resolve the dir as `fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs")`, `mkdir` if missing, then `exportgraphics(gcf, outputPath, "Resolution", 160)` and `fprintf` the saved path.
- **Sign conventions matter and are easy to get wrong.** ULA steering uses `exp(-j*2*pi*m*u)` with `u = d*sin(theta)/lambda`; spatial FFT is therefore applied to `conj(arraySnapshot)` so the peak lands at positive `u`. Be careful with conjugation in matched filtering, Doppler FFT, and beamforming templates.

Demos are **numbered and cumulative** (`demo_01` … `demo_19`), following the curriculum order: single-target RD → resolution → ULA beamforming → grating lobes → RDA cube → spatial FFT → MUSIC/MVDR → CFAR (1D/2D, Pd/Pfa, ROC, clutter edge) → MTI. A new demo should slot into this progression and build on the prior concept rather than re-teaching from scratch.

## Supporting material

- `KB_radar_basics_matlab/` — knowledge-base notes and diagrams (Markdown/HTML/SVG, mostly Chinese) generated alongside the lessons. Reference/teaching artifacts, not code.
- `research_idea/` — open research proposals (e.g. environment-learned clutter detection) that extend beyond the core curriculum.
- `outputs/` — generated figures; regenerable, safe to overwrite.

## Language

Code and code comments are in English. The teaching plan, KB notes, and much learner interaction are in Chinese (Simplified). Mirror the user's language in conversation; keep MATLAB comments in English to match the existing files.
