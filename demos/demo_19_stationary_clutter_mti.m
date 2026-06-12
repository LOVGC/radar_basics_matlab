%% demo_19_stationary_clutter_mti
% Stationary clutter forms a zero-Doppler ridge; MTI suppresses it.
%
% Data model: x[fast time, slow time]. A moving target has pulse-to-pulse
% Doppler phase progression, while stationary clutter is nearly constant
% across slow time and concentrates near the zero-Doppler bin.

clear; close all; clc;

%% Baseline parameters
c = 299792458;
fc = 10e9;
lambda = c / fc;

B = 10e6;
tau = 10e-6;
fs = 20e6;
PRF = 10e3;
PRI = 1 / PRF;
Np = 64;

targetRange = 4e3;
targetVelocity = 30;
targetAmplitude = 0.7;

clutterRanges = (1.2e3:250:8.5e3).';
clutterVelocity = 0;
clutterAmplitude = 3.5;

noisePower = 0.04;

%% Derived values
K = B / tau;
Nfast = round(fs / PRF);
Ntx = round(tau * fs);
tFast = (0:Nfast-1).' / fs;
tPulse = (0:Ntx-1).' / fs;

rangeResolution = c / (2 * B);
dopplerBinHz = PRF / Np;
velocityBin = lambda * dopplerBinHz / 2;
targetDoppler = 2 * targetVelocity / lambda;

fprintf("Theoretical range resolution: %.2f m\n", rangeResolution);
fprintf("Velocity bin spacing: %.2f m/s\n", velocityBin);
fprintf("Target Doppler: %.2f Hz, target velocity: %.2f m/s\n", ...
    targetDoppler, targetVelocity);
fprintf("Stationary clutter scatterers: %d, velocity %.2f m/s\n", ...
    numel(clutterRanges), clutterVelocity);

%% Transmit waveform and echo synthesis
txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);

rng(191);
rx = complex(zeros(Nfast, Np));
targetEcho = localPointEcho(targetRange, targetVelocity, targetAmplitude, ...
    txPulse, tFast, PRI, lambda, c, K, tau, Np);

clutterEcho = complex(zeros(Nfast, Np));
clutterPhase = exp(1j * 2 * pi * rand(numel(clutterRanges), 1));
for iClutter = 1:numel(clutterRanges)
    rangeJitter = 8 * randn;
    amplitudeJitter = clutterAmplitude * (0.7 + 0.6 * rand);
    clutterEcho = clutterEcho + localPointEcho( ...
        clutterRanges(iClutter) + rangeJitter, clutterVelocity, ...
        amplitudeJitter * clutterPhase(iClutter), txPulse, tFast, ...
        PRI, lambda, c, K, tau, Np);
end

noise = sqrt(noisePower / 2) * (randn(Nfast, Np) + 1j * randn(Nfast, Np));
rx = targetEcho + clutterEcho + noise;

%% Matched filtering along fast time
matchedFilter = conj(flipud(txPulse));
[matchedOut, rangeAxis] = localMatchedFilter(rx, matchedFilter, fs, c, PRF, Ntx);

%% MTI high-pass filtering along slow time
% Two-pulse canceller: y[p] = x[p] - x[p-1]. It nulls exactly stationary
% slow-time content, with a notch at zero Doppler.
mtiOut = [complex(zeros(size(matchedOut, 1), 1)), diff(matchedOut, 1, 2)];

%% Doppler FFT before and after MTI
slowTimeWindow = 0.5 - 0.5 * cos(2 * pi * (0:Np-1) / (Np-1));
rangeDoppler = fftshift(fft(matchedOut .* slowTimeWindow, [], 2), 2);
rangeDopplerMti = fftshift(fft(mtiOut .* slowTimeWindow, [], 2), 2);

dopplerAxis = (-Np/2:Np/2-1) * PRF / Np;
velocityAxis = lambda * dopplerAxis / 2;

rdPower = abs(rangeDoppler).^2;
rdPowerMti = abs(rangeDopplerMti).^2;

zeroDopplerIndex = find(abs(velocityAxis) == min(abs(velocityAxis)), 1);
targetVelocityIndex = find(abs(velocityAxis - targetVelocity) ...
    == min(abs(velocityAxis - targetVelocity)), 1);
targetRangeIndex = find(abs(rangeAxis - targetRange) ...
    == min(abs(rangeAxis - targetRange)), 1);

zeroDopplerPowerBefore = sum(rdPower(:, zeroDopplerIndex));
zeroDopplerPowerAfter = sum(rdPowerMti(:, zeroDopplerIndex));
targetCellPowerBefore = rdPower(targetRangeIndex, targetVelocityIndex);
targetCellPowerAfter = rdPowerMti(targetRangeIndex, targetVelocityIndex);

