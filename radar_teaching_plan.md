# Radar DSP 教学方案

本文档用于把这个仓库逐步建设成一个“学习和体验雷达信号处理”的实验项目。核心路线是：

1. 先用 MATLAB 搭一个可验证的 complex-baseband end-to-end radar simulator。
2. 再把 antenna、propagation、target、RF impairments、ADC、DSP 链路逐步拆出来。
3. 最后把已经验证过的算法和数据流迁移到 Simulink block model。

重要原则：不要一开始就把整张系统图完整搬进 Simulink。先把 tensor 维度、坐标系、物理量和 DSP 结果跑通，再做 block-level system integration。

## 1. 学习目标与核心抽象

整个 phased-array pulse-Doppler radar 的 DSP，可以先理解为对一个 3D complex tensor 做 range-Doppler-angle processing：

```text
x[fast time, slow time, array element]
```

| 维度 | 物理意义 | 主要处理 |
| --- | --- | --- |
| fast time | pulse 内采样 | range processing、matched filter、pulse compression |
| slow time | pulse-to-pulse | Doppler FFT、MTI、clutter cancellation |
| array element | 阵元通道 | beamforming、DOA、angle estimation |

学习时要反复追问三个相位分别来自哪里：

```text
range phase / delay       -> fast-time dimension
Doppler phase             -> slow-time dimension
spatial phase             -> array-element dimension
```

阶段性成功标准：

- 能生成单目标 echo，并在 range-Doppler map 上看到清楚的 peak。
- peak 的 range、velocity、angle 与设定值一致。
- 能解释 bandwidth、PRF、CPI length、array aperture 对分辨率和模糊性的影响。
- 能逐个打开 clutter、jammer、RF impairments，并观察它们如何污染 range-Doppler-angle cube。

## 2. 工具分层

| 层级 | 工具 | 目的 |
| --- | --- | --- |
| Algorithm layer | MATLAB + Phased Array System Toolbox | 快速理解 waveform、array、range-Doppler、CFAR、beamforming |
| Scenario / waveform-IQ layer | Radar Toolbox | target motion、scenario management、I/Q echo synthesis |
| RF / mixed-signal layer | Simulink + RF Blockset | IQ imbalance、phase noise、PA nonlinearity、filter、ADC/DAC 等非理想性 |

建议顺序：

1. 第一阶段尽量用 MATLAB 数组、FFT 和自己写的函数，不急着依赖高级 object。
2. 第二阶段再引入 Phased Array System Toolbox 验证处理链和参考算法。
3. 第三阶段用 Radar Toolbox 管理更复杂的 target motion 和 scenario。
4. 第四阶段只在算法链路稳定后，把模块迁移到 Simulink / RF Blockset。

## 3. 最小可用雷达

目标：单天线、单目标、无 RF impairments，只验证 pulse-Doppler processing 是否正确。

推荐 baseline 参数：

| 参数 | 建议值 | 含义 |
| --- | ---: | --- |
| carrier frequency, `fc` | 10 GHz | X-band，波长约 3 cm |
| bandwidth, `B` | 10 MHz | range resolution 约 15 m |
| pulse width, `tau` | 10 us | LFM pulse |
| PRF | 10 kHz | max unambiguous range 约 15 km |
| pulses per CPI, `Np` | 64 | Doppler FFT 长度 |
| sample rate, `fs` | 20 MHz | 至少覆盖 waveform bandwidth |
| target range | 4 km | 固定单目标 |
| target radial velocity | 30 m/s | 产生明显 Doppler shift |
| SNR | 10-20 dB | 先让目标足够清楚 |

第一版链路：

```text
LFM waveform
-> target delay + Doppler shift + path loss
-> additive noise
-> matched filter / pulse compression
-> Doppler FFT
-> range-Doppler map
-> peak picking
```

必须验证的公式：

```text
range resolution:
Delta R = c / (2B)

Doppler frequency:
fD = 2v / lambda

velocity estimate:
v = lambda fD / 2
```

第一版输出物：

