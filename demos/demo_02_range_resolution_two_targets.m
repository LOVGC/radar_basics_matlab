%% demo_02_range_resolution_two_targets
% Compare matched-filter range profiles for two closely spaced targets.

clear; close all; clc;

%% Scenario
c = 299792458;
tau = 10e-6;                % pulse width, s
fs = 200e6;                 % high sample rate for smooth visualization
PRF = 10e3;

targetRanges = [4000, 4008];        % m
targetAmplitudes = [1.0, 0.9];      % keep the second target slightly lower
bandwidths = [10e6, 20e6];          % Hz

Nfast = round(fs / PRF);
Ntx = round(tau * fs);
tFast = (0:Nfast-1).' / fs;
tPulse = (0:Ntx-1).' / fs;

figure("Name", "Demo 02: Range Resolution", "Color", "w");
tiledlayout(numel(bandwidths), 1, "Padding", "compact", "TileSpacing", "compact");

for iBand = 1:numel(bandwidths)
    B = bandwidths(iBand);
    K = B / tau;

    txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);
    rx = complex(zeros(Nfast, 1));

    for iTarget = 1:numel(targetRanges)
        delayTime = 2 * targetRanges(iTarget) / c;
        tDelayed = tFast - delayTime;
        echoMask = (tDelayed >= 0) & (tDelayed < tau);

        delayedPulse = exp(1j * pi * K * (tDelayed(echoMask) - tau/2).^2);
        rx(echoMask) = rx(echoMask) + targetAmplitudes(iTarget) * delayedPulse;
    end

    matchedFilter = conj(flipud(txPulse));
    matchedOut = conv(rx, matchedFilter, "full");

    rangeAxis = ((0:numel(matchedOut)-1).' - (Ntx - 1)) / fs * c / 2;
    validRange = (rangeAxis >= 3950) & (rangeAxis <= 4050);
    rangeZoom = rangeAxis(validRange);
    profile = abs(matchedOut(validRange));
    profileDB = 20 * log10(profile / max(profile) + eps);

    rangeResolution = c / (2 * B);
    fprintf("B = %.0f MHz: nominal range resolution = %.2f m\n", ...
        B / 1e6, rangeResolution);

    nexttile;
    plot(rangeZoom, profileDB, "LineWidth", 1.3);
    grid on;
    hold on;
    xline(targetRanges(1), "--", "R1", "LabelVerticalAlignment", "bottom");
    xline(targetRanges(2), "--", "R2", "LabelVerticalAlignment", "bottom");
    xlabel("Range (m)");
    ylabel("Normalized magnitude (dB)");
    title(sprintf("B = %.0f MHz, nominal \\DeltaR = %.2f m", ...
        B / 1e6, rangeResolution));
    xlim([3970, 4038]);
    ylim([-45, 3]);
end

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_02_range_resolution_two_targets.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

