# Learner Current Understanding

## Current Topic and Stage

- Current curriculum topic: CFAR and detection metrics
- Current learning stage: Stationary clutter and two-pulse MTI demo has run successfully; next step is CFAR after clutter suppression or moving clutter / Doppler-spread clutter
- Last updated: 2026-06-12

## Concepts the Learner Seems to Understand

- Correctly maps target range/delay to `fast time`, target velocity/Doppler to `slow time`, and target angle/spatial phase to `array element`.
- Understands that fixing `fast time` and `array element` leaves a slow-time vector whose phase varies with target radial velocity.
- Understands that array geometry creates element-to-element delay differences, visible as spatial phase differences across array elements.
- Understands that the single-target continuous-time received signal, vector form, and data-cube form are different representations of the same underlying array echo, rather than separate physical models.
- Understands range, Doppler, and angle processing as matched-filter/projection operations against delay, slow-time sinusoid, and spatial steering templates.
- Correctly predicts that increasing LFM bandwidth narrows the matched-filter range peak and that increasing pulse count improves Doppler/velocity bin spacing.
- Correctly predicts that two targets separated by less than the approximate range resolution tend to merge into one range peak, while increasing bandwidth makes them easier to separate.
- Understands that larger target separation makes two range responses easier to distinguish, especially when separation exceeds the nominal range-resolution scale.
- Understands that targets separated only slightly beyond nominal range resolution can still have strongly overlapping matched-filter mainlobes, producing partial rather than clean separation.
- Correctly predicts that two targets separated by 2 m/s will strongly overlap in Doppler for `Np = 64`, and will still overlap substantially for `Np = 128`.
- Correctly computes that about `Np = 300` pulses are needed to make velocity bin spacing roughly `0.5 m/s` at `fc = 10 GHz` and `PRF = 10 kHz`.
- Correctly predicts that increasing PRF decreases maximum unambiguous range and increases maximum unambiguous velocity.
- Correctly recognizes that a target velocity beyond the unambiguous velocity interval will Doppler-alias/wrap rather than appear at its true velocity.
- Correctly computes a simple aliased velocity by subtracting the velocity period, e.g. `160 m/s -> 10 m/s` when the velocity period is about `150 m/s`.
- Understands ambiguity as an aliasing problem: sampling makes spectra repeat/shift, and if the repeated copies overlap or map multiple physical parameters to the same sampled phase progression, the original physical value cannot be uniquely recovered.
- Correctly identifies that a broadside ULA target has zero element-to-element phase shift and an all-ones steering vector under the normalized convention.
- Correctly simplifies a nonzero ULA steering-vector phase progression: for `Delta phi = -pi/2`, the first four entries are `[1, -j, -1, j]`.
- Correctly predicts that increasing ULA element count from `M = 8` to `M = 16` narrows the mainlobe and makes the sidelobe/null structure denser.
- Has seen a MATLAB ULA beamforming scan where spatial matched filtering estimates a `20 deg` target at about `20.05 deg`.
- Has seen a MATLAB grating-lobe comparison where `d = lambda/2` suppresses the `-30 deg` alias for a `30 deg` target, while `d = lambda` produces an equal-height grating lobe at `-30 deg`.
- Has seen a full `x[fast time, slow time, array element]` MATLAB demo estimate range, velocity, and angle from a single target using matched filtering, Doppler FFT, and angle scan.
- Correctly traces `demo_06` from raw data-cube synthesis through matched filtering, Doppler FFT, RD peak picking, and angle scan at the detected RD cell.
- Correctly computes ULA spatial frequency `u = d*sin(theta)/lambda`; for `d = lambda/2` and `theta = 30 deg`, `u = 0.25`.
- Has seen conventional ULA angle scan and spatial FFT estimate the same `30 deg` target by finding the same spatial frequency.
- Understands that using `Nfft = 4096` for a 16-element spatial FFT is zero-padding/interpolation of the spatial spectrum, not an increase in true angle resolution.
- Understands the unified Fourier/aperture view: range, Doppler, and angle processing map data to frequency-like coordinates whose peaks correspond to physical parameters.
- Understands that physical resolution is tied to measurement support/aperture: waveform bandwidth for range, CPI duration for Doppler, and array aperture/element count for angle.
- Has seen an angle-resolution demo where increasing `Nfft` from 16 to 4096 smooths/interpolates the spectrum, while increasing `M` from 16 to 32 actually narrows the mainlobe and improves physical angular separation.
- Correctly infers that, in ideal MUSIC, two uncorrelated targets correspond to a two-dimensional signal subspace.
- Correctly computes MUSIC subspace dimensions from `M` array elements and `K` sources, e.g. `M = 16`, `K = 3` gives signal subspace dimension 3 and noise subspace dimension 13.
- Has seen a minimal MUSIC demo where covariance eigendecomposition separates two signal eigenvectors from a 14-dimensional noise subspace for `M = 16`, `K = 2`.
- Has seen MUSIC resolve two close angular targets at `20 deg` and `28 deg` more sharply than conventional beamforming under ideal assumptions.
- Correctly understands the core MVDR intuition: conventional beamforming does not actively null a strong off-angle jammer, while MVDR uses covariance information to place a null in the interference direction under a distortionless target constraint.
- Has seen a minimal MVDR jammer-nulling demo where both conventional and MVDR keep `20 deg` look gain at `0 dB`, but MVDR suppresses a `-30 deg` jammer much more deeply.
- Correctly understands that fewer snapshots / less reliable covariance estimates call for larger diagonal loading to make MVDR less aggressive and more stable.
- Has seen an MVDR diagonal-loading sweep where small loading forms a deep jammer null and very large loading makes the null shallower and more conventional-like.
- Understands that MUSIC and MVDR depend on training snapshots/covariance quality and are less plug-and-play than conventional beamforming because they rely on modeling assumptions and tuning choices.
- Understands that CFAR is not specific to range-Doppler maps; it can operate on any detection statistic map/cube such as range profiles, RD maps, RA maps, DA maps, or RDA tensors.
- Has seen a 1D CA-CFAR demo on a matched-filter range profile, including CUT-level thresholding, guard cells, training cells, target detection, and contiguous detection clustering.
- Understands detection as a mapping from a 1D/2D/3D detection-statistic tensor to a same-shape binary mask tensor indicating candidate target cells.
- Has seen a 2D CA-CFAR demo on a range-Doppler map that outputs a same-shape binary detection mask and strongest detection estimate.
- Has seen a Monte Carlo CFAR metrics demo estimating empirical `Pfa` from noise-only trials and empirical `Pd` from target-present trials across an SNR sweep.
- Understands the Monte Carlo framing for CFAR metrics: one random trial generates a detection-statistic profile, CFAR tests each valid CUT using local training cells to estimate a random threshold, and repeated trials estimate `Pfa`/`Pd` as empirical frequencies.
- Correctly analogizes radar detection to anomaly detection: CA-CFAR flags cells that deviate significantly from a locally estimated background model built from training cells.
- Understands that adjacent positive CFAR cells should not automatically be counted as separate targets; postprocessing must consider connectedness, peak structure, and whether close targets may be unresolved or partially merged.
- Correctly identifies that two local maxima inside one CFAR component with range separation below nominal range resolution should be treated conservatively as unresolved/ambiguous rather than confidently split, because the peaks may be sidelobes or unresolved close targets.
- Correctly uses statistic-to-threshold margin as evidence for detection-report reliability; a detection far above threshold is generally more trustworthy than one barely crossing threshold.
- Correctly distinguishes detection energy from CFAR calibration reliability: a high statistic-to-threshold detection near the RD-map edge still needs a caveat if training cells are incomplete and the threshold estimate may be biased or poorly calibrated.
- Has seen a 2D CFAR detection-list demo convert 28 detected CUTs into 6 connected components, with one strong target report and several weak near-threshold review candidates.
- Correctly interprets Demo 15's CFAR mask visualization: white cells are CFAR-positive candidate cells, yellow markers indicate component peak locations, and a high `statisticToThreshold` makes the main target report much more reliable than weak near-threshold components.
- Has seen a design-`Pfa` sweep on the same RD map: lowering `Pfa` from `1e-3` to `1e-7` increased the CA-CFAR threshold scale `alpha`, reduced detected CUTs/components/review candidates, and still detected the strong target in this scenario.
- Correctly explains the CFAR design-`Pfa` tradeoff: smaller `Pfa` raises the detection threshold, creates a stricter target-declaration standard, reduces point detections, and makes weak low-SNR targets more likely to be missed.
- Has seen ROC-style Monte Carlo curves where lower design `Pfa` shifts the `Pd` versus SNR curve to the right: stricter thresholds require higher target SNR to reach the same detection probability.
- Correctly understands Demo 17 as estimating empirical `Pd` over a grid of `(SNR, design Pfa)` settings using repeated target-present Monte Carlo trials, so the experiment samples the mapping `(SNR, Pfa) -> Pd`.
- Understands detector evaluation as context-dependent rather than a single scalar score: for a specified detector and environment, `Pd` should be interpreted together with SNR and design/empirical `Pfa`.
- Correctly recognizes the operational tradeoff: low-SNR targets make detection difficult, and for CFAR-like detectors a stricter false-alarm requirement raises threshold and usually reduces `Pd` for weak targets.
- Correctly converts a system-level false-alarm budget into per-cell `Pfa`: if `1e6` tested cells can tolerate about `10` false alarms per CPI, the per-cell design `Pfa` should be about `1e-5`.
- Correctly predicts that strong clutter contamination in CA-CFAR training cells biases the noise/clutter estimate upward, raises the threshold, and makes target misses more likely.
- Has seen a 1D clutter-edge demo where a weak target before a 20 dB clutter step is missed by CA-CFAR because the high-clutter side contaminates the training average.
- Correctly generalizes Demo 18: different CFAR-like detectors use different background/noise estimation rules, which create different `Pfa`/`Pd`/ROC behavior under nonhomogeneous clutter; no single simple CFAR variant is uniformly best across all clutter distributions.
- Proposed a research direction: learn environment/clutter statistics from historical or online radar data, then use that learned distribution to improve detection beyond single-frame local CFAR estimates in complex backgrounds.
- Correctly predicts that stationary clutter appears near the `0 m/s` Doppler bin in an RD map because its radial velocity is approximately zero and its slow-time phase is nearly constant.
- Has seen a stationary-clutter RD demo where many zero-velocity scatterers form a vertical zero-Doppler clutter ridge, and a two-pulse MTI canceller suppresses that ridge while preserving a `30 m/s` moving target.

