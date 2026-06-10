%% demo_01_single_target_rd
% Minimal complex-baseband pulse-Doppler radar demo.
% Data model for this first demo: x[fast time, slow time].

clear; close all; clc;

%% Baseline parameters
c = 299792458;              % speed of light, m/s
fc = 10e9;                  % carrier frequency, Hz
lambda = c / fc;

B = 10e6;                   % LFM bandwidth, Hz
tau = 10e-6;                % pulse width, s
fs = 20e6;                  % sample rate, Hz
PRF = 10e3;                 % pulse repetition frequency, Hz
PRI = 1 / PRF;
Np = 64;                    % pulses per CPI

targetRange = 4e3;          % m
targetVelocity = 30;        % m/s, positive Doppler in this demo
SNRdB = 10;

%% Derived values
K = B / tau;                            % chirp slope, Hz/s
Nfast = round(fs / PRF);                % fast-time samples per PRI
Ntx = round(tau * fs);                  % transmit pulse samples
tFast = (0:Nfast-1).' / fs;
tPulse = (0:Ntx-1).' / fs;

delayTime = 2 * targetRange / c;
fD = 2 * targetVelocity / lambda;

rangeResolution = c / (2 * B);
dopplerBinHz = PRF / Np;
velocityBin = lambda * dopplerBinHz / 2;

fprintf("Theoretical range resolution: %.2f m\n", rangeResolution);
fprintf("Doppler bin spacing: %.2f Hz, velocity bin spacing: %.2f m/s\n", ...
    dopplerBinHz, velocityBin);
fprintf("Target Doppler frequency: %.2f Hz\n\n", fD);

%% Transmit waveform: baseband LFM pulse at the start of each PRI
txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);

%% Echo synthesis: delay along fast time, Doppler phase along slow time
rng(7);
rx = complex(zeros(Nfast, Np));
targetEcho = complex(zeros(Nfast, Np));
tDelayed = tFast - delayTime;
echoMask = (tDelayed >= 0) & (tDelayed < tau);

for p = 1:Np
    absoluteTime = tFast + (p-1) * PRI;

    onePulseEcho = complex(zeros(Nfast, 1));
    delayedPulse = exp(1j * pi * K * (tDelayed(echoMask) - tau/2).^2);
    dopplerPhase = exp(1j * 2 * pi * fD * absoluteTime(echoMask));
    onePulseEcho(echoMask) = delayedPulse .* dopplerPhase;

    targetEcho(:, p) = onePulseEcho;
end

signalPower = mean(abs(targetEcho(echoMask, 1)).^2);
noisePower = signalPower / 10^(SNRdB / 10);
noise = sqrt(noisePower / 2) * (randn(Nfast, Np) + 1j * randn(Nfast, Np));
rx = targetEcho + noise;

%% Matched filter / pulse compression along fast time
matchedFilter = conj(flipud(txPulse));
NrangeFull = Nfast + Ntx - 1;
matchedOut = complex(zeros(NrangeFull, Np));

for p = 1:Np
    matchedOut(:, p) = conv(rx(:, p), matchedFilter, "full");
end

rangeAxis = ((0:NrangeFull-1).' - (Ntx - 1)) / fs * c / 2;
validRange = (rangeAxis >= 0) & (rangeAxis <= c / (2 * PRF));
rangeAxis = rangeAxis(validRange);
matchedOut = matchedOut(validRange, :);

%% Doppler FFT along slow time
slowTimeWindow = 0.5 - 0.5 * cos(2 * pi * (0:Np-1) / (Np-1));
rangeDoppler = fftshift(fft(matchedOut .* slowTimeWindow, [], 2), 2);

dopplerAxis = (-Np/2:Np/2-1) * PRF / Np;
velocityAxis = lambda * dopplerAxis / 2;

%% Peak picking
[~, peakLinearIndex] = max(abs(rangeDoppler(:)));
[peakRangeIndex, peakDopplerIndex] = ind2sub(size(rangeDoppler), peakLinearIndex);

estimatedRange = rangeAxis(peakRangeIndex);
estimatedVelocity = velocityAxis(peakDopplerIndex);

fprintf("Estimated range: %.2f m (truth %.2f m)\n", estimatedRange, targetRange);
fprintf("Estimated velocity: %.2f m/s (truth %.2f m/s)\n", ...
    estimatedVelocity, targetVelocity);

%% Plots
mfProfile = abs(matchedOut(:, 1));
mfProfileDB = 20 * log10(mfProfile / max(mfProfile) + eps);

rdMagnitude = abs(rangeDoppler);
rdMagnitudeDB = 20 * log10(rdMagnitude / max(rdMagnitude(:)) + eps);

figure("Name", "Demo 01: Single Target Range-Doppler", "Color", "w");
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(rangeAxis / 1e3, mfProfileDB, "LineWidth", 1.2);
grid on;
xlabel("Range (km)");
ylabel("Normalized magnitude (dB)");
title("Matched filter output");
xlim([0, c / (2 * PRF) / 1e3]);
ylim([-60, 5]);

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, rdMagnitudeDB);
axis xy;
colorbar;
clim([-60, 0]);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("Range-Doppler map");
hold on;
plot(estimatedVelocity, estimatedRange / 1e3, "wo", ...
    "MarkerSize", 8, "LineWidth", 1.5);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_01_single_target_rd.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);
