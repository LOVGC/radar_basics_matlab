%% demo_03_doppler_resolution_two_targets
% Compare slow-time Doppler spectra for two closely spaced velocities.

clear; close all; clc;

%% Scenario
c = 299792458;
fc = 10e9;
lambda = c / fc;
PRF = 10e3;
PRI = 1 / PRF;

targetVelocities = [30, 32];       % m/s
targetAmplitudes = [1.0, 0.9];
pulseCounts = [64, 128];

figure("Name", "Demo 03: Doppler Resolution", "Color", "w");
tiledlayout(numel(pulseCounts), 1, "Padding", "compact", "TileSpacing", "compact");

for iCount = 1:numel(pulseCounts)
    Np = pulseCounts(iCount);
    p = 0:Np-1;

    slowSignal = complex(zeros(1, Np));
    for iTarget = 1:numel(targetVelocities)
        fD = 2 * targetVelocities(iTarget) / lambda;
        slowSignal = slowSignal + targetAmplitudes(iTarget) ...
            * exp(1j * 2 * pi * fD * p * PRI);
    end

    slowTimeWindow = 0.5 - 0.5 * cos(2 * pi * p / (Np-1));
    dopplerSpectrum = fftshift(fft(slowSignal .* slowTimeWindow));

    dopplerAxis = (-Np/2:Np/2-1) * PRF / Np;
    velocityAxis = lambda * dopplerAxis / 2;

    spectrumDB = 20 * log10(abs(dopplerSpectrum) / max(abs(dopplerSpectrum)) + eps);
    velocityBinSpacing = lambda * PRF / (2 * Np);

    fprintf("Np = %d: velocity bin spacing = %.2f m/s\n", ...
        Np, velocityBinSpacing);

    nexttile;
    plot(velocityAxis, spectrumDB, "LineWidth", 1.3);
    grid on;
    hold on;
    xline(targetVelocities(1), "--", "v1", "LabelVerticalAlignment", "bottom");
    xline(targetVelocities(2), "--", "v2", "LabelVerticalAlignment", "bottom");
    xlabel("Velocity (m/s)");
    ylabel("Normalized magnitude (dB)");
    title(sprintf("Np = %d, velocity bin spacing = %.2f m/s", ...
        Np, velocityBinSpacing));
    xlim([20, 42]);
    ylim([-45, 3]);
end

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_03_doppler_resolution_two_targets.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