## Understanding Gaps / Misconceptions

- Needs more practice connecting these phase progressions to actual plots: matched-filter output, Doppler FFT bins, and angle spectrum peaks.
- Needs to keep the representation levels distinct: `x_{m,n,p}(t)` is a continuous-time per-element/per-pulse signal, while vector and data-cube forms arise after stacking across array elements and/or sampling/matched filtering into range bins.
- Needs to be careful about conjugation/sign conventions in matched filtering, Doppler FFT, and beamforming templates.
- Should distinguish the mechanisms behind range and Doppler resolution: bandwidth controls delay/range resolution, while CPI duration controls Doppler/velocity resolution.
- Should remember that `Delta R = c/(2B)` is an approximate resolution scale, not a hard threshold; visible separation also depends on waveform shape, sampling, windowing, sidelobes, SNR, and relative target amplitudes.
- May be slightly too conservative about separations just above nominal range resolution; a separation larger than `Delta R` can produce visible separation even when the peaks are not cleanly split.
- Needs to distinguish Doppler resolution from unambiguous velocity: increasing `Np` at fixed PRF improves resolution, while increasing PRF expands the unambiguous Doppler interval.
- Needs practice connecting element count and aperture to beamwidth / angle resolution.
- Needs to connect element spacing to spatial aliasing / grating lobes after seeing the basic angle scan.
- Needs to distinguish true target peaks from sidelobes, noise peaks, and grating lobes in an angle spectrum.
- Should note that increasing element count with uniform weights mainly narrows beamwidth; sidelobe relative levels depend strongly on aperture weighting/windowing.
- Needs to keep angle-domain conventions explicit: `theta = 150 deg` has the same sine as `30 deg`, but with the current broadside scan interval `[-90, 90]`, the `d = lambda` grating lobe for a `30 deg` target appears near `-30 deg`.
- Should next connect grating lobes to the spatial sampling condition `d <= lambda/2` and compare them against ordinary sidelobes.
- Should next practice reading the code path from raw cube to detected target: `rx -> matchedOut -> rangeDopplerAngle -> arraySnapshot -> beamResponse`.
- Should distinguish the economical detected-cell angle scan used in `demo_06` from a full range-Doppler-angle cube, which would scan/beamform every RD cell.
- Should remember the sign convention in `demo_07`: because steering uses `exp(-j2*pi*m*u)`, the spatial FFT is applied to `conj(arraySnapshot)` so the plotted peak appears at positive `u`.
- Should distinguish FFT display grid density from physical resolution: increasing `Nfft` interpolates the spectrum, while increasing `M`/aperture narrows the mainlobe.
- Should phrase the Fourier duality carefully: FFT is the computational projection/display method, while bandwidth, CPI length, and aperture determine the physical response width.
- Should next connect conventional FFT/beamforming limits to why MUSIC/MVDR can improve estimation or interference rejection under stronger assumptions.
- Needs to distinguish the number of snapshots from subspace dimension: snapshots improve covariance estimation quality, while ideal noise-subspace dimension is `M-K` for `M` array elements and `K` sources.
- Ready to see MUSIC implemented as covariance estimation, eigendecomposition, noise-subspace extraction, and pseudospectrum scanning.
- Should remember MUSIC requires stronger assumptions than conventional beamforming: known/estimated source count, enough snapshots, uncorrelated or decorrelated sources, and a good array calibration/model.
- Ready to see MVDR implemented as `w = R^{-1}a/(a^H R^{-1}a)` and compare its pattern against conventional steering weights in a jammer scenario.
- Should distinguish MVDR look-direction weights from the Capon/MVDR spectrum: the former forms a beam with a distortionless constraint, while the latter scans covariance power and can peak at the jammer direction.
- Should be able to explain the visual diagonal-loading tradeoff: small loading trusts covariance strongly, while large loading makes MVDR more conservative and conventional-like.
- Needs to connect diagonal-loading choice to practical covariance quality, steering mismatch, and robustness requirements.
- Should use the term "diagonal loading" rather than "diagonal overloading."
- Needs to learn how CFAR training cells, guard cells, and CUT neighborhoods should be designed differently for 1D, 2D, and 3D detection products.
- Needs to connect CA-CFAR parameters to behavior: more guard cells protect against target leakage, more training cells smooth the noise estimate, and `Pfa` controls threshold scaling under model assumptions.
- Should distinguish the cell-level binary detection mask from the post-processed detection list, where adjacent positive cells are clustered and converted into target reports.
- Needs to learn 2D detection-mask postprocessing: connected-component clustering, peak selection within each cluster, and converting cells to range/velocity reports.
- Needs practice deciding when one connected CFAR blob should become one detection versus multiple detections, using evidence such as multiple local maxima, expected resolution, waveform/array response width, amplitudes, and tracker context.
- Should extend unresolved-target reasoning from range-only resolution to the full 2D/3D response: targets may be range-unresolved but Doppler- or angle-resolved if they are sufficiently separated along those dimensions.
- Should remember that cluster size is contextual rather than monotonic evidence of confidence: a large cluster can mean a strong/extended response, but can also indicate clutter, merging, sidelobe spread, or unresolved targets.
- Should continue treating detection report confidence as a combination of evidence strength and validity of the local thresholding assumptions, including edge effects and training-cell availability.
- Needs practice deciding which detection-list entries should be forwarded to a tracker automatically versus kept as review/caveat candidates, especially when `statisticToThreshold` is only slightly above 1.
- Needs to keep the binary-mask visualization concrete: white pixels/cells mean CFAR-positive cells (`mask = 1`), black pixels/cells mean not detected or not tested/false (`mask = 0`), and plotted markers/boxes are overlays from postprocessing rather than the mask values themselves.
- Should phrase white CFAR cells as candidate target evidence rather than confirmed targets; confirmation/reliability comes later from clustering, peak selection, threshold margin, caveats, and tracker context.
- Needs to connect the clutter-edge result back to detector design choices: CA-CFAR is well calibrated in homogeneous backgrounds, but nonhomogeneous training cells can bias thresholds and motivate GO/SO/OS-CFAR variants.
- Should understand GO/SO/OS-CFAR as robust background estimators matched to different clutter assumptions, not arbitrary threshold tricks; each improves one failure mode while creating another tradeoff.
- Should next distinguish "learning a better background/clutter model" from "losing false-alarm calibration": any learned detector still needs calibrated thresholds, held-out environment tests, and ROC/Pfa validation.
- Needs to connect MTI output to detection: after clutter suppression, CFAR should run on a less clutter-dominated RD map, but MTI also changes noise/clutter statistics and attenuates slow targets near zero Doppler.
- Should keep design `Pfa` distinct from empirical `Pfa`: design `Pfa` sets the CFAR threshold, while empirical `Pfa` is estimated separately from noise-only Monte Carlo trials.
- Should phrase the SNR/Pfa/Pd relation carefully: SNR does not directly make `Pfa` low; rather, high SNR lets a detector maintain high `Pd` even when the chosen design `Pfa` is strict.
- Asked for a deeper explanation of ROC thinking; next teaching should distinguish classic ROC curves from Demo 17's ROC-style Pd-vs-SNR family and connect both to operating-point selection.
- Should refine the automation motivation for detection: beyond high data rates, the key value of detection algorithms is quantifiable and controllable error statistics such as analytic `Pfa` control and ROC analysis, which human operators cannot provide to a downstream tracker.
- Should note that "rule-based" understates CFAR: CA-CFAR thresholds are derived from hypothesis-testing models (e.g. exponential noise gives `alpha = N*(Pfa^{-1/N} - 1)` on the training mean), so performance degradation is predictable when model assumptions break, which motivates GO/SO/OS-CFAR variants.
- Should distinguish statistical/model-based detection thresholds from more heuristic detection-list postprocessing rules such as clustering, peak splitting, merge criteria, and unresolved-target labeling.
- Should practice applying the aliasing/ambiguity framework separately to each radar dimension: range ambiguity from delay modulo PRI, Doppler ambiguity from slow-time sampling at PRF, and spatial ambiguity/grating lobes from element spacing above the spatial Nyquist limit.

