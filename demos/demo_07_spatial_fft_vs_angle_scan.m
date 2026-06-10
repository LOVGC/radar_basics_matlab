%% demo_07_spatial_fft_vs_angle_scan
% Compare conventional ULA angle scan with spatial FFT.

clear; close all; clc;

%% Scenario
c = 299792458;
fc = 10e9;
lambda = c / fc;

M = 16;
d = lambda / 2;
targetAngleDeg = 30;
SNRdB = 25;
Nfft = 4096;

elementIndex = (0:M-1).';
steer = @(thetaDeg) exp(-1j * 2 * pi * elementIndex * d ...
    .* sind(thetaDeg) / lambda);

targetSteering = steer(targetAngleDeg);
targetU = d * sind(targetAngleDeg) / lambda;

rng(23);
signalPower = mean(abs(targetSteering).^2);
noisePower = signalPower / 10^(SNRdB / 10);
noise = sqrt(noisePower / 2) * (randn(M, 1) + 1j * randn(M, 1));
arraySnapshot = targetSteering + noise;

%% Conventional angle scan: response(theta) = |a(theta)^H x|
scanAnglesDeg = -90:0.05:90;
beamResponse = zeros(size(scanAnglesDeg));

for iAngle = 1:numel(scanAnglesDeg)
    candidateSteering = steer(scanAnglesDeg(iAngle));
    beamResponse(iAngle) = abs(candidateSteering' * arraySnapshot) / M;
end

beamResponseDB = 20 * log10(beamResponse / max(beamResponse) + eps);
[~, anglePeakIndex] = max(beamResponse);
estimatedAngleScanDeg = scanAnglesDeg(anglePeakIndex);

%% Spatial FFT over array elements
% With the steering convention exp(-j*2*pi*m*u), fft(conj(x)) peaks at +u.
spatialSpectrum = fftshift(fft(conj(arraySnapshot), Nfft));
uAxis = (-Nfft/2:Nfft/2-1) / Nfft;
spatialSpectrumDB = 20 * log10(abs(spatialSpectrum) ...
    / max(abs(spatialSpectrum)) + eps);

validAngleMask = abs(uAxis * lambda / d) <= 1;
thetaAxisFromU = nan(size(uAxis));
thetaAxisFromU(validAngleMask) = asind(uAxis(validAngleMask) * lambda / d);

[~, fftPeakIndex] = max(abs(spatialSpectrum(validAngleMask)));
validIndices = find(validAngleMask);
fftPeakIndex = validIndices(fftPeakIndex);
estimatedU = uAxis(fftPeakIndex);
estimatedAngleFftDeg = asind(estimatedU * lambda / d);

fprintf("Truth angle: %.2f deg\n", targetAngleDeg);
fprintf("Truth spatial frequency u: %.4f cycles/element\n", targetU);
fprintf("Angle-scan estimate: %.2f deg\n", estimatedAngleScanDeg);
fprintf("Spatial-FFT estimate: u = %.4f, angle = %.2f deg\n", ...
    estimatedU, estimatedAngleFftDeg);

%% Plots
figure("Name", "Demo 07: Spatial FFT vs Angle Scan", "Color", "w");
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(scanAnglesDeg, beamResponseDB, "LineWidth", 1.3);
grid on;
hold on;
xline(targetAngleDeg, "--", "Truth", "LabelVerticalAlignment", "bottom");
plot(estimatedAngleScanDeg, beamResponseDB(anglePeakIndex), "ro", ...
    "MarkerSize", 7, "LineWidth", 1.4);
xlabel("Scan angle (deg)");
ylabel("Normalized response (dB)");
title("Conventional angle scan");
xlim([-90, 90]);
ylim([-45, 3]);

nexttile;
plot(thetaAxisFromU, spatialSpectrumDB, "LineWidth", 1.3);
grid on;
hold on;
xline(targetAngleDeg, "--", "Truth", "LabelVerticalAlignment", "bottom");
plot(estimatedAngleFftDeg, spatialSpectrumDB(fftPeakIndex), "ro", ...
    "MarkerSize", 7, "LineWidth", 1.4);
xlabel("Angle mapped from spatial frequency (deg)");
ylabel("Normalized response (dB)");
title("Spatial FFT");
xlim([-90, 90]);
ylim([-45, 3]);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_07_spatial_fft_vs_angle_scan.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