fprintf("Zero-Doppler total power before MTI: %.3e\n", zeroDopplerPowerBefore);
fprintf("Zero-Doppler total power after  MTI: %.3e\n", zeroDopplerPowerAfter);
fprintf("Zero-Doppler suppression: %.2f dB\n", ...
    10 * log10((zeroDopplerPowerBefore + eps) / (zeroDopplerPowerAfter + eps)));
fprintf("Target cell power change after MTI: %.2f dB\n", ...
    10 * log10((targetCellPowerAfter + eps) / (targetCellPowerBefore + eps)));

%% Plots
rdBeforeDB = 10 * log10(rdPower / max(rdPower(:)) + eps);
rdAfterDB = 10 * log10(rdPowerMti / max(rdPower(:)) + eps);

rangeProfileBeforeDB = 10 * log10(rdPower(:, zeroDopplerIndex) ...
    / max(rdPower(:)) + eps);
rangeProfileAfterDB = 10 * log10(rdPowerMti(:, zeroDopplerIndex) ...
    / max(rdPower(:)) + eps);

figure("Name", "Demo 19: Stationary Clutter and MTI", "Color", "w", ...
    "Position", [100, 100, 1250, 760]);
tiledlayout(2, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, rdBeforeDB);
axis xy;
colorbar;
clim([-65, 0]);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("Before MTI: zero-Doppler clutter ridge");
hold on;
plot(targetVelocity, targetRange / 1e3, "wo", "MarkerSize", 7, ...
    "LineWidth", 1.3);
xline(0, "w--", "0 m/s", "HandleVisibility", "off");

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, rdAfterDB);
axis xy;
colorbar;
clim([-65, 0]);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("After two-pulse MTI");
hold on;
plot(targetVelocity, targetRange / 1e3, "wo", "MarkerSize", 7, ...
    "LineWidth", 1.3);
xline(0, "w--", "0 m/s", "HandleVisibility", "off");

nexttile;
plot(rangeAxis / 1e3, rangeProfileBeforeDB, "r-", ...
    "LineWidth", 1.1, "DisplayName", "Before MTI");
hold on;
plot(rangeAxis / 1e3, rangeProfileAfterDB, "b-", ...
    "LineWidth", 1.1, "DisplayName", "After MTI");
grid on;
xlabel("Range (km)");
ylabel("Zero-Doppler power (dB rel.)");
title("Zero-Doppler range profile");
legend("Location", "southoutside", "Orientation", "horizontal");
ylim([-80, 5]);

nexttile;
localPlotMtiResponse(velocityAxis, PRF, lambda);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_19_stationary_clutter_mti.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

%% Local functions
function echo = localPointEcho(targetRange, targetVelocity, amplitude, ...
    txPulse, tFast, PRI, lambda, c, K, tau, Np)

    Nfast = numel(tFast);
    echo = complex(zeros(Nfast, Np));
    delayTime = 2 * targetRange / c;
    dopplerHz = 2 * targetVelocity / lambda;
    tDelayed = tFast - delayTime;
    echoMask = (tDelayed >= 0) & (tDelayed < tau);

    for p = 1:Np
        absoluteTime = tFast + (p-1) * PRI;

        onePulseEcho = complex(zeros(Nfast, 1));
        delayedPulse = exp(1j * pi * K * (tDelayed(echoMask) - tau/2).^2);
        dopplerPhase = exp(1j * 2 * pi * dopplerHz * absoluteTime(echoMask));
        onePulseEcho(echoMask) = amplitude * delayedPulse .* dopplerPhase;

        echo(:, p) = onePulseEcho;
    end
end

function [matchedOut, rangeAxis] = localMatchedFilter(rx, matchedFilter, fs, c, PRF, Ntx)
    [Nfast, Np] = size(rx);
    NrangeFull = Nfast + Ntx - 1;
    matchedOut = complex(zeros(NrangeFull, Np));

    for p = 1:Np
        matchedOut(:, p) = conv(rx(:, p), matchedFilter, "full");
    end

    rangeAxis = ((0:NrangeFull-1).' - (Ntx - 1)) / fs * c / 2;
    validRange = (rangeAxis >= 0) & (rangeAxis <= c / (2 * PRF));
    rangeAxis = rangeAxis(validRange);
    matchedOut = matchedOut(validRange, :);
end

function localPlotMtiResponse(velocityAxis, PRF, lambda)
    dopplerHz = 2 * velocityAxis / lambda;
    normalizedResponse = abs(1 - exp(-1j * 2 * pi * dopplerHz / PRF));
    responseDB = 20 * log10(normalizedResponse / max(normalizedResponse) + eps);

    plot(velocityAxis, responseDB, "k-", "LineWidth", 1.2);
    grid on;
    xlabel("Velocity (m/s)");
    ylabel("Magnitude (dB)");
    title("Two-pulse MTI Doppler response");
    xline(0, "r--", "0 m/s notch", "HandleVisibility", "off");
    ylim([-60, 5]);
end