## Evidence From Learner Responses

- When asked which tensor dimension changes for target distance, speed, and angle, the learner answered: "1. fast time 2. slow time 3. array element."
- The learner explained that fixing fast time and array element gives a slow-time vector whose phase changes with radial velocity, and that array geometry causes element-dependent delays reflected in phase.
- The learner summarized that the "single-target continuous-time received signal" is the basic model and that the data cube and vector form describe the same thing: the whole array sensing a single-target signal.
- The learner described Doppler processing, angle estimation, and range estimation as template matching operations over slow time, array elements, and fast time, respectively.
- The learner predicted that changing `B` from 10 MHz to 20 MHz makes the range peak narrower, changing `Np` from 64 to 128 makes velocity estimation finer, and the target peak center should remain roughly unchanged.
- The learner predicted that targets at 4000 m and 4008 m look like one peak for `B = 10 MHz`, and become easier to separate for `B = 20 MHz` because the nominal resolution is about 7.5 m.
- For targets at 4000 m and 4020 m, the learner predicted that `B = 20 MHz` would likely resolve them, but that `B = 10 MHz` might still not resolve them; this was partly conservative because 20 m exceeds the 10 MHz nominal resolution of about 15 m.
- The learner explained that at `B = 10 MHz`, a 20 m separation still looks imperfect because the 15 m nominal resolution means the targets are still close and their responses overlap.
- The learner predicted that targets at 30 m/s and 32 m/s will overlap badly with `Np = 64`, and still overlap substantially with `Np = 128`.
- The learner answered `300` when asked how many pulses are needed for velocity bin spacing below about `0.5 m/s` at `fc = 10 GHz` and `PRF = 10 kHz`.
- The learner answered that doubling PRF makes maximum unambiguous range smaller and maximum unambiguous velocity larger.
- The learner answered that a `90 m/s` target at `PRF = 10 kHz`, `fc = 10 GHz` would wrap to another velocity, but guessed it might be around `20 m/s`; the correct shifted-FFT alias is near `-60 m/s`.
- The learner correctly answered that a `160 m/s` target aliases to about `10 m/s` when the velocity period is about `150 m/s`.
- For a ULA broadside target with `theta = 0 deg`, the learner answered that element-to-element phase difference is zero and the steering vector is constant/all ones.
- For `d = lambda/2` and `theta = 30 deg`, the learner answered `pi*d/lambda`; this partly applied `sin(30)=0.5` but missed the negative sign and did not finish substituting `d = lambda/2`.
- After correction that `Delta phi = -pi/2`, the learner correctly simplified the first four steering-vector entries as `[1, -j, -1, j]`.
- A new MATLAB demo estimated a `20 deg` ULA target at `20.05 deg` using the spatial matched-filter response `|a(theta)^H x|`.
- When asked how to interpret a high angle-spectrum peak at `30 deg` and a smaller peak at `-20 deg`, the learner suggested there may be two real targets; this is possible but needs caution because the smaller peak may also be a sidelobe or artifact.
- The learner predicted that increasing ULA element count from `M = 8` to `M = 16` makes the angle-spectrum mainlobe narrower and the sidelobe pattern denser.
- For `d = lambda` and a true `30 deg` target, the learner suggested `150 deg` as another equivalent angle; this is mathematically related through `sin(150 deg) = sin(30 deg)`, while the current `[-90, 90]` scan convention highlights the grating-lobe alias near `-30 deg`.
- A new MATLAB demo showed that for a `30 deg` target with `M = 16`, response at `-30 deg` is about `-308 dB` for `d = lambda/2`, but `0 dB` for `d = lambda`.
- A new MATLAB RDA demo used `rx[fast time, slow time, array element]` and estimated a `4 km`, `30 m/s`, `20 deg` target as `4002.23 m`, `30.45 m/s`, and `20.00 deg`.
- The learner summarized `demo_06` as synthesizing `rx = targetEcho + noise`, applying matched filtering along fast time for each slow-time/channel slice, applying Doppler FFT along slow time for each range/channel slice, then scanning angles only at the detected RD cell rather than all RD cells.
- The learner answered `0.25` for the spatial frequency `u = d*sin(theta)/lambda` with `d = lambda/2` and `theta = 30 deg`.
- A new MATLAB demo estimated a `30 deg` ULA target as `30.05 deg` using conventional angle scan and `30.06 deg` using spatial FFT.
- The learner noticed that a 16-element array used `Nfft = 4096` in `demo_07` and correctly inferred that this is an interpolation/zero-padding trick rather than a 4096-point independent measurement.
- The learner summarized range FFT, Doppler FFT, and angle FFT as converting data to frequency-like domains where response peaks correspond to physical target parameters, and connected resolution to inverse support relationships.
- A new MATLAB demo showed that `M = 16` gives about `7.84 deg` angular resolution near `24 deg` whether `Nfft = 16` or `4096`, while `M = 32` improves the estimate to about `3.92 deg`.
- The learner guessed that two targets give signal subspace dimension 2, and that noise subspace dimension depends on snapshot count; the first part is correct, while the second should be corrected to `M-K` dimension with snapshot count affecting estimation quality.
- The learner correctly answered that for `M = 16` and `K = 3`, the ideal signal/noise subspace dimensions are 3 and 13.
- A new MATLAB MUSIC demo used `M = 16`, `K = 2`, and 200 snapshots; it produced signal/noise subspace dimensions 2 and 14, eigenvalues about `17.80`, `15.08`, and `0.03`, and sharp MUSIC peaks at the two true angles.
- The learner correctly answered that a conventional beamformer pointed at `20 deg` will not actively null a strong `-30 deg` jammer, while MVDR will tend to place a null in the jammer direction if the covariance captures it.
- A new MATLAB MVDR demo used `M = 16`, look direction `20 deg`, jammer direction `-30 deg`, and 500 training snapshots; conventional jammer gain was about `-26.46 dB`, while MVDR jammer gain was about `-80.34 dB`.
- The learner said they do not yet understand why diagonal loading makes MVDR more stable but can make jammer nulls shallower.
- After explanation, the learner correctly answered that with few snapshots and unreliable `R_hat`, larger diagonal loading should be used.
- A new MATLAB loading sweep showed conventional jammer gain about `-26.46 dB`, MVDR loading `1e-6` about `-65.24 dB`, loading `1e-2` about `-69.15 dB`, and large loading `1e1` about `-34.66 dB`.
- The learner summarized that MUSIC and MVDR require training/covariance data and can be unstable because MUSIC needs assumptions such as source count `K`, while MVDR can suppress the wrong directions and requires diagonal loading tuning.
- In a side conversation, the learner asked whether CFAR must be applied on an RD map or can also apply to RA maps and RDA tensors, then accepted that CFAR can operate on any detection map/cube with a CUT and surrounding training cells.
- A new MATLAB 1D CA-CFAR demo detected the single target range profile: `7` CUTs crossed threshold, forming `1` contiguous detection cluster, with strongest detection at `4002.23 m` for a `4000 m` target.
- The learner formulated detection as taking a given input tensor, whether 1D, 2D, or 3D, and outputting a same-shape 0/1 mask tensor where 1 marks cells with target evidence.
- A new MATLAB 2D CA-CFAR demo detected the range-Doppler target: `28` CUTs crossed threshold, with strongest detection at `4002.23 m` and `30.45 m/s` for a `4000 m`, `30 m/s` target.
- A new MATLAB Monte Carlo demo estimated empirical `Pfa = 9.474e-4` for design `Pfa = 1e-3`, and showed `Pd` increasing from near zero at low SNR to about `0.77` at `10 dB` and near `1.0` by `14 dB`.
- The learner summarized CFAR Monte Carlo correctly: each test uses surrounding cells to estimate a threshold for a CUT, repeated random trials estimate probabilities in a frequentist way, and a single trial can include tests over every valid cell.
- The learner compared radar detection to anomaly detection and explained automated detection as motivated by radar data rates exceeding human processing capacity, describing the algorithms as rule-based.
- The learner summarized ambiguity as fundamentally a Fourier/sampling aliasing issue: sampling creates shifted or repeated spectra, and when shifted copies overlap, the original signal information cannot be uniquely recovered.
- When asked whether 20 adjacent positive CFAR cells around one RD peak should become 20 detections, 1 detection, or depend on clustering rules, the learner chose the conditional answer and noted that the underlying scene could be one broadened target response or multiple closely spaced targets.
- The learner asked whether blob interpretation and split/merge decisions are essentially rule-based detections based on human empirical observation implemented as algorithms.
- When asked how to handle two local maxima in one CFAR component with range separation below `Delta R = c/(2B)`, the learner answered that the detector should mark it unresolved because the maxima may be sidelobes or two targets inside the same range-resolution cell.
- When comparing two detection reports, the learner identified the report with `statistic / threshold = 8.5` as more trustworthy than one with `1.2`, focusing on threshold margin rather than target size.
- When asked how to label a detection with `statistic / threshold = 20` at an RD-map edge where training cells are incomplete, the learner answered that it should be treated as high energy but with a caveat because the threshold estimate may be inaccurate.
- A new MATLAB demo converted the 2D CFAR mask into a detection list: 28 detected CUTs formed 6 connected components; the true target report had range `4002.23 m`, velocity `30.45 m/s`, and `statisticToThreshold = 440.41`, while the other components were marked `weak_margin_review`.
- The learner asked what the white and black regions in the CFAR binary mask mean, indicating a need to connect the plotted binary image directly to `cfarMask` values and postprocessing overlays.
- The learner summarized Demo 15: white mask cells are where the detector thinks there is target evidence, yellow markers are peaks inside the white cells/components, and the first detection is more reliable because its `clusterSize = 21` and `statisticToThreshold = 440.41` are much larger than the weak candidates.
- A new MATLAB design-`Pfa` sweep used the same RD map and showed `Pfa = 1e-3` produced `185` detected CUTs and `116` components, `Pfa = 1e-5` produced `28` CUTs and `6` components, and `Pfa = 1e-7` produced `23` CUTs and `3` components; the strong target stayed detected in all three cases.
- The learner summarized Demo 16: threshold is determined by the designed `Pfa`; smaller `Pfa` gives a higher threshold and fewer point detections. For a low-SNR target, the learner predicted `Pfa = 1e-3` is more likely to detect it than `Pfa = 1e-7` because the threshold is lower.
- A new MATLAB ROC-style demo swept target SNR and design `Pfa`; approximate SNR needed for `Pd >= 0.9` increased from `10 dB` at `Pfa = 1e-2`, to `12 dB` at `1e-3`, to `14 dB` at `1e-5`, to `16 dB` at `1e-7`.
- The learner explained Demo 17 as fixing an SNR and design `Pfa`, running Monte Carlo to estimate `Pd`, then sweeping different SNR/Pfa settings to study the resulting `(SNR, Pfa, Pd)` relationship.
- The learner summarized detector evaluation as requiring operating conditions instead of a single number: SNR, design/empirical `Pfa`, and `Pd` must be considered together. The learner also connected low SNR to practical radar constraints such as limited transmit power/cost and small target RCS, and explained that stricter `Pfa` raises CFAR threshold and lowers `Pd` for weak targets.
- The learner asked for a detailed explanation of ROC thinking after understanding that detector evaluation depends jointly on SNR, `Pfa`, and `Pd`.
- When asked to choose per-cell `Pfa` for `1e6` tested cells and an average budget of `10` false alarms per CPI, the learner answered `1e-5`.
- When asked what happens if one side of CA-CFAR training cells contains strong clutter while the CUT has no target, the learner predicted the threshold becomes biased high and targets are more likely to be missed.
- A new MATLAB clutter-edge demo used low/high clutter powers `1` and `100`, a target at bin `262`, and a clutter edge at bin `270`; CA-CFAR saw left/right training means `1.04` and `91.47`, producing a CA threshold `343.68` above the target statistic `121.06`, so the target was missed.
- The learner summarized Demo 18 as showing that different statistical threshold-estimation methods lead to different detector performance (`Pfa`, `Pd`, ROC behavior), and that CFAR-like detectors are not perfect because no single variant handles every clutter distribution well.
- The learner proposed collecting environment statistics before or during radar operation, training a model to learn the clutter/background distribution, and using simulation data to test whether such learned environment-aware detection can outperform CFAR in complex clutter.
- When asked whether stationary clutter or a `30 m/s` target lies closer to the `0 m/s` Doppler bin, the learner answered stationary clutter because its velocity is zero.
- A new MATLAB stationary-clutter demo created 30 zero-velocity clutter scatterers and one `30 m/s` target; the two-pulse MTI reduced total zero-Doppler power by about `73.99 dB`, while the target-cell power changed by about `+1.41 dB`.

