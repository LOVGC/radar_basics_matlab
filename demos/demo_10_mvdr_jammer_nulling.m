%% demo_10_mvdr_jammer_nulling
% Compare conventional beamforming and MVDR in a strong jammer scenario.

clear; close all; clc;

%% Scenario
c = 299792458;
fc = 10e9;
lambda = c / fc;

M = 16;
d = lambda / 2;
lookAngleDeg = 20;
jammerAngleDeg = -30;
Nsnapshots = 500;
jammerPowerDB = 40;         % jammer-to-noise ratio per element, dB
diagonalLoadingFactor = 1e-3;

elementIndex = (0:M-1).';
steer = @(thetaDeg) exp(-1j * 2 * pi * elementIndex * d ...
    .* sind(thetaDeg) / lambda);

aLook = steer(lookAngleDeg);
aJammer = steer(jammerAngleDeg);

%% Estimate covariance from jammer-plus-noise training snapshots
rng(41);
jammerPower = 10^(jammerPowerDB / 10);
jammerSignal = sqrt(jammerPower) ...
    * (randn(1, Nsnapshots) + 1j * randn(1, Nsnapshots)) / sqrt(2);
noise = (randn(M, Nsnapshots) + 1j * randn(M, Nsnapshots)) / sqrt(2);

Xtraining = aJammer * jammerSignal + noise;
Rhat = (Xtraining * Xtraining') / Nsnapshots;
diagonalLoading = diagonalLoadingFactor * trace(Rhat) / M;
Rloaded = Rhat + diagonalLoading * eye(M);

%% Conventional and MVDR weights
wConventional = aLook / (aLook' * aLook);

RinvALook = Rloaded \ aLook;
wMvdr = RinvALook / (aLook' * RinvALook);

fprintf("Look direction: %.2f deg\n", lookAngleDeg);
fprintf("Jammer direction: %.2f deg\n", jammerAngleDeg);
fprintf("Jammer-to-noise ratio: %.1f dB\n", jammerPowerDB);
fprintf("Conventional look gain: %.2f dB\n", ...
    20 * log10(abs(wConventional' * aLook) + eps));
fprintf("MVDR look gain: %.2f dB\n", ...
    20 * log10(abs(wMvdr' * aLook) + eps));
fprintf("Conventional jammer gain: %.2f dB\n", ...
    20 * log10(abs(wConventional' * aJammer) + eps));
fprintf("MVDR jammer gain: %.2f dB\n", ...
    20 * log10(abs(wMvdr' * aJammer) + eps));

%% Beampattern scan
scanAnglesDeg = -90:0.05:90;
conventionalPattern = zeros(size(scanAnglesDeg));
mvdrPattern = zeros(size(scanAnglesDeg));

for iAngle = 1:numel(scanAnglesDeg)
    candidateSteering = steer(scanAnglesDeg(iAngle));
    conventionalPattern(iAngle) = abs(wConventional' * candidateSteering);
    mvdrPattern(iAngle) = abs(wMvdr' * candidateSteering);
end

conventionalPatternDB = 20 * log10(conventionalPattern + eps);
mvdrPatternDB = 20 * log10(mvdrPattern + eps);

%% Capon/MVDR spatial spectrum for reference
% This spectrum estimates high-power spatial directions in R; here it peaks
% at the jammer, while the left plot shows MVDR weights steered to the look.
mvdrSpectrum = zeros(size(scanAnglesDeg));
for iAngle = 1:numel(scanAnglesDeg)
    candidateSteering = steer(scanAnglesDeg(iAngle));
    RinvA = Rloaded \ candidateSteering;
    mvdrSpectrum(iAngle) = 1 / real(candidateSteering' * RinvA);
end
mvdrSpectrumDB = 10 * log10(mvdrSpectrum / max(mvdrSpectrum) + eps);

%% Plots
figure("Name", "Demo 10: MVDR Jammer Nulling", "Color", "w");
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(scanAnglesDeg, conventionalPatternDB, "LineWidth", 1.3);
grid on;
hold on;
plot(scanAnglesDeg, mvdrPatternDB, "LineWidth", 1.3);
xline(lookAngleDeg, "--", "Look", "LabelVerticalAlignment", "bottom");
xline(jammerAngleDeg, ":", "Jammer", "LabelVerticalAlignment", "bottom");
xlabel("Angle (deg)");
ylabel("Array gain (dB)");
title("Beampattern toward look direction");
legend("Conventional", "MVDR", "Location", "southoutside");
xlim([-90, 90]);
ylim([-90, 10]);

nexttile;
plot(scanAnglesDeg, mvdrSpectrumDB, "LineWidth", 1.3);
grid on;
hold on;
xline(lookAngleDeg, "--", "Look", "LabelVerticalAlignment", "bottom");
xline(jammerAngleDeg, ":", "Jammer", "LabelVerticalAlignment", "bottom");
xlabel("Scan angle (deg)");
ylabel("Normalized Capon spectrum (dB)");
title("Capon spectrum: strongest covariance direction");
xlim([-90, 90]);
ylim([-60, 3]);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_10_mvdr_jammer_nulling.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);
