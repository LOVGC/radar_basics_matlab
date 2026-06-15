# Deep Learning for Clutter-Map Failure Modes

Date: 2026-06-15

Status: research idea / simulation-first proposal

## One-Sentence Idea

Learn a time- and context-conditioned radar clutter background model from historical range-Doppler data, then detect deviations from that learned background with calibrated false-alarm control.

The core thesis is:

```text
clutter map works when history is a good model of now
```

Deep learning may help when this assumption is only partly true. The goal is not to replace CFAR with a black-box classifier. The goal is to learn a richer model of:

```text
history -> current background distribution
```

and then evaluate detections at fixed empirical `Pfa`.

## Motivation From Demos 22-24

The recent clutter demos show a progression of increasingly realistic background problems.

Demo 22 showed that a simple two-pulse MTI notch works well for exact zero-Doppler clutter but leaks residual detections when clutter has Doppler spread. The same low-Doppler region can contain clutter residuals and slow targets.

Demo 23 showed a simple engineering response:

```text
if |velocity| <= 5 m/s, do not report the detection
```

This Doppler clutter mask removed many low-Doppler clutter reports, but it also removed a true `2 m/s` target that raw CFAR had detected.

Demo 24 showed a first clutter-map alternative. It estimated a historical per-cell background:

```text
clutterMap[range, Doppler] = mean historical RD power at that cell
```

and detected current-frame surprise:

```text
surprise = current RD power / learned clutter map
```

That method recovered a new `2 m/s` slow target that the fixed Doppler mask suppressed. However, the demo also exposed classical clutter-map assumptions: the background must be stable, the map must stay registered, and targets must not be learned into the background.

## Why Classical Clutter Maps Fail

Classical clutter maps are useful, but they can fail when historical background is not a reliable model for the current frame.

Important failure modes:

- **Nonstationary clutter**: weather, sea state, foliage, traffic, or moving ground clutter change faster than the map update.
- **Doppler-spread clutter**: clutter energy is not confined to one fixed velocity bin or one fixed notch shape.
- **Target contamination**: persistent or slow targets appear in the history and get absorbed into the clutter map.
- **Registration error**: platform motion, attitude error, timing drift, or map projection error makes the same RD cell correspond to a different physical patch.
- **Abrupt scene change**: new buildings, terrain occlusion, rain cells, or moving clutter edges make old statistics stale.
- **Multimodal background**: a cell has multiple normal states, so a single mean or variance is not enough.
- **Calibration drift**: thresholds based on old statistics no longer maintain empirical `Pfa`.

These are exactly the places where a learned temporal/contextual model may be useful.

## Research Hypothesis

A deep model trained on historical radar background sequences can learn clutter dynamics that are richer than a static per-cell mean map.

The model should help when:

```text
current background is predictable from recent history and context,
but not well represented by a fixed historical mean.
```

Expected benefit:

```text
At the same empirical Pfa, improve Pd for weak or slow targets
near Doppler-spread, drifting, or structured clutter.
```

Expected risk:

```text
If the model is miscalibrated or trained on contaminated history,
it may produce unsafe false-alarm behavior or absorb real targets.
```

## Candidate Deep Learning Approaches

### 1. Temporal Background Prediction

Input:

```text
RD_history[range, Doppler, time]
```

Output:

```text
predicted_background_power[range, Doppler]
uncertainty[range, Doppler]
```

Candidate models:

- temporal CNN over recent RD maps
- ConvLSTM for slow clutter evolution
- small transformer over compressed RD features

Detection score:

```text
score = current_power - predicted_background
```

or:

```text
score = current_power / predicted_background
```

### 2. U-Net Style Background Map Refinement

Start with a classical clutter map, then learn a correction:

```text
learned_background = clutter_map + neural_residual(history, context)
```

This keeps the model tied to an interpretable baseline and reduces the risk of a fully black-box detector.

### 3. Autoencoder / VAE Anomaly Detection

Train on target-absent background RD maps:

```text
model learns normal clutter structure
```

At test time:

```text
large reconstruction error -> possible target or abnormal clutter
```

Risk: reconstruction error is not automatically calibrated as `Pfa`.

### 4. Distributional Forecasting Model

Instead of predicting only mean background power, predict a distribution:

```text
p(background_power[cell] | RD_history, context)
```

Useful outputs:

- mean background
- variance or uncertainty
- high quantile background threshold
- tail probability of current observation

This is closer to radar detection because it can support threshold calibration.

### 5. Hybrid Learned Residual Detector

Use classical processing first:

```text
MTI -> Doppler FFT -> CFAR / clutter map
```

Then let a neural model estimate where classical assumptions are unreliable:

```text
residual_risk_map
calibration_correction
context-aware threshold multiplier
```

This is probably the safest first research direction because it treats deep learning as an adaptive background-modeling layer, not as the whole radar detector.

## Simulation-First Experiment Plan

Start with 2D RD maps before moving to full RDA tensors.

### Phase 1: Classical Baselines

Generate target-free historical frames:

```text
RD_history[range_bin, Doppler_bin, frame]
```

