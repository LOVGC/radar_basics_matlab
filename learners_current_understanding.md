# Learner Current Understanding — Compact

> Source: uploaded learner-model markdown, compacted on 2026-06-16.

## 1. Current stage

The current radar-learning path is moving from **clutter / clutter-map modeling** into **jammer and interference scenarios**, especially:

- sidelobe jammer versus mainlobe jammer,
- conventional beamforming versus adaptive beamforming,
- MVDR robustness,
- broadband / tone / narrowband interference effects.

Clutter modeling has been explored enough for now. The next useful step is a focused jammer/interference segment.

---

## 2. Stable core understanding

### 2.1 Radar data-cube mental model

The learner now has a stable mapping:

- **Range / delay** → `fast time`
- **Velocity / Doppler** → `slow time`
- **Angle / spatial phase** → `array element`

The continuous-time received signal, vector form, and sampled data-cube form should be treated as different representations of the same physical array echo, not separate physical models.

Range, Doppler, and angle processing share the same basic abstraction:

> correlate/project the measured data onto a hypothesis template.

Concretely:

- range processing matches against delayed waveform templates,
- Doppler processing matches against slow-time sinusoids,
- angle processing matches against spatial steering vectors.

---

### 2.2 Fourier / aperture view

The learner understands the unified Fourier-like view:

- **Range resolution** comes mainly from waveform bandwidth.
- **Doppler resolution** comes mainly from coherent processing interval / pulse count.
- **Angle resolution** comes mainly from array aperture / element count.

Zero-padding or larger FFT display grids smooth/interpolate the spectrum, but do not create new physical resolution. True resolution improves only when measurement support increases: larger bandwidth, longer CPI, or larger aperture.

Ambiguity is understood as aliasing:

- range ambiguity from delay modulo PRI,
- Doppler ambiguity from slow-time sampling at PRF,
- spatial ambiguity / grating lobes from array spacing beyond the spatial Nyquist condition.

---

### 2.3 Array processing

The learner understands ULA steering vectors, broadside phase, nonzero spatial phase progression, element spacing, aperture, and grating lobes.

Key stable points:

- Broadside ULA target has all-ones steering vector under the normalized convention.
- Larger aperture narrows the mainlobe.
- `d > lambda/2` can create spatial aliasing / grating lobes.
- Spatial FFT and angle scan estimate the same underlying spatial frequency, but FFT bin density is not the same as physical resolution.

MUSIC and MVDR are understood at the framework level:

- MUSIC uses covariance eigendecomposition and separates signal/noise subspaces.
- MVDR uses covariance information to preserve the look direction while suppressing interference directions.
- Both require stronger assumptions than conventional beamforming: good covariance estimation, enough snapshots, calibration, source-count assumptions or tuning.
- Diagonal loading trades adaptivity for robustness: small loading trusts the covariance more; large loading makes MVDR more conventional-like.

---

### 2.4 Detection / CFAR framework

The learner now sees detection as:

> detection-statistic map/cube → thresholding → binary mask → postprocessed detection reports.

CFAR is not tied only to RD maps. It can operate on 1D range profiles, 2D RD / RA / DA maps, or 3D RDA tensors, as long as there is a CUT and surrounding background/training region.

Stable detection ideas:

- CUT statistic can be power, amplitude, log power, beamformed power, likelihood score, learned anomaly score, etc.
- Design `Pfa` sets the threshold rule; empirical `Pfa` must be measured separately.
- `Pd`, `Pfa`, SNR, and operating environment must be interpreted together.
- Lower design `Pfa` raises threshold and usually reduces `Pd` for weak targets.
- Adjacent positive CFAR cells should not automatically be counted as multiple targets.
- Binary mask cells are candidate evidence, not confirmed targets.
- Detection reports need postprocessing: connected components, peak picking, merge/split logic, threshold margin, caveats, and tracker context.
- A detection far above threshold is more reliable than one barely crossing threshold, but threshold validity also depends on local calibration quality.

---

### 2.5 Clutter, MTI, and slow-target tradeoff

Stationary clutter appears near zero Doppler because its slow-time phase is nearly constant.

Two-pulse MTI suppresses zero-Doppler clutter, but it also creates a low-Doppler notch:

- exactly stationary clutter is strongly suppressed,
- fast moving targets are mostly preserved,
- slow targets near zero Doppler can be attenuated or missed.

A key stable insight:

> detectability after MTI depends on the statistic-to-threshold ratio, not absolute target power alone.

A slow target may lose power after MTI but still be detected if the local CFAR threshold also drops enough. Conversely, it may be missed if MTI attenuation pushes the statistic below threshold.

Doppler-spread clutter is harder than exactly stationary clutter because energy leaks away from the exact zero-Doppler bin. A simple zero-Doppler notch or fixed low-Doppler mask can reduce false reports but creates a slow-target blind zone.

