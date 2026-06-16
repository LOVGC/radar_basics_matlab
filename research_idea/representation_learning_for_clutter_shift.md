# Representation Learning for Clutter Shift

Date: 2026-06-16

Status: research insight / simulation-first note

## Bilingual Summary / 双语摘要

**English.** Classical clutter-map methods estimate a typical background from historical radar range-Doppler maps, then flag cells whose current power is unusually high relative to that background. Demo 25 reframes this as calibrated anomaly detection:

```text
RD_history -> predicted clutter map/distribution -> anomaly score -> calibrated threshold
```

The research insight is that hand-designed clutter-map estimators handle clutter shift only through manual update rules such as window length, mean/median/quantile choice, background floor, and threshold calibration. Representation learning may learn richer temporal clutter dynamics directly from RD history, including Doppler shift, Doppler spread, range-dependent texture, and target-like anomalies.

**中文。** 传统 clutter-map 方法本质上是从历史 range-Doppler 图里估计一个“典型 clutter 背景”，然后看当前 RD map 中哪些 cell 相对这个背景异常强。Demo 25 可以抽象成一个 calibrated anomaly detection 框架：

```text
RD 历史序列 -> 预测 clutter map / clutter distribution -> anomaly score -> 校准后的 threshold
```

核心 insight 是：传统 clutter-map estimator 并没有真正理解 clutter dynamics，而是依赖手工统计规则追踪背景，例如选择 `K`、选择 mean/median/quantile、设置 background floor、再校准 threshold。深度学习的 representation learning 也许可以直接从 RD history 中学到更丰富的 clutter shift / Doppler-spread 动态。

## Motivation From Demo 25 / Demo 25 带来的动机

Demo 25 compared four simple background estimators:

- `static mean`: stable, but stale when clutter drifts.
- `recent mean`: tracks drift quickly, but absorbs persistent slow targets quickly.
- `recent median`: more robust to short target contamination, but fails once the target contaminates a majority-like part of the window.
- `recent q25`: more resistant to high-power target contamination, but changes the target-free score distribution and therefore needs a higher calibrated threshold.

These methods are useful baselines, but their behavior is controlled by hand-designed choices:

```text
KWindow
quantileLevel
backgroundFloor
score formula
pooled/global versus per-cell threshold calibration
target-exclusion or update-gating policy
```

中文理解是：这些传统方法不是没有用，而是它们的“智能”主要来自人工设计的 update rule。为了处理 clutter shift，我们不断调 `K`；为了避免 target absorption，我们调 median / q25；为了控制 false alarm，又要重新校准 threshold。这个过程很像在用很多手工旋钮逼近一个更复杂的 temporal background model。

## Research Hypothesis / 研究假设

**English hypothesis.**

```text
A learned temporal representation of RD history can predict the current
clutter background or clutter distribution better than handcrafted mean,
median, or quantile clutter maps under drifting Doppler-spread clutter,
while preserving calibrated empirical false-alarm control.
```

Expected benefit:

- Better tracking of clutter ridge shift without only relying on a fixed recent window.
- Better separation between normal clutter drift and compact target-like anomalies.
- Better slow-target detection near low-Doppler clutter at the same empirical `Pfa`.
- Less manual tuning of `K`, quantile level, and background update rule.

Main risk:

- A learned model may still absorb persistent targets into the background.
- A learned score may look good visually but fail empirical `Pfa` calibration.
- A model trained on synthetic clutter may overfit simulation shortcuts.

**中文假设。**

```text
如果模型能从一段 RD history 中学习 temporal clutter representation，
它可能比 static mean / recent mean / median / q25 更好地预测当前 clutter，
尤其是在 Doppler-spread clutter 发生 shift 的情况下。
```

但是 radar detector 的底线不能丢：最终不是看 reconstruction 多漂亮，也不是看 ML accuracy，而是看 fixed empirical `Pfa` 下 `Pd` 是否提高。

## Possible Model Routes / 可能的模型路线

1. **Temporal background predictor**

   ```text
   input:  RD_history[range, Doppler, time]
   output: predicted_clutter_power[range, Doppler]
   score:  current_power / predicted_clutter_power
   ```

   Candidate models: temporal CNN, ConvLSTM, lightweight transformer, or U-Net style predictor.

2. **Autoencoder / representation anomaly detector**

   Learn a low-dimensional representation of normal target-free RD maps. The anomaly score may be reconstruction error, latent-space distance, or prediction residual. This is related to standard deep anomaly detection, but the radar version still needs empirical `Pfa` calibration.

3. **Distributional clutter forecasting**

   Predict more than one background map:

   ```text
   p(background_power[cell] | RD_history)
   ```

   Useful outputs include mean, variance, quantile, uncertainty, or tail probability. This is closer to radar detection because the model can support calibrated cell scores.

4. **Hybrid classical-plus-learned detector**

   Use classical clutter maps or CFAR as interpretable baselines, then learn a correction:

   ```text
   learned_background = classical_background + neural_residual(history)
   ```

   This may be safer than a fully black-box detector because the learned model starts from a known radar baseline.

## Evaluation Requirement / 评估要求

This research direction must be evaluated as radar detection, not only as machine learning reconstruction.

Required metrics:

- empirical `Pfa` on target-free test frames
- `Pd` versus SNR / SCR at fixed empirical `Pfa`
- false alarms per CPI
- slow-target `Pd` inside the low-Doppler clutter band
- target absorption time for persistent slow targets
- calibration drift under clutter shift
- robustness to Doppler-spread clutter, registration shifts, and changing clutter width

The central comparison should be:

```text
At the same empirical Pfa, does the learned representation improve Pd
relative to static mean, recent mean, median, q25, Doppler mask, and CFAR baselines?
```

中文版本：

```text
不能只说 neural network 的图更干净。
必须问：在相同 empirical Pfa 下，它是否真的提高了 Pd？
它是否减少 slow target 被吸收的速度？
它是否在 clutter shift 后仍然保持 false alarm calibration？
```

## Minimal Simulation Experiment / 最小仿真实验

Start from the Demo 25 synthetic RD-map setup:

1. Generate target-free RD sequences with a Doppler-spread clutter ridge drifting from `0 m/s` to `3 m/s`.
2. Train or fit a temporal background predictor on target-free RD history.
3. Calibrate the predictor's anomaly score on held-out target-free frames.
4. Inject a `2 m/s` slow target with different persistence lengths.
5. Compare against `static mean`, `recent mean`, `recent median`, and `recent q25`.

Success criterion:

```text
The learned temporal representation improves slow-target Pd at fixed
empirical Pfa and delays target absorption compared with simple recent
mean/median/quantile maps.
```

Useful failure case:

```text
If the target persists for many frames, the learned model may still predict
it as background. That failure motivates target-exclusion logic, uncertainty
modeling, or distribution-aware calibration.
```

## Relationship To Existing Notes / 和已有文档的关系

This note is a focused insight connected to:

```text
research_idea/deep_learning_clutter_map_failure_modes.md
research_idea/environment_learned_clutter_detection.md
```

Those documents describe the broader research program. This note emphasizes the specific conceptual jump from Demo 25:

```text
handcrafted clutter-map update rules
    -> learned temporal clutter representation
    -> calibrated anomaly detection
```

The strongest framing is:

```text
representation learning for clutter shift with calibrated false-alarm control
```