1. matched filter output vs range
2. range-Doppler map
3. peak picking result with estimated range and velocity

验收标准：

- range peak 出现在 4 km 附近。
- velocity estimate 接近 30 m/s。
- 改变 `B` 后，range resolution 的变化符合 `c/(2B)`。
- 改变 `Np` 后，Doppler bin spacing 的变化符合 CPI length。

## 4. Phased Array 扩展

第二阶段把单通道扩展为多阵元，让数据从 2D range-Doppler map 变成 3D range-Doppler-angle cube。

推荐起点：

| 参数 | 建议值 |
| --- | ---: |
| array type | ULA |
| number of elements | 8 或 16 |
| element spacing | `lambda/2` |
| target azimuth | 20 deg |

接收信号模型：

```text
x_m(t, n) =
  alpha * s(t - tau)
  * exp(j 2 pi fD n T_PRI)
  * exp(-j 2 pi (m - 1) d sin(theta) / lambda)
  + w_m(t, n)
```

| 符号 | 意义 |
| --- | --- |
| `m` | array element index |
| `t` | fast time |
| `n` | pulse index / slow time |
| `tau = 2R/c` | round-trip delay |
| `fD = 2v/lambda` | Doppler frequency |
| `theta` | angle of arrival |

处理链：

```text
each antenna channel
-> matched filter
-> Doppler FFT
-> beamforming / spatial FFT / MUSIC / MVDR
-> range-Doppler-angle cube
```

建议实现三类 angle processing：

| 方法 | 目的 |
| --- | --- |
| conventional beamforming | 最直观，理解 steering vector 和 beampattern |
| spatial FFT | 直观看 angle bins 和 aperture 限制 |
| MUSIC / MVDR | 体验 super-resolution 和 adaptive beamforming |

实验菜单：

| 实验 | 观察点 |
| --- | --- |
| `N = 4, 8, 16, 32` | beamwidth、angle resolution |
| `d = lambda/2` vs `d = lambda` | grating lobes |
| `theta = -40:10:40 deg` | steering vector phase progression |
| 两个接近 angle 的目标 | aperture 对可分辨性的影响 |

验收标准：

- 在检测到的 range-Doppler bin 上，angle spectrum 的 peak 出现在 20 deg 附近。
- 能解释为什么 `d > lambda/2` 会出现 grating lobes。
- 能比较 conventional beamforming、spatial FFT、MUSIC/MVDR 的优缺点。

## 5. 环境复杂度扩展

第三阶段开始接近真实 radar environment，但每次只加一个因素，避免调试困难。

推荐顺序：

```text
single target
-> multiple point targets
-> distributed clutter
-> moving clutter
-> jammer
-> multipath / propagation loss
```

实验设计：

| 实验 | 观察什么 |
| --- | --- |
| 两个不同 range 的目标 | range resolution |
| 两个不同 velocity 的目标 | Doppler resolution |
| 两个接近 angle 的目标 | array aperture / angle resolution |
| stationary clutter | zero-Doppler ridge |
| moving clutter | Doppler-spread clutter |
| sidelobe jammer | beamformer robustness |
| mainlobe jammer | conventional beamforming 的崩溃 |

Detection pipeline：

```text
range-Doppler map
-> 2D CFAR
-> detection list
-> range / velocity / angle estimation
```

需要记录的指标：

| 指标 | 目的 |
| --- | --- |
| `Pd` | detection probability |
| `Pfa` | false alarm probability |
| range bias | range estimate 是否偏移 |
| Doppler bias | velocity estimate 是否偏移 |
| angle bias | beam pointing / calibration 是否可靠 |

验收标准：

- 能用 2D CFAR 从 range-Doppler map 中得到 detection list。
- 能观察 clutter ridge，并用 MTI 或 Doppler filtering 降低 stationary clutter。
- 能展示 sidelobe jammer 与 mainlobe jammer 对 beamforming 的不同影响。

## 6. RF / ADC Impairments

第四阶段仍然建议先使用 complex baseband equivalent model。不要真的用 10 GHz passband waveform 采样，否则仿真会非常慢，而且对学习 DSP 主线帮助不大。

