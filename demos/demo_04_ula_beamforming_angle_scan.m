%% demo_04_ula_beamforming_angle_scan
% Spatial matched filtering / conventional beamforming for a ULA snapshot.

clear; close all; clc;

%% Scenario
c = 299792458;
fc = 10e9;
lambda = c / fc;

M = 8;                      % number of array elements
d = lambda / 2;             % element spacing
targetAngleDeg = 20;        % broadside-referenced angle, deg
SNRdB = 25;

elementIndex = (0:M-1).';

steer = @(thetaDeg) exp(-1j * 2 * pi * elementIndex * d ...
    .* sind(thetaDeg) / lambda);

targetSteering = steer(targetAngleDeg);

rng(11);
signalPower = mean(abs(targetSteering).^2);
noisePower = signalPower / 10^(SNRdB / 10);
noise = sqrt(noisePower / 2) * (randn(M, 1) + 1j * randn(M, 1));
arraySnapshot = targetSteering + noise;

%% Angle scan: matched filter each candidate steering vector
scanAnglesDeg = -90:0.05:90;
beamResponse = zeros(size(scanAnglesDeg));

for iAngle = 1:numel(scanAnglesDeg)
    candidateSteering = steer(scanAnglesDeg(iAngle));
    beamResponse(iAngle) = abs(candidateSteering' * arraySnapshot) / M;
end

beamResponseDB = 20 * log10(beamResponse / max(beamResponse) + eps);
[~, peakIndex] = max(beamResponse);
estimatedAngleDeg = scanAnglesDeg(peakIndex);

fprintf("Target angle: %.2f deg\n", targetAngleDeg);
fprintf("Estimated angle: %.2f deg\n", estimatedAngleDeg);
fprintf("Element spacing: %.2f lambda\n", d / lambda);

%% Plot spatial phase and beam response
figure("Name", "Demo 04: ULA Beamforming Angle Scan", "Color", "w");
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
stem(elementIndex, unwrap(angle(arraySnapshot)), "filled", "LineWidth", 1.2);
grid on;
xlabel("Array element index");
ylabel("Unwrapped phase (rad)");
title("Received spatial phase");

nexttile;
plot(scanAnglesDeg, beamResponseDB, "LineWidth", 1.3);
grid on;
hold on;
xline(targetAngleDeg, "--", "Truth", "LabelVerticalAlignment", "bottom");
plot(estimatedAngleDeg, beamResponseDB(peakIndex), "ro", ...
    "MarkerSize", 7, "LineWidth", 1.4);
xlabel("Scan angle (deg)");
ylabel("Normalized response (dB)");
title("Conventional beamforming scan");
xlim([-90, 90]);
ylim([-45, 3]);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_04_ula_beamforming_angle_scan.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