---

### 2.6 Clutter maps and anomaly detection

The learner understands clutter maps as temporal background modeling:

> use historical target-free or mostly target-free RD maps to estimate expected background per cell, then compare the current RD map against that background.

Typical score:

```text
surprise_dB = 10 * log10(currentPower / (backgroundMap + floor))
```

This reframes detection as anomaly detection under a target-free background model.

Important tradeoffs:

- Static clutter maps fail when clutter drifts.
- Short recent-history windows track drift faster but absorb persistent slow targets more easily.
- Long windows resist target contamination but adapt slowly.
- Mean updates adapt quickly but are vulnerable to target contamination.
- Median / quantile updates are more robust to high-power target contamination, but quantile choice affects threshold calibration and anomaly direction.
- A lower background quantile can resist high-power target absorption, but may not be robust to low-power shadow/gap anomalies.
- Pooled threshold calibration gives more samples but loses cell-specific background behavior; per-cell calibration is more specific but sample-hungry.

---

## 3. Main remaining gaps

The learner is broadly on track. The remaining gaps are mostly nuance, not conceptual failure.

### 3.1 Signal-processing details

Needs more practice with:

- conjugation and sign conventions in matched filtering, Doppler FFT, and beamforming,
- representation levels: continuous-time signal versus vector versus sampled data cube,
- physical resolution versus FFT interpolation,
- Doppler resolution versus unambiguous velocity,
- ordinary sidelobes versus grating lobes,
- true target peaks versus noise / sidelobe / grating artifacts.

### 3.2 Adaptive array processing

Needs to keep clear:

- snapshots improve covariance estimation quality, not subspace dimension,
- MUSIC requires source count, decorrelation assumptions, calibration, and enough snapshots,
- MVDR look-direction beamforming is different from Capon/MVDR spectral scanning,
- diagonal loading is a robustness control, not just a numerical trick,
- mainlobe jammer is harder than sidelobe jammer because it overlaps the desired look direction.

### 3.3 Detection and CFAR

Needs more practice with:

- CUT / guard / training-cell design in 1D, 2D, and 3D,
- mask-to-report postprocessing,
- when to split or merge one CFAR blob,
- edge effects and incomplete training windows,
- design `Pfa` versus empirical `Pfa`,
- ROC thinking and operating-point selection,
- why CFAR is a statistical detector, not merely a rule-based heuristic.

### 3.4 Clutter and learned background models

Needs to keep explicit:

- real clutter is not literally ideal point scatterers; it can be distributed, correlated, Doppler-spread, nonstationary, and heavy-tailed,
- clutter-map validity depends on stationarity and registration,
- learned detectors still need fixed-`Pfa` evaluation,
- heavy tails can both inflate variance and break Gaussian-tail false-alarm assumptions,
- background modeling can be point-estimate based, uncertainty-aware, or full-distribution/tail-probability based.

---

## 4. Core research abstraction

The most important abstraction from the file is:

> CFAR, clutter maps, temporal background maps, robust quantile maps, and learned anomaly detectors are all variants of the same statistical detection pipeline.

The pipeline is:

```text
target-free / background data
        ↓
estimate or learn H0 background behavior
        ↓
compute detection statistic / anomaly score on current frame
        ↓
calibrate threshold for desired Pfa
        ↓
evaluate Pd, empirical Pfa, false alarms per CPI, and ROC behavior
```

The deep-learning opportunity is not simply “replace CFAR.”

A better framing is:

> Learn a richer model of `history → current target-free background distribution`, then use that model to compute calibrated anomaly scores while preserving empirical false-alarm control.

Possible learned-model levels:

1. **Point-estimate background model**Predict expected clutter/background power per RD cell.
2. **Uncertainty-aware background model**Predict background mean plus variance / uncertainty, so the same current power is more anomalous in historically stable cells than in heavy-tailed cells.
3. **Full target-free distribution model**
   Learn the full `H0` distribution or tail probability per cell, then declare detections by calibrated tail probability.

The key evaluation constraint remains:

```text
Do not evaluate only by accuracy.
Evaluate at fixed empirical Pfa / false alarms per CPI, and report Pd / ROC behavior.
```

---

## 5. Next recommended learning step

Pause deeper clutter-map research for now and return to Week 5 jammer/interference learning.

Recommended sequence:

1. Conventional beamformer with target plus strong sidelobe jammer.
2. MVDR spatial nulling against sidelobe jammer.
3. Diagonal-loading robustness under limited snapshots / steering mismatch.
4. Mainlobe jammer versus sidelobe jammer.
5. Broadband noise jammer versus tone/narrowband jammer.
6. How different jammer types appear in angle spectra, RD maps, and detection statistics.

The next teaching focus should be:

> how interference changes the data cube, how beamformers respond, and why sidelobe interference is easier to suppress than mainlobe interference.
>
