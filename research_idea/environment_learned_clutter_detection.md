# Environment-Learned Clutter Detection

Date: 2026-06-12

Status: research idea / simulation-first proposal

## One-Sentence Idea

Learn the local radar background / clutter distribution from historical or online target-absent data, then use the learned environment model to set calibrated detection thresholds that can outperform single-frame local CFAR in nonhomogeneous clutter.

## Motivation

The current CFAR demos show a key limitation:

```text
CA-CFAR assumes local training cells represent the CUT background.
```

This works well in homogeneous noise, but it can fail when:

- clutter changes sharply near the CUT
- training cells contain strong clutter, target sidelobes, or other targets
- background statistics vary by range, Doppler, angle, scan direction, or time
- a target lies near a clutter edge

Demo 18 showed this failure mode directly. A target near a 20 dB clutter step was missed because one side of the CA-CFAR training window was contaminated by high clutter, raising the threshold above the target statistic.

The research question is whether a detector can do better by using more information than the current frame's local training window.

## Core Research Question

Can a learned environment-aware background model improve `Pd` at fixed empirical `Pfa` compared with CA/GO/SO/OS-CFAR in heterogeneous clutter?

More specifically:

```text
Given historical or online target-absent radar frames,
can we learn p(background statistic | range, Doppler, angle, context)
and set calibrated thresholds from that distribution?
```

## Key Hypothesis

For structured or slowly varying clutter, a learned model can provide a better estimate of the CUT-specific background distribution than a single local CFAR window.

Expected benefit:

```text
same empirical Pfa, higher Pd near clutter edges or structured clutter
```

Expected risk:

```text
if the learned model is stale, contaminated, or miscalibrated,
Pfa can drift and the detector can become unsafe for downstream tracking
```

## Relation To Existing Radar Ideas

This idea is not completely new, but there is room for useful experiments and variants.

Related directions:

- **Clutter-map CFAR**: uses previous scans of the same spatial/radar cell to estimate clutter instead of relying only on neighboring cells in the current scan.
- **Knowledge-aided radar / knowledge-aided STAP**: uses prior environment knowledge, maps, geometry, or previously estimated clutter covariance to improve adaptive processing.
- **Adaptive detection in heterogeneous clutter**: explicitly models nonhomogeneous clutter, often through covariance or power heterogeneity.
- **Learning-based / CFAR-constrained detectors**: use ML-style score functions while trying to preserve a constant false alarm rate.

This project's version should focus on:

```text
learned clutter/background model + calibrated false-alarm control
```

The calibration requirement is crucial. A high-scoring ML detector is not enough unless its operating threshold can be tied back to empirical `Pfa`.

## Proposed Detector Family

### 1. Clutter-Map Quantile Detector

For each detection cell, learn a target-absent background quantile from historical frames:

```text
threshold[cell] = empirical_quantile(background_power[cell], 1 - Pfa)
```

Detection rule:

```text
z[cell] > threshold[cell]
```

This is the simplest learned baseline.

Advantages:

- easy to implement
- interpretable
- directly connected to empirical `Pfa`
- strong baseline against CA-CFAR in spatially varying clutter

Risks:

- needs enough target-absent samples per cell
- slow adaptation to changing clutter
- persistent targets may be learned as clutter

### 2. Online Clutter-Map Detector

Update background statistics over time:

```text
background_estimate_t[cell]
    = (1 - beta) * background_estimate_{t-1}[cell]
      + beta * current_statistic_t[cell]
```

Use a robust update:

- freeze updates when a cell is detected
- use median / quantile / trimmed mean instead of mean
- decay old samples
- track uncertainty or sample count per cell

Advantages:

- adapts to slow environmental changes
- closer to deployed radar behavior

Risks:

- target leakage into the clutter map
- adaptation lag
- hard-to-calibrate `Pfa` if updates are not carefully controlled

### 3. Context-Conditioned Background Model

Learn:

```text
background_statistic ~ f(range, Doppler, angle, time, platform_state, environment_context)
```

Possible lightweight models:

- per-cell quantile table
- range/Doppler/angle smoothed quantile maps
- Gaussian / Gamma / K-distribution parameter maps
- gradient-boosted quantile regression
- small CNN over RD/RA/RDA background maps
- normalizing flow or VAE for target-absent background modeling

Detection can use a calibrated tail probability:

```text
score[cell] = P_model(Z >= observed_statistic[cell] | context)
detect if score[cell] < Pfa
```

## Minimal Simulation Plan

Start with 1D range-statistic simulations before moving to RD maps.

### Phase 1: 1D Clutter-Map Toy Model

Generate many target-absent frames:

```text
rangePower[range_bin, frame]
```

Background types:

- homogeneous exponential noise
- fixed clutter step
- slowly moving clutter edge
- cell-dependent clutter power map
- sparse strong clutter scatterers

Then inject targets into held-out test frames:

```text
rangePower[target_bin] += target_power
```

Compare:

- CA-CFAR
- GO-CFAR
- SO-CFAR
- OS-CFAR
- offline learned quantile map
- online learned clutter map

### Phase 2: 2D Range-Doppler Clutter

Generate:

```text
rdPower[range_bin, doppler_bin, frame]
```

Background types:

- zero-Doppler clutter ridge
- range-dependent clutter power
- clutter edge in range
- clutter ridge with Doppler spread
- time-varying clutter map

Inject targets at different:

- range offsets from clutter edge
- Doppler offsets from clutter ridge
- SNR / SCR values

Compare 2D CFAR variants and learned clutter models.

### Phase 3: Full RDA Tensor

Eventually move to:

```text
x[fast time, slow time, array element]
-> range-Doppler-angle statistic cube
```

Learn background distribution over:

```text
range, Doppler, angle, time/context
```

This connects the idea back to the repository's core abstraction:

```text
fast time -> range
slow time -> Doppler
array element -> angle
```

## Evaluation Metrics

The detector should be evaluated with ROC-style thinking, not a single accuracy number.

Metrics:

- empirical `Pfa` from target-absent test frames
- `Pd` versus SNR / SCR at fixed empirical `Pfa`
- false alarms per CPI
- detection probability near clutter edge
- detection probability near clutter ridge
- sensitivity to environment drift
- calibration error: design `Pfa` versus empirical `Pfa`
- adaptation latency for online methods
- robustness to target contamination in training data

Important comparison:

```text
At the same empirical Pfa, does the learned detector improve Pd?
```

Do not compare detectors at uncontrolled thresholds.

## First Concrete Experiment

Use a 1D version of Demo 18.

Training data:

```text
N_train target-absent frames
fixed clutter edge at bin 270
low/high clutter powers = 1 / 100
```

Test data:

```text
target injected before clutter edge
target bin = 262
target SNR/SCR sweep
```

Baselines:

```text
CA-CFAR
GO-CFAR
SO-CFAR
OS-CFAR
learned per-bin quantile threshold
```

Expected result:

```text
CA-CFAR misses weak targets near the edge because high-clutter training cells raise threshold.
Learned per-bin threshold should use the low-clutter distribution at bin 262 and recover Pd at controlled Pfa.
```

Potential failure:

```text
If the clutter edge moves between training and test,
the learned per-bin threshold may become miscalibrated.
```

That failure is useful. It motivates online adaptation or context-conditioned models.

## Research Risks

1. **False-alarm calibration drift**

   A learned model may look good on training environments but fail to maintain empirical `Pfa` under distribution shift.

2. **Target contamination**

   If online learning updates on frames containing targets, persistent or slow targets can be absorbed into the clutter model.

3. **Simulation gap**

   A detector that works on simple synthetic clutter may not generalize to real sea/ground clutter.

4. **Overfitting to cell identity**

   A per-cell map can perform well in a fixed scene but fail when platform geometry, aspect, or environment changes.

5. **Latency**

   Historical learning needs enough target-absent samples; online learning needs time to adapt.

## Possible Novel Angle

A strong research framing would be:

```text
Environment-learned radar detection with calibrated false-alarm control.
```

The key contribution should not simply be "use ML instead of CFAR." A better contribution is:

```text
learn richer clutter/background distributions while preserving measurable empirical Pfa.
```

Potential technical angles:

- learned quantile thresholds with empirical calibration
- conformal-style threshold calibration for radar detection scores
- online clutter maps with target-exclusion update rules
- hybrid detector: local CFAR + learned clutter prior
- uncertainty-aware learned clutter maps
- evaluation under controlled clutter distribution shift

## Milestones

### Milestone 1: Offline 1D Learned Quantile Map

- Generate target-absent training frames.
- Learn per-bin quantile thresholds.
- Test on held-out frames with injected targets.
- Compare against CA/GO/SO/OS-CFAR.

Success criterion:

```text
At fixed empirical Pfa, learned quantile map improves Pd near clutter edge.
```

### Milestone 2: Online Clutter Map

- Replace offline quantiles with recursive updates.
- Add slow clutter drift.
- Test update freezing around detections.

Success criterion:

```text
Online detector tracks slow background drift without absorbing targets too quickly.
```

### Milestone 3: 2D RD Clutter Map

- Move from 1D range profile to 2D RD map.
- Add zero-Doppler clutter ridge and range-varying clutter.
- Compare against 2D CA-CFAR and OS-CFAR.

Success criterion:

```text
Improved Pd near clutter ridge at fixed false alarms per CPI.
```

### Milestone 4: RDA / Array Extension

- Add angle dimension and structured clutter by angle sector.
- Compare learned background thresholds in RD versus RDA.

Success criterion:

```text
Learned RDA background model reduces false candidates while preserving weak target detection in cluttered sectors.
```

## Suggested Next Demo

Create:

```text
demos/demo_19_learned_clutter_map_cfar.m
```

Demo goal:

```text
Show CA-CFAR versus an offline learned per-bin quantile threshold
on the same 1D clutter-edge target scenario.
```

Expected output:

1. target-absent training clutter map / learned threshold
2. test frame with injected target near clutter edge
3. CA threshold versus learned threshold
4. empirical Pfa/Pd summary over Monte Carlo trials

## Reference Pointers

- Clutter-map CFAR uses prior scans / recursive maps to estimate clutter per radar cell rather than relying only on the current local window: <https://www.mdpi.com/2076-3417/14/7/2967>
- A scan-by-scan averaging ship-detection paper discusses clutter-map CFAR as a way to handle nonhomogeneous detection backgrounds: <https://www.hsu-hh.de/ant/wp-content/uploads/sites/699/2017/10/Hinz-Holters-Z%C3%B6lzer-2012-Scan-by-scan-averaging-and-adjacent-detection-merging-to-improve-ship-detection-in-HFSWR.pdf>
- Knowledge-aided STAP and related work use prior/environmental knowledge to improve clutter/interference covariance estimation: <https://arrc.ou.edu/~goodman/pubs/RadarCon_04_STAP_training_through_KA_modeling.pdf>
- Adaptive radar detection in heterogeneous clutter explicitly studies detection under nonhomogeneous clutter assumptions: <https://arxiv.org/abs/2108.08011>
- CFAR-constrained learning explores ML detectors while preserving constant false-alarm behavior: <https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4590633>
