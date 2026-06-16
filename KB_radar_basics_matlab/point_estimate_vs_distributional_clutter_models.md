# Point Estimate Background Model vs Distributional Clutter Model

Date: 2026-06-16

这篇笔记总结 Demo 25 后面出现的两个重要抽象：

1. **point estimate background model**
2. **learned clutter model 的三个 level**

它们的共同目标是把 radar detection 从“看当前 RD map 的局部邻域”推进到：

```text
用历史 RD maps 学习 background / clutter 的正常行为，
再判断当前 RD cell 是否在这个正常行为下显得异常。
```

---

## 1. 从 Demo 25 抽象出的检测框架

Demo 25 可以抽象成一个 anomaly detection pipeline：

```text
RD_history
  -> estimate / predict clutter background
  -> compute anomaly score on current RD map
  -> compare score with calibrated threshold
  -> anomaly / candidate target
```

其中 RD map 是经过前面雷达 DSP 后得到的检测统计图：

```text
x[fast time, slow time, array element]
  -> matched filtering
  -> Doppler FFT
  -> beamforming if needed
  -> RD or RDA power statistic
```

在 Demo 25 里，为了专注研究 background modeling，代码直接合成：

```text
RD_power[range_bin, Doppler_bin, frame]
```

然后比较不同的 clutter-background estimator。

---

## 2. Point Estimate Background Model

### 2.1 定义

所谓 **point estimate background model**，就是模型只输出一个 background power 的点估计：

```text
RD_history -> predicted_background_power[range, Doppler]
```

也就是对每个 cell 只预测一个数：

```text
\hat B(r,d)
```

表示：

```text
我认为 range-Doppler cell (r,d) 在 clutter-only 条件下，
典型背景功率大概是多少。
```

Demo 25 里的方法都属于这一类：

```text
static mean:
    \hat B(r,d) = old K-frame mean

recent mean:
    \hat B(r,d) = recent K-frame mean

recent median:
    \hat B(r,d) = recent K-frame median

recent q25:
    \hat B(r,d) = recent K-frame 25% quantile
```

它们的区别只是：

```text
如何从历史 RD maps 中把一个代表性 background value 算出来。
```

### 2.2 对应的 anomaly score

有了 point estimate background 后，最直接的 anomaly score 是比值：

```text
surprise(r,d)
  = current_power(r,d) / (\hat B(r,d) + floor)
```

用 dB 写就是：

```text
surprise_dB(r,d)
  = 10 log10(current_power(r,d) / (\hat B(r,d) + floor))
```

如果当前 cell 比历史背景强很多：

```text
surprise_dB large -> candidate anomaly / target
```

如果当前 cell 和历史背景差不多：

```text
surprise_dB small -> background-like
```

### 2.3 threshold 从哪里来

threshold 不应该随便手写，例如不能简单说：

```text
surprise_dB > 12 dB means target
```

更 radar-like 的做法是用 target-free calibration data：

```text
target-free RD frames
  -> compute surprise_dB scores
  -> take empirical quantile at 1 - Pfa
  -> threshold
```

例如目标 false alarm rate 是：

```text
Pfa = 1e-3
```

那就可以取 target-free score distribution 的：

```text
99.9% quantile
```

作为 threshold。

这句话很重要：

```text
threshold 来自“没有目标时 background 自己最大会假装多像目标”。
```

### 2.4 point estimate 的优点

point estimate background model 的优点是清楚、简单、可解释：

- 容易实现。
- 容易画图。
- 可以直接和 clutter map、CFAR 思路连接。
- 可以用 empirical `Pfa` 做 threshold calibration。
- 是 deep learning 方法必须超过的强 baseline。

### 2.5 point estimate 的核心限制

它的限制也很明显：它只输出一个典型值，却不告诉你背景分布的宽度。

例如两个 RD cells：

```text
Cell A:
    historical clutter 很稳定，波动很小

Cell B:
    historical clutter heavy-tailed，经常冒尖
```

如果当前功率都比 predicted mean 高 `10 dB`，简单 ratio score 可能认为它们一样异常。

但直觉上：

```text
Cell A 更异常。
```

因为在 Cell A 的 target-free background distribution 下，出现这么高的 current power 更不可能。

这说明 anomaly evidence 不应该只看：

```text
current / mean
```

还应该看：