Background conditions:

- stable Doppler-spread clutter
- slowly drifting clutter ridge
- clutter ridge with changing Doppler width
- intermittent high-clutter patches
- registration shift by a small number of bins

Inject test targets into held-out current frames:

- slow targets inside the low-Doppler clutter band
- fast targets outside the clutter band
- weak targets near clutter ridges
- targets that persist for multiple frames

Compare:

- 2D CA-CFAR
- fixed Doppler clutter mask
- classical mean clutter map
- classical quantile clutter map

### Phase 2: Learned Background Prediction

Train a lightweight model:

```text
input:  last K target-free RD maps
output: next-frame background power map
```

Initial models:

- temporal CNN
- ConvLSTM
- U-Net residual correction over the classical clutter map

Detection:

```text
surprise[cell] = current_power[cell] / (predicted_background[cell] + floor)
detect if calibrated_surprise[cell] > threshold
```

### Phase 3: Distribution Shift and Failure Tests

Evaluate on conditions not seen exactly during training:

- clutter ridge shifts in Doppler
- clutter spread increases
- background power changes by range sector
- platform registration error shifts the RD map
- a slow target remains present for many frames

The goal is to see when deep learning improves over a classical clutter map and when it fails in a different way.

### Phase 4: RDA Extension

Move from:

```text
RD[range, Doppler]
```

to:

```text
RDA[range, Doppler, angle]
```

or:

```text
RDA_history[range, Doppler, angle, time]
```

This connects the idea back to the project abstraction:

```text
x[fast time, slow time, array element]
```

where:

- fast time becomes range
- slow time becomes Doppler
- array element becomes angle

## Evaluation Metrics

The central evaluation must be radar-style, not ML accuracy-style.

Primary metrics:

- empirical `Pfa` on target-absent test frames
- `Pd` versus SNR / SCR at fixed empirical `Pfa`
- false alarms per CPI
- `Pd` for slow targets inside the clutter band
- `Pd` near Doppler-spread clutter ridges
- calibration error: design `Pfa` versus empirical `Pfa`
- robustness under clutter drift and registration shift
- target absorption time for persistent targets

Core comparison:

```text
At the same empirical Pfa, does the learned background model improve Pd
relative to classical clutter maps and CFAR baselines?
```

Do not accept results that only report:

```text
accuracy
precision
recall without fixed false-alarm control
visual improvement only
```

## Calibration Requirement

The learned model must output a score that can be thresholded with measurable false-alarm behavior.

Possible calibration strategies:

- hold-out target-absent calibration set
- empirical score quantiles per operating condition
- conformal-style calibration on target-absent frames
- environment-specific threshold tables
- uncertainty-aware thresholding from predicted background distributions

The model is only radar-useful if the final operating point can be stated as:

```text
empirical Pfa = ...
false alarms per CPI = ...
Pd at target SCR = ...
```

## Failure Risks

1. **False-alarm calibration drift**

   The model may look good in one simulated environment but fail to maintain `Pfa` after clutter distribution shift.

2. **Target absorption**

   A persistent slow target can become part of the learned background if update logic is too aggressive.

3. **Registration sensitivity**

   Neural models may learn cell identity too strongly and fail when the RD map shifts.

4. **Simulation overfitting**

   A model may exploit synthetic clutter shortcuts that do not exist in real radar data.

5. **Black-box detector risk**

   A high neural score is not enough. The score must be interpretable enough to calibrate and audit.

6. **Latency and data demand**

   The model may require more history than the radar system can provide during rapid environment changes.

## Minimal Next Demo

Create:

```text
demos/demo_25_learned_clutter_background_forecast.m
```

Minimal goal:

```text
Compare a classical mean clutter map against a simple learned temporal
background predictor on drifting Doppler-spread clutter.
```

First implementation can avoid a heavy neural network:

1. Generate RD history with a clutter ridge whose Doppler center drifts slowly.
2. Train or fit a lightweight temporal predictor from recent frames.
3. Build a current frame with the drifted clutter plus a `2 m/s` slow target.
4. Compare:
   - fixed Doppler mask
   - static mean clutter map
   - temporal background predictor
5. Evaluate at fixed empirical `Pfa`, not only by visual mask quality.

Expected result:

```text
Static clutter map becomes stale under clutter drift.
Temporal model predicts the drift better and gives a cleaner surprise map.
```

Useful failure case:

```text
If the target persists for many frames, the temporal model may start
predicting it as background unless target-exclusion logic is added.
```

## Relationship To Existing Research Idea

This document is a focused extension of:

```text
research_idea/environment_learned_clutter_detection.md
```

That earlier idea frames environment-learned detection broadly. This document narrows the research angle to:

```text
deep learning for classical clutter-map failure modes
```

The strongest research framing is:

```text
Deep temporal clutter-background modeling with calibrated false-alarm control.
```

The contribution should not be:

```text
deep learning replaces CFAR
```

The contribution should be:

```text
learn richer, context-conditioned background distributions while preserving
empirical Pfa control for radar detection.
```