逐个加入这些非理想因素：

| 模块 | 建议建模 |
| --- | --- |
| DAC | quantization、sample rate、reconstruction filter |
| TX analog filter | bandwidth limit、group delay |
| PA | AM/AM、AM/PM、P1dB、IP3、saturation |
| LO | phase noise、frequency offset |
| mixer | IQ imbalance、LO leakage |
| RF chain | gain、noise figure、bandpass filter |
| antenna channels | per-element gain/phase mismatch |
| RX LNA | noise figure、compression |
| ADC | quantization、clipping、sampling jitter |
| digital receiver | DDC、decimation、AGC、calibration |

每个 impairment 都回答同一个问题：

```text
它最终如何污染 range-Doppler-angle cube？
```

典型现象：

| Impairment | 典型影响 |
| --- | --- |
| phase noise | Doppler spreading、range-Doppler floor 抬高 |
| IQ imbalance | image artifact |
| PA nonlinearity | spectral regrowth、matched filter sidelobe 变差 |
| ADC clipping | false alarms |
| array gain/phase mismatch | beam pointing error、sidelobe rise |
| timing jitter | high-frequency waveform 的 SNR loss |
| LO frequency offset | Doppler bias |
| insufficient dynamic range | clutter leakage 淹没弱目标 |

推荐输出图：

1. impairment off 的 range-Doppler map
2. impairment on 的 range-Doppler map
3. CFAR false alarms 对比
4. range / Doppler / angle bias 对比

验收标准：

- 每次只打开一个 impairment，并保存 before / after 图。
- 能解释 impairment 对 matched filter、Doppler FFT、beamforming 或 CFAR 的具体影响。
- 能用同一组 baseline 参数对不同 impairment 做公平比较。

## 7. Simulink 迁移路线

等 MATLAB 脚本验证过后，再搭 Simulink。Simulink 的价值是 block-level system integration，而不是替代前期数学建模。

第一版 Simulink 子系统：

```text
Waveform Generator
-> Target Echo Synthesizer
-> Receiver DSP
-> Range-Doppler Display
```

第二版替换为更真实的物理链路：

```text
Target Echo Synthesizer
-> Antenna + Channel + Target + Receiver Front-end
```

最终 block architecture：

```text
Digital TX Baseband
    waveform generator
    pulse scheduler
    digital beamformer / phase shifter

Analog TX Front-end
    DAC
    reconstruction filter
    gain control

RF TX Front-end
    mixer / upconverter
    LO phase noise
    PA nonlinearity
    bandpass filter

Phased Array Antenna
    radiator
    steering vector
    element pattern
    mutual mismatch, optional

Forward Channel
    free-space propagation
    path loss
    delay

Target / Clutter / Jammer
    RCS
    Doppler
    scattering
    clutter patches
    jammer waveform

Backward Channel
    return propagation
    delay
    loss

Phased Array Receiver
    collector
    element-channel data

RF RX Front-end
    LNA
    mixer
    phase noise
    IQ imbalance
    filter

Analog Receiver
    AGC
    anti-aliasing filter
    ADC

Digital Receiver
    DDC
    decimation
    calibration
    matched filter
    Doppler FFT
    beamforming
    CFAR
    tracker / display
```

迁移验收标准：

- MATLAB 版本和 Simulink 版本在同一 baseline 参数下，range-Doppler peak 位置一致。
- 每个 Simulink block 的输入输出维度明确，尤其是 fast time、slow time、array element 三个维度。
- 先跑通 single target，再逐步打开 array、clutter、jammer、RF impairments。

## 8. 6-8 周学习安排

### Week 1: 跑官方例子，建立直觉

目标：

- 理解 Doppler shift、pulse-Doppler processing、range-Doppler response。
- 跑通 pulse compression、CFAR detection、basic phased-array beamforming。

输出物：

```text
range-time intensity plot
range-Doppler map
beampattern
single-target detection result
```

验收标准：