```text
这个 cell 的 background 本来有多稳定？
这个 high current power 在 H0 下有多罕见？
```

也就是从 point estimate 走向 distribution-aware detection。

---

## 3. Learned Clutter Model 的三个 Level

深度学习或 representation learning 不一定只是在替换 `mean` 或 `median`。

它可以被分成三个 level。

---

## Level 1: Predict Mean / Background Map

### 3.1 模型形式

Level 1 是最接近 Demo 25 的版本：

```text
RD_history[range, Doppler, time]
  -> learned model
  -> predicted_background_power[range, Doppler]
```

也就是：

```text
history -> \hat B(r,d)
```

只不过 `\hat B` 不再由 mean / median / q25 手工计算，而是由 neural network 预测。

可能模型：

- temporal CNN
- ConvLSTM
- U-Net over RD history
- lightweight transformer over RD frames

### 3.2 score

Level 1 仍然可以用 Demo 25 的 score：

```text
score(r,d)
  = current_power(r,d) / (\hat B(r,d) + floor)
```

### 3.3 它能解决什么

它可能比 simple mean / median 更好地捕捉：

- clutter ridge 从 `0 m/s` 漂到 `3 m/s`
- Doppler-spread clutter 的形状变化
- range-dependent clutter texture
- clutter ridge 宽度变化
- temporal trend rather than only recent average

### 3.4 它仍然缺什么

Level 1 仍然是 point estimate。

它只告诉你：

```text
我预测 background mean / typical power 是多少。
```

但它没有告诉你：

```text
这个 prediction 有多确定？
这个 cell 的 clutter 是稳定还是 heavy-tailed？
当前值在 H0 下有多罕见？
```

所以 Level 1 是一个很自然的第一步，但不一定是最 radar-like 的终点。

---

## Level 2: Predict Background + Uncertainty

### 4.1 模型形式

Level 2 不只输出一个 background map，而是输出 background 和 uncertainty：

```text
RD_history
  -> predicted_mean[range, Doppler]
  -> predicted_uncertainty[range, Doppler]
```

可以写成：

```text
RD_history -> \mu(r,d), \sigma(r,d)
```

其中：

- `\mu(r,d)` 是 clutter-only power 的典型水平。
- `\sigma(r,d)` 表示这个 cell 正常背景波动有多大。

### 4.2 score

一个直观 score 是 normalized residual：

```text
score(r,d)
  = (current_power(r,d) - \mu(r,d)) / \sigma(r,d)
```

或者在 log-power domain：

```text
score(r,d)
  = (current_log_power(r,d) - \mu_log(r,d)) / \sigma_log(r,d)
```

更 robust 的版本可以预测 quantile：

```text
RD_history -> predicted_q999(r,d)
```

然后检测：

```text
current_power(r,d) > predicted_q999(r,d)
```

### 4.3 为什么 uncertainty 重要

回到 Cell A / Cell B 的例子：

```text
Cell A:
    mean = 10
    std  = small

Cell B:
    mean = 10
    std  = large / heavy-tailed
```

如果当前都是：

```text
current = 100
```

那么 `current / mean` 都是 10 倍。

但 uncertainty-aware score 会认为：

```text
Cell A 更异常，
Cell B 可能只是正常 clutter spike。
```

这比 point estimate 更接近真实 detection 问题。

### 4.4 Level 2 的风险

如果假设 background 是 Gaussian，但真实 clutter 是 heavy-tailed，那么：

```text
mean / std z-score 可能 miscalibrate false alarm rate。
```

heavy-tailed clutter 有两个风险：

- tail spikes 会让 empirical `Pfa` 比 Gaussian assumption 预测的高。
- 大 outliers 会 inflate `std`，导致 weak target 的 score 变小。

所以 Level 2 要小心 distribution assumption。

---

## Level 3: Predict Full Distribution / Tail Probability

### 5.1 模型形式

Level 3 是最 radar-like 的版本。

它不只预测 mean 或 uncertainty，而是预测：

```text
p(background_power(r,d) | RD_history)
```

也就是：

```text
在没有目标的假设 H0 下，
给定历史 RD maps，
当前 cell 的 background power 应该服从什么分布？
```

### 5.2 和 radar detection 的连接

Radar detection 可以写成两个假设：

```text
H0: clutter/background only
H1: target + clutter/background
```

