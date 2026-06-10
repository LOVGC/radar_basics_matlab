%% demo_08_angle_resolution_m_vs_nfft
% Show that Nfft interpolates the spatial spectrum, while M/aperture
% controls physical angle resolution.

clear; close all; clc;

%% Scenario
c = 299792458;
fc = 10e9;
lambda = c / fc;
d = lambda / 2;

targetAnglesDeg = [20, 28];
targetAmplitudes = [1.0, 0.9];
cases = [
    struct("M", 16, "Nfft", 16,   "Label", "M = 16, Nfft = 16")
    struct("M", 16, "Nfft", 4096, "Label", "M = 16, Nfft = 4096")
    struct("M", 32, "Nfft", 4096, "Label", "M = 32, Nfft = 4096")
];

figure("Name", "Demo 08: Angle Resolution, M vs Nfft", "Color", "w");
tiledlayout(numel(cases), 1, "Padding", "compact", "TileSpacing", "compact");

for iCase = 1:numel(cases)
    M = cases(iCase).M;
    Nfft = cases(iCase).Nfft;
    elementIndex = (0:M-1).';

    steer = @(thetaDeg) exp(-1j * 2 * pi * elementIndex * d ...
        .* sind(thetaDeg) / lambda);

    arraySnapshot = complex(zeros(M, 1));
    for iTarget = 1:numel(targetAnglesDeg)
        arraySnapshot = arraySnapshot + targetAmplitudes(iTarget) ...
            * steer(targetAnglesDeg(iTarget));
    end

    spatialSpectrum = fftshift(fft(conj(arraySnapshot), Nfft));
    uAxis = (-Nfft/2:Nfft/2-1) / Nfft;
    validAngleMask = abs(uAxis * lambda / d) <= 1;
    thetaAxis = nan(size(uAxis));
    thetaAxis(validAngleMask) = asind(uAxis(validAngleMask) * lambda / d);

    spectrumDB = 20 * log10(abs(spatialSpectrum) ...
        / max(abs(spatialSpectrum)) + eps);

    approximateResolutionDeg = rad2deg((lambda / (M * d)) ...
        / cosd(mean(targetAnglesDeg)));

    fprintf("%s: approximate angle resolution near %.1f deg is %.2f deg\n", ...
        cases(iCase).Label, mean(targetAnglesDeg), approximateResolutionDeg);

    nexttile;
    if Nfft == M
        stem(thetaAxis(validAngleMask), spectrumDB(validAngleMask), ...
            "filled", "LineWidth", 1.1);
    else
        plot(thetaAxis(validAngleMask), spectrumDB(validAngleMask), ...
            "LineWidth", 1.3);
    end
    grid on;
    hold on;
    xline(targetAnglesDeg(1), "--", "T1", "LabelVerticalAlignment", "bottom");
    xline(targetAnglesDeg(2), "--", "T2", "LabelVerticalAlignment", "bottom");
    xlabel("Angle mapped from spatial frequency (deg)");
    ylabel("Normalized response (dB)");
    title(sprintf("%s, approx \\Delta\\theta = %.1f deg", ...
        cases(iCase).Label, approximateResolutionDeg));
    xlim([0, 50]);
    ylim([-45, 3]);
end

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_08_angle_resolution_m_vs_nfft.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