## Follow-up Questions to Ask

- After the first MATLAB demo, ask the learner to identify which code lines implement delay, Doppler phase, and matched filtering.
- Ask the learner to explain what indices are being held fixed or stacked when moving from `x_{m,n,p}(t)` to `\mathbf x_{p,k}` and then to `x[m,n,p,k]`.
- Ask the learner to write the Doppler matched-filter sum for a hypothesized Doppler frequency and explain why the matching bin produces coherent gain.
- Ask the learner to distinguish "nominally resolvable" from "visually clean two-peak separation" in a matched-filter profile.
- Ask the learner what evidence would distinguish a second target from a sidelobe in an angle spectrum.
- Ask the learner why grating lobes are more dangerous than ordinary sidelobes in detection.
- Ask the learner to identify which dimensions are processed by matched filtering, Doppler FFT, noncoherent RD peak picking, and angle scan in `demo_06`.
- Ask the learner what would change computationally and dimensionally if angle scan were applied to every range-Doppler cell.
- Ask the learner how to convert a spatial FFT bin `u` back to angle using `theta = asin(u*lambda/d)`.
- Ask the learner to explain one advantage and one limitation of spatial FFT versus arbitrary angle scan.
- Ask the learner what would happen to mainlobe width if `Nfft` stayed 4096 but `M` increased from 16 to 32.
- Ask the learner to compare which change improves display smoothness versus physical resolution: increasing `Nfft` or increasing `M`.
- Ask the learner to explain why zero-padding can help peak interpolation but cannot separate two targets whose mainlobes fundamentally overlap.
- Ask the learner to identify which eigenvectors form the noise subspace after sorting covariance eigenvalues.
- Ask the learner why MUSIC fails or degrades when `K` is chosen incorrectly or snapshots are too few.
- Ask the learner to identify the MVDR distortionless constraint and what would go wrong if the steering vector is mismatched.
- Ask the learner to explain why large diagonal loading makes MVDR behave more like conventional beamforming.
- Ask the learner to compare when conventional beamforming might be preferred over MUSIC/MVDR despite lower resolution or less adaptivity.
- Ask the learner to identify what the CUT, guard cells, and training cells would mean in a 1D range profile versus a 2D RD map.
- Ask the learner why multiple adjacent CUT detections near one target should usually be clustered before reporting target count.
- Ask the learner what information a detection list should include beyond the binary mask, such as estimated range, velocity, angle, and detection statistic/SNR.
- Ask the learner why CFAR edge cells are often left untested or handled specially.
- Ask the learner what happens to `Pd` at fixed SNR if the design `Pfa` is reduced from `1e-3` to `1e-6`.
- Ask the learner which quantity a downstream tracker needs from the detector that a human operator watching displays cannot guarantee or calibrate.
- Ask the learner what evidence inside one connected CFAR component would justify splitting it into two target reports instead of reporting one peak.
- Ask the learner which demo_15 detection-list rows should be forwarded automatically to a tracker and which should be filtered or caveated, and why.
- Ask the learner to predict what would happen to a weaker target if design `Pfa` were reduced from `1e-3` to `1e-7`.
- Ask the learner to explain why a stricter design `Pfa` shifts the `Pd` curve to the right, and what operational tradeoff that creates.