- 能解释 range-Doppler map 的两个坐标轴。
- 能指出 matched filter peak、Doppler peak、beam peak 分别对应什么物理量。

### Week 2: 自己写 single-channel MATLAB simulator

目标：不用高级对象，自己写一遍 signal model。

实现：

```text
LFM pulse
delay
Doppler phase
AWGN
matched filter
Doppler FFT
range-Doppler plot
```

验收标准：

- 单目标 range / velocity 估计正确。
- 能通过参数变化验证 range resolution 和 Doppler resolution。

### Week 3: 加入 ULA phased array

目标：理解 spatial phase。

实现：

```text
steering vector
receive array data
digital beamforming
angle scan
range-angle map
range-Doppler-angle cube
```

实验：

```text
N = 4, 8, 16, 32
d = lambda/2 and d = lambda
target angle = -40 deg to 40 deg
```

验收标准：

- angle spectrum peak 与设定 angle 一致。
- 能解释 aperture、sidelobe、grating lobe。

### Week 4: 加入 detection metrics

目标：从“看图”变成“评估系统”。

实现：

```text
CFAR
Pd / Pfa
ROC curve
SNR sweep
Monte Carlo
```

实验：

```text
SNR = -20:2:20 dB
Pfa = 1e-2, 1e-4, 1e-6
target RCS variation
```

验收标准：

- 能画出 ROC curve。
- 能解释 threshold、training cells、guard cells 的作用。

### Week 5: 加入 clutter 和 jammer

目标：理解现实环境问题。

实现：

```text
stationary clutter
moving clutter
noise jammer
tone jammer
sidelobe jammer
mainlobe jammer
```

处理方法：

```text
MTI
Doppler filtering
adaptive threshold
spatial nulling
MVDR beamforming
STAP, optional
```

验收标准：

- stationary clutter 能形成 zero-Doppler ridge。
- sidelobe jammer 可通过 spatial nulling 或 MVDR 明显压制。
- mainlobe jammer 会展示 conventional beamforming 的限制。

### Week 6: 加入 RF / ADC impairments

目标：连接 radar DSP 和 hardware reality。

逐个开关：

```text
ADC bits
ADC clipping
phase noise
IQ imbalance
array calibration error
PA compression
channel gain mismatch
thermal noise / noise figure
```

每个 impairment 都画：

```text
before / after range-Doppler map
CFAR false alarms
estimated range bias
estimated Doppler bias
estimated angle bias
```

验收标准：

- 能说明每个 impairment 如何改变 noise floor、sidelobe、bias 或 false alarm。
- 能用量化指标比较 impairment 开关前后差异。

### Week 7-8: Simulink system integration

目标：把 MATLAB simulator 迁移成 block-level system。

迁移顺序：

```text
Waveform Generator
-> Target Echo Synthesizer
-> Receiver DSP
-> Range-Doppler Display

Target Echo Synthesizer
-> Antenna + Channel + Target + Receiver Front-end

RF impairments
-> ADC/DAC
-> fixed-point
-> FPGA/SoC partitioning
```

验收标准：

- Simulink 模型与 MATLAB simulator 的 baseline 输出一致。
- 每个 block 的 sample time、frame size、tensor dimension 都清楚标注。
- 能逐步替换模块，而不是一次性重搭全部系统。

## 9. 最重要的实验菜单

| 实验 | 你会学到什么 |
| --- | --- |
| Increase bandwidth | range resolution 为什么变好 |
| Increase CPI length | Doppler resolution 为什么变好 |
| Increase PRF | unambiguous velocity 变大，但 unambiguous range 变小 |
| Increase array aperture | angle resolution 变好 |
| Change element spacing | grating lobes 为什么出现 |
| Add phase noise | Doppler skirt / clutter leakage |
| Add ADC clipping | false alarms |
| Add IQ imbalance | image artifacts |
| Add array calibration error | beam pointing error |
| Add jammer | sidelobe / mainlobe interference 的差异 |
| Add CFAR | threshold 如何随 clutter/noise 自适应 |

建议每个实验都固定记录：