Level 3 直接建模的是：

```text
H0 distribution
```

然后当前观测 `z(r,d)` 的异常程度可以写成 tail probability：

```text
p_tail(r,d)
  = P(background_power >= z(r,d) | RD_history, H0)
```

如果这个概率很小，说明：

```text
在没有目标的情况下，很难看到这么大的值。
```

因此可以定义 anomaly score：

```text
score(r,d)
  = -log p_tail(r,d)
```

或者直接用：

```text
p_tail(r,d) < threshold
```

### 5.3 为什么 Level 3 最自然

Level 3 自动处理了前面的 Cell A / Cell B 问题：

```text
same current / mean ratio
```

不代表 same anomaly strength。

真正应该比较的是：

```text
这个 current value 在各自 H0 distribution 下的 tail probability。
```

所以：

```text
stable low-variance cell:
    tail probability smaller -> more anomalous

heavy-tailed cell:
    tail probability larger -> less anomalous
```

### 5.4 Level 3 的难点

Level 3 的难点也更大：

- 要学完整分布或高分位 tail，数据需求更高。
- Tail calibration 比 mean prediction 更难。
- Synthetic clutter 上学到的 distribution 可能不泛化。
- Persistent target 仍然可能污染 training history。
- 最终仍然要用 held-out target-free data 验证 empirical `Pfa`。

一句话：

```text
Level 3 最符合 detection theory，
但也最需要 calibration discipline。
```

---

## 4. 三个 Level 的对比

| Level | Model output | Typical score | Strength | Limitation |
| --- | --- | --- | --- | --- |
| Level 1 | predicted background power | `current / background` | 简单，接近 Demo 25，容易实现 | 不知道 uncertainty / tail |
| Level 2 | mean + uncertainty or quantile | normalized residual / quantile exceedance | 能区分 stable cell 和 noisy cell | 分布假设可能错，tail calibration 仍难 |
| Level 3 | full H0 distribution / tail probability | `-log P_H0(Z >= current)` | 最接近 radar detection theory | 数据、建模、校准都更难 |

---

## 5. 和 CFAR / Clutter Map 的关系

CFAR、clutter map、learned anomaly detector 都可以放进同一个统计检测框架：

```text
estimate background behavior under H0
  -> compute detection statistic / anomaly score
  -> choose threshold for desired Pfa
  -> evaluate Pd at fixed Pfa
```

区别是 background behavior 从哪里估计：

```text
CA-CFAR:
    current frame 的 local training cells

classical clutter map:
    same cell 的 historical samples

Demo 25 point estimate:
    historical RD maps -> mean / median / q25 background estimate

learned clutter model:
    RD_history -> learned representation -> mean / uncertainty / distribution
```

所以 deep learning 的研究价值不应该表述成：

```text
replace CFAR with a neural network
```

更强的表述是：

```text
learn a better H0 background model from RD history,
then perform calibrated detection at fixed empirical Pfa.
```

---

## 6. 对研究的启发

Demo 25 之后，研究问题可以从：

```text
Which handcrafted clutter-map update rule is best?
```

升级成：

```text
What should a learned clutter model output for calibrated radar detection?
```

可能的研究路线：

1. 先做 Level 1：用 temporal CNN / ConvLSTM 预测 next-frame clutter map。
2. 和 `static mean`、`recent mean`、`recent median`、`recent q25` 比较。
3. 在 same empirical `Pfa` 下看 slow-target `Pd` 是否提高。
4. 再做 Level 2：输出 uncertainty 或 high quantile。
5. 最后探索 Level 3：输出 tail probability 或 full clutter distribution。

评价标准必须保持 radar 风格：

```text
At fixed empirical Pfa,
does the learned model improve Pd and delay target absorption?
```

不要只看：

```text
reconstruction loss
visual map quality
classification accuracy
```

因为 radar detector 最终要对 downstream tracker 负责：

```text
false alarms per CPI
Pd at target SCR
calibration under clutter drift
target absorption time
```

---

## 7. 最重要的一句话

Point estimate background model 问的是：

```text
当前值比我预测的 typical background 大多少？
```

Distributional clutter model 问的是：

```text
如果这里没有目标，
在这个 cell 的历史背景分布下，
看到当前值这么大到底有多不可能？
```

第二个问题更接近 radar detection 的本质。