## Next Recommended Learning Step

- Add CFAR before/after MTI to show how clutter suppression changes the detector's false alarms and target detectability, then discuss slow-target loss near the MTI notch.

## Update History

| Date | Topic | Evidence | Update |
| --- | --- | --- | --- |
| 2026-06-09 | Core tensor model | First learning session started. | Created learner model file with initial topic and no assessed understanding yet. |
| 2026-06-09 | Core tensor model | Correctly identified fast time, slow time, and array element as the dimensions for range, velocity, and angle. | Recorded initial correct mapping; next check should assess physical reasoning. |
| 2026-06-09 | Core tensor model | Explained slow-time phase variation with radial velocity and element-to-element phase from array geometry. | Marked the core tensor model as initially stable and moved next step to MATLAB implementation. |
| 2026-06-09 | Signal model representations | Summarized continuous-time, vector, and data-cube forms as different descriptions of the whole array sensing the same single-target signal. | Recorded understanding of equivalent representations; added a nuance to distinguish continuous-time per-element signals from stacked/sampled vector and tensor forms. |
| 2026-06-09 | Matched-filter view of radar processing | Described Doppler, angle, and range processing as matching templates along slow time, array element, and fast time. | Recorded a strong unifying abstraction; added a caution about conjugation/sign conventions. |
| 2026-06-09 | Resolution parameters | Correctly predicted the qualitative effects of increasing bandwidth and pulse count on range and velocity resolution. | Recorded correct prediction and added nuance that range resolution comes from bandwidth while Doppler resolution comes from CPI duration. |
| 2026-06-09 | Range resolution | Correctly predicted that 8 m target separation is unresolved or barely resolved at 10 MHz bandwidth and easier to separate at 20 MHz. | Recorded understanding of the range-resolution formula and added nuance that resolution is an approximate scale rather than a hard boundary. |
| 2026-06-09 | Range resolution | Predicted that 20 m separation would likely resolve at 20 MHz but might still not resolve at 10 MHz. | Recorded partly correct prediction; clarified that 20 m exceeds the 10 MHz nominal resolution, so partial visible separation is expected even if the two peaks are not clean. |
| 2026-06-09 | Range resolution | Explained that 20 m separation at 10 MHz is still close to the 15 m resolution scale, so responses overlap and do not form clean peaks. | Recorded understanding of nominal resolution versus clean visual separation. |
| 2026-06-09 | Doppler resolution | Predicted that 30 m/s and 32 m/s targets overlap strongly for `Np = 64`, and still overlap a lot for `Np = 128`. | Recorded correct qualitative transfer of resolution logic from range to Doppler; next step is MATLAB slow-time FFT verification. |
| 2026-06-09 | Doppler resolution | Computed `Np` as about 300 for velocity bin spacing below `0.5 m/s` at 10 GHz carrier and 10 kHz PRF. | Recorded correct formula-based parameter reasoning; next step is PRF ambiguity tradeoffs. |
| 2026-06-09 | PRF ambiguity tradeoff | Correctly predicted that doubling PRF reduces unambiguous range and increases unambiguous velocity. | Recorded understanding of the basic PRF tradeoff; next step is Doppler aliasing. |
| 2026-06-09 | Doppler aliasing | Predicted that a 90 m/s target exceeds the unambiguous velocity and will wrap, but guessed the alias near 20 m/s. | Recorded correct aliasing intuition and corrected the shifted-FFT alias to about -60 m/s. |
| 2026-06-09 | Doppler aliasing | Correctly computed that 160 m/s aliases to about 10 m/s for a 150 m/s velocity period. | Recorded successful alias calculation; ready to connect temporal aliasing to spatial aliasing in arrays. |
| 2026-06-09 | ULA steering vector | Correctly answered that broadside has zero spatial phase increment and an all-ones steering vector. | Recorded initial understanding of the ULA steering vector at broadside; next step is nonzero angle phase progression. |
| 2026-06-09 | ULA steering vector | For `d = lambda/2`, `theta = 30 deg`, answered `pi*d/lambda` for the phase increment. | Recorded partial substitution and corrected the current-convention phase increment to `-pi/2`; follow-up should practice steering-vector entries. |
| 2026-06-09 | ULA steering vector | Correctly simplified `Delta phi = -pi/2` steering-vector entries as `[1, -j, -1, j]`. | Recorded corrected nonzero-angle steering-vector understanding. |
| 2026-06-09 | ULA beamforming | Ran a ULA spatial matched-filter angle scan with a 20 deg target and estimated 20.05 deg. | Connected steering-vector templates to conventional beamforming output; next step is aperture and grating-lobe experiments. |
| 2026-06-09 | Angle spectrum interpretation | Interpreted a high peak at 30 deg and smaller peak at -20 deg as possibly two real targets. | Recorded plausible interpretation and added caution that smaller peaks can be sidelobes, noise peaks, or grating lobes. |
| 2026-06-09 | ULA aperture | Predicted that increasing element count from 8 to 16 narrows the mainlobe and makes sidelobe structure denser. | Recorded correct aperture intuition; added nuance that sidelobe levels depend on weighting/windowing. |
| 2026-06-09 | Spatial aliasing | Suggested 150 deg as an equivalent angle for a 30 deg target with `d = lambda`. | Recorded the sine-equivalence insight and clarified that under the current broadside scan convention, the visible grating-lobe alias is near -30 deg. |
| 2026-06-09 | Spatial aliasing | Ran a MATLAB comparison showing `d = lambda/2` has no strong `-30 deg` alias, while `d = lambda` creates an equal-height `-30 deg` grating lobe for a `30 deg` target. | Recorded visual/numerical evidence that element spacing above `lambda/2` can create spatial aliasing. |
| 2026-06-09 | Range-Doppler-angle cube | Built and ran `demo_06_single_target_rda_cube.m`, estimating range, velocity, and angle from `rx[fast time, slow time, array element]`. | Recorded successful integration of the three processing dimensions into one end-to-end skeleton. |
| 2026-06-09 | Range-Doppler-angle cube | Correctly summarized `demo_06` processing order and noted that angle scan is applied only to the detected RD cell. | Recorded strong code-level understanding and added distinction between detected-cell scan and full RDA cube generation. |
| 2026-06-09 | Spatial FFT | Correctly computed spatial frequency `u = 0.25` for `d = lambda/2`, `theta = 30 deg`. | Began connecting ULA steering vectors to FFT over the array-element dimension. |
| 2026-06-09 | Spatial FFT | Built and ran `demo_07_spatial_fft_vs_angle_scan.m`, estimating a 30 deg target as 30.05 deg by angle scan and 30.06 deg by spatial FFT. | Recorded that conventional beamforming scan and spatial FFT are two views of the same ULA spatial-frequency matching operation. |
| 2026-06-09 | Spatial FFT | Noticed that `Nfft = 4096` is much larger than the 16 array elements and asked whether it is interpolation. | Recorded correct understanding that zero-padding densifies the displayed FFT grid but does not improve physical angle resolution. |
| 2026-06-09 | Fourier/aperture view | Summarized range, Doppler, and angle FFTs as frequency-domain mappings whose responses correspond to physical target parameters, with resolution tied to inverse support. | Recorded a strong unified abstraction and added nuance that FFT displays/projections reveal resolution set by physical support/aperture. |
| 2026-06-09 | Angle resolution | Built and ran `demo_08_angle_resolution_m_vs_nfft.m`, comparing `M=16,Nfft=16`, `M=16,Nfft=4096`, and `M=32,Nfft=4096` for two close angular targets. | Recorded visual/numerical evidence that zero-padding interpolates the display grid, while increasing array aperture improves true angular resolution. |
| 2026-06-09 | MUSIC motivation | Correctly inferred that two targets imply a two-dimensional signal subspace, but thought noise subspace dimension depends on snapshot count. | Recorded partial MUSIC subspace understanding and corrected that ideal noise subspace dimension is `M-K`, while snapshots affect covariance estimate quality. |
| 2026-06-09 | MUSIC motivation | Correctly computed signal/noise subspace dimensions as 3 and 13 for `M = 16`, `K = 3`. | Recorded stable understanding of MUSIC subspace dimensions. |
| 2026-06-09 | MUSIC demo | Built and ran `demo_09_music_two_targets.m`, comparing conventional beamforming and MUSIC for two close angular targets. | Recorded that MUSIC can produce sharper two-target DOA peaks by using the noise subspace, under stronger covariance/model assumptions. |
| 2026-06-09 | MVDR motivation | Correctly stated that conventional beamforming does not actively null an off-angle jammer, while MVDR tends to null the jammer if covariance estimation captures it. | Recorded the core MVDR intuition and moved next step to a jammer-nulling demo. |
| 2026-06-09 | MVDR demo | Built and ran `demo_10_mvdr_jammer_nulling.m`, comparing conventional and MVDR weights for a 20 deg look direction with a -30 deg jammer. | Recorded that MVDR preserves look-direction gain while placing a much deeper jammer null than conventional beamforming. |
| 2026-06-10 | MVDR diagonal loading | Said the stability/null-depth tradeoff from diagonal loading is not yet clear. | Recorded diagonal-loading intuition as the current MVDR understanding gap. |
| 2026-06-10 | MVDR diagonal loading | Correctly answered that fewer snapshots / less reliable covariance estimates call for larger diagonal loading. | Recorded initial diagonal-loading intuition; next step is visualizing the loading sweep. |
| 2026-06-10 | MVDR diagonal loading | Built and ran `demo_11_mvdr_diagonal_loading_sweep.m`, showing small loading yields deep jammer nulls while very large loading makes the null shallower. | Recorded visual/numerical evidence of the stability versus null-depth tradeoff. |
| 2026-06-10 | MUSIC/MVDR assumptions | Summarized that MUSIC and MVDR need training/covariance data and are sensitive to assumptions such as source count, covariance quality, steering mismatch, and diagonal loading. | Recorded strong practical understanding of advanced beamforming tradeoffs. |
| 2026-06-10 | CFAR scope | Asked whether CFAR must be applied to RD maps or can also apply to RA maps and RDA tensors. | Recorded understanding that CFAR is a general adaptive-threshold method for detection maps/cubes, not an RD-only algorithm. |
| 2026-06-10 | 1D CA-CFAR | Built and ran `demo_12_cfar_1d_range_profile.m`, detecting the matched-filter target range profile with CA-CFAR. | Recorded first CFAR implementation: CUT thresholding produced 7 adjacent detected CUTs grouped into 1 target cluster, strongest at 4002.23 m. |
| 2026-06-10 | Detection formulation | Formulated detection as converting an input statistic tensor into a same-shape binary mask tensor. | Recorded correct engineering abstraction and added nuance that masks are usually clustered into detection lists. |
| 2026-06-10 | 2D CA-CFAR | Built and ran `demo_13_cfar_2d_range_doppler.m`, detecting a single target in a range-Doppler map with a 2D CA-CFAR mask. | Recorded first 2D CFAR implementation: 28 detected CUTs, strongest detection at 4002.23 m and 30.45 m/s. |
| 2026-06-10 | Detection metrics | Built and ran `demo_14_cfar_pd_pfa_monte_carlo.m`, estimating empirical false alarm probability and detection probability versus SNR. | Recorded first Monte Carlo detection-metrics demo: empirical Pfa matched design Pfa closely and Pd increased with SNR. |
| 2026-06-10 | Detection motivation | Compared detection to anomaly detection and attributed automation mainly to high radar data rates, calling CFAR rule-based. | Recorded the apt anomaly-detection analogy; refined the motivation to controllable error statistics and noted CA-CFAR thresholds derive from hypothesis-testing models rather than ad-hoc rules. |
| 2026-06-11 | Learning-state refresh | Recalled `radar_teaching_plan.md` and `learners_current_understanding.md` before continuing. | Aligned current stage with completed 2D CFAR and Pd/Pfa Monte Carlo demos. |
| 2026-06-11 | Ambiguity / aliasing | Explained ambiguity through Fourier aliasing: sampling creates repeated/shifted spectra, and overlap destroys unique recoverability. | Recorded the unified ambiguity mental model and added follow-up practice across range, Doppler, and spatial dimensions. |
| 2026-06-11 | CFAR Monte Carlo metrics | Summarized that each CFAR random experiment tests cells by estimating a local threshold from neighboring values, and repeated trials estimate probabilities by empirical frequency. | Recorded understanding of the CUT-level CFAR test, trial-level repetition, and frequentist interpretation of empirical `Pfa` and `Pd`. |
| 2026-06-11 | CFAR detection-list postprocessing | Chose the conditional interpretation for 20 adjacent CFAR detections and explained that the blob could represent one target response or multiple close targets. | Recorded nuanced understanding that CFAR masks require clustering/peak analysis before target reports, and that close-target separation depends on resolution and evidence. |
| 2026-06-11 | Detection rules vs statistical detection | Asked whether blob interpretation rules are empirical human-observation rules implemented as algorithms. | Recorded need to distinguish CFAR's statistical threshold model from heuristic/engineering postprocessing rules used to convert masks into detection lists. |
| 2026-06-11 | Unresolved CFAR components | Answered that two local maxima closer than nominal range resolution should be marked unresolved/ambiguous because they may be sidelobes or targets in the same range-resolution cell. | Recorded conservative split/merge reasoning and added nuance that separability should be assessed across range, Doppler, and angle dimensions. |
| 2026-06-11 | Detection report confidence | Chose the compact detection with `statistic / threshold = 8.5` over the large barely-above-threshold cluster at `1.2`. | Recorded understanding that threshold margin is strong evidence of report reliability, while cluster size requires contextual interpretation. |
| 2026-06-11 | Edge-cell detection caveats | Labeled a `statistic / threshold = 20` edge detection as high energy but needing a caveat because incomplete training cells make threshold estimation less reliable. | Recorded distinction between evidence strength and reliability of CFAR calibration assumptions. |
| 2026-06-11 | CFAR detection list demo | Built and ran `demo_15_cfar_detection_list.m`, converting 28 CFAR CUT detections into 6 connected-component reports. | Recorded that the true target has a very large threshold margin while weak near-threshold components should be marked for review rather than treated as equally reliable targets. |
| 2026-06-11 | CFAR mask visualization | Asked what black and white mean in the CFAR binary mask plot. | Recorded visualization gap: connect white cells to `mask = 1`, black cells to `mask = 0`/untested cells, and yellow markers/boxes to postprocessing overlays. |
| 2026-06-11 | Demo 15 consolidation | Correctly summarized white CFAR-positive cells, yellow component peaks, and why the high-margin main report is more reliable than weak candidates. | Marked Demo 15 concept as understood, with a small wording nuance that white cells are candidate evidence rather than confirmed targets. |
| 2026-06-11 | CFAR Pfa tradeoff demo | Built and ran `demo_16_cfar_pfa_tradeoff.m`, comparing `Pfa = 1e-3`, `1e-5`, and `1e-7` on the same RD map. | Recorded that stricter design `Pfa` raises threshold scale, reduces CUT/component/review-candidate counts, and still detects the strong target in this controlled scenario. |
| 2026-06-11 | CFAR Pfa/Pd tradeoff | Explained that smaller design `Pfa` raises threshold and reduces point detections; predicted that a low-SNR target is more likely to be detected with `Pfa = 1e-3` than `Pfa = 1e-7`. | Recorded understanding of the qualitative ROC tradeoff: looser thresholds improve detection probability for weak targets while allowing more false candidates. |
| 2026-06-11 | CFAR ROC-style curves | Built and ran `demo_17_cfar_roc_pfa_snr_sweep.m`, sweeping target SNR for design `Pfa = 1e-2`, `1e-3`, `1e-5`, and `1e-7`. | Recorded the ROC-style result that stricter `Pfa` reduces false alarms but shifts the `Pd` curve right, requiring higher SNR for the same detection probability. |
| 2026-06-11 | Demo 17 interpretation | Described each Monte Carlo point as fixing SNR and design `Pfa`, estimating `Pd`, then studying the relationship across `(SNR, Pfa, Pd)`. | Recorded correct experiment-design understanding and added nuance that empirical `Pfa` is estimated separately from noise-only trials. |
| 2026-06-11 | Detector evaluation tradeoffs | Summarized that detector quality is context-dependent and should be evaluated through SNR, `Pfa`, and `Pd`, especially under low-SNR operational constraints. | Recorded strong ROC-level understanding and added nuance that SNR affects `Pd` for a chosen threshold but does not directly set `Pfa`. |
| 2026-06-11 | ROC thinking request | Asked for a detailed explanation of ROC thinking. | Recorded the next teaching need: explain detector statistic distributions, threshold movement, classic ROC, Demo 17's Pd-vs-SNR family, and operating-point selection. |
| 2026-06-11 | False-alarm budget | Computed per-cell `Pfa = 1e-5` from `10` allowable false alarms over `1e6` tested cells. | Recorded understanding that operating-point selection is constrained by downstream false-alarm budget, not just by per-cell detector theory. |
| 2026-06-11 | CA-CFAR clutter contamination | Predicted that strong clutter in training cells raises CA-CFAR threshold and makes miss detections more likely. | Recorded initial understanding of CA-CFAR failure modes in nonhomogeneous backgrounds. |
| 2026-06-12 | CA-CFAR clutter edge demo | Built and ran `demo_18_cfar_clutter_edge.m`; CA-CFAR missed a target near a 20 dB clutter step because right-side training cells raised the threshold above the target statistic. | Recorded visual and numerical evidence that CA-CFAR's homogeneous-background assumption breaks at clutter edges, motivating clutter-aware CFAR variants. |
| 2026-06-12 | CFAR variant tradeoffs | Summarized that different threshold-estimation statistics produce different detector performance and that no CFAR-like detector is universally best across clutter distributions. | Recorded strong conceptual understanding of detector/clutter mismatch and added nuance that CFAR variants are robust estimators tuned to different assumptions. |
| 2026-06-12 | Environment-learned detection idea | Proposed learning environment/clutter distributions from prior or online radar data to improve detection beyond single-frame CFAR estimates, first validated with simulation. | Recorded a promising research direction and the need to preserve calibrated `Pfa`/ROC evaluation when using learned models. |
| 2026-06-12 | Stationary clutter Doppler intuition | Predicted that stationary clutter appears near the zero-Doppler bin because its radial velocity is approximately zero. | Recorded readiness to move from CFAR-only detection into clutter ridge and MTI/Doppler filtering. |
| 2026-06-12 | Stationary clutter and MTI demo | Built and ran `demo_19_stationary_clutter_mti.m`; stationary clutter formed a zero-Doppler ridge and two-pulse MTI suppressed zero-Doppler power by about `73.99 dB` while preserving the `30 m/s` target. | Recorded visual/numerical evidence that stationary clutter is a slow-time problem and that MTI is a Doppler high-pass/notch filter before detection. |