- 改了哪个参数或打开了哪个模块。
- 预期物理现象是什么。
- 实际 range-Doppler-angle cube 如何变化。
- 检测结果、估计 bias、false alarms 是否变化。
- 这说明 radar DSP 链路里的哪个假设被破坏了。

## 10. 推荐代码结构

后续实现时建议把仓库组织成小模块，每个 demo 只回答一个问题：

```text
radar_basics_matlab/
  configs/
    xband_lfm_baseline.m
    array_ula_16.m
    impairment_profiles.m

  waveform/
    make_lfm_pulse.m
    make_pulse_train.m

  channel/
    point_target_echo.m
    freespace_loss.m
    clutter_model.m
    jammer_model.m

  array/
    steering_vector_ula.m
    apply_tx_beamforming.m
    apply_rx_beamforming.m

  frontend/
    add_phase_noise.m
    add_iq_imbalance.m
    quantize_adc.m
    pa_nonlinearity.m
    analog_filter.m

  dsp/
    matched_filter_bank.m
    range_doppler_fft.m
    cfar_2d.m
    angle_scan.m
    estimate_targets.m

  demos/
    demo_01_single_target_rd.m
    demo_02_phased_array_angle.m
    demo_03_cfar.m
    demo_04_clutter_jammer.m
    demo_05_rf_impairments.m
```

模块边界建议：

| 目录 | 职责 |
| --- | --- |
| `configs/` | 参数集中管理，保证实验可复现 |
| `waveform/` | 只负责生成发射波形 |
| `channel/` | 只负责 propagation、target、clutter、jammer |
| `array/` | 只负责 steering vector 和 beamforming |
| `frontend/` | 只负责 RF / analog / ADC impairments |
| `dsp/` | 只负责 matched filter、FFT、CFAR、estimation |
| `demos/` | 只编排实验，不塞大量底层逻辑 |

## 11. 最小 Starting Point

第一版就做这个：

| 参数 | 值 |
| --- | ---: |
| waveform | LFM pulse |
| bandwidth, `B` | 10 MHz |
| pulse width, `tau` | 10 us |
| carrier frequency, `fc` | 10 GHz |
| PRF | 10 kHz |
| pulses per CPI, `Np` | 64 |
| sample rate, `fs` | 20 MHz |
| target range | 4 km |
| target velocity | 30 m/s |
| ULA elements | 8 |
| element spacing | `lambda/2` |
| target angle | 20 deg |

生成三张图：

```text
1. matched filter output vs range
2. range-Doppler map
3. angle spectrum at detected range-Doppler bin
```

这三张图稳定之后，整个系统骨架就打通了。后面所有模块，本质上都是在这个 skeleton 上增加 realism。

## 12. 学习记录模板

每完成一个实验，建议在笔记里记录：

```text
Experiment:

Question:

Changed parameter / module:

Expected effect:

Observed range-Doppler-angle effect:

Detection / estimation result:

What I learned:

Next experiment:
```

这个模板的重点是把“我看到了图”变成“我知道哪个物理机制造成了这个图”。

## 13. 参考资料

- [Phased Array System Toolbox 入门](https://jp.mathworks.com/help/phased/getting-started-with-phased-array-system-toolbox.html)
- [radarTransceiver - Monostatic radar transceiver](https://www.mathworks.com/help/radar/ref/radartransceiver-system-object.html)
- [RF Blockset Examples](https://www.mathworks.com/help/simrf/examples.html)
- [Doppler Shift and Pulse-Doppler Processing](https://www.mathworks.com/help/phased/ug/doppler-shift-and-pulse-doppler-processing.html)
- [Detection - MATLAB & Simulink](https://www.mathworks.com/help/phased/detection.html)
- [Enabling RF Circuit Envelope Simulation in MATLAB](https://la.mathworks.com/videos/enabling-rf-circuit-envelope-simulation-in-matlab-1641971035057.html)
- [Pulse-Doppler Radar Using AMD RFSoC Device](https://www.mathworks.com/help/phased/ug/pulse-doppler-radar-using-xilinx-rfsoc-device.html)
