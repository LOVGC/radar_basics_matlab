%% demo_09_music_two_targets
% Compare conventional beamforming and MUSIC for two close ULA targets.

clear; close all; clc;

%% Scenario
c = 299792458;
fc = 10e9;
lambda = c / fc;

M = 16;
d = lambda / 2;
Ksources = 2;
targetAnglesDeg = [20, 28];
Nsnapshots = 200;
SNRdB = 20;

elementIndex = (0:M-1).';
steer = @(thetaDeg) exp(-1j * 2 * pi * elementIndex * d ...
    .* sind(thetaDeg) / lambda);

A = complex(zeros(M, Ksources));
for k = 1:Ksources
    A(:, k) = steer(targetAnglesDeg(k));
end

%% Multiple snapshots with uncorrelated source waveforms
rng(31);
sourceSignals = (randn(Ksources, Nsnapshots) ...
    + 1j * randn(Ksources, Nsnapshots)) / sqrt(2);
cleanSnapshots = A * sourceSignals;

signalPower = mean(abs(cleanSnapshots(:)).^2);
noisePower = signalPower / 10^(SNRdB / 10);
noise = sqrt(noisePower / 2) ...
    * (randn(M, Nsnapshots) + 1j * randn(M, Nsnapshots));
X = cleanSnapshots + noise;

Rhat = (X * X') / Nsnapshots;
[eigenVectors, eigenValuesMatrix] = eig(Rhat, "vector");
[eigenValues, sortIndex] = sort(real(eigenValuesMatrix), "descend");
eigenVectors = eigenVectors(:, sortIndex);

signalSubspace = eigenVectors(:, 1:Ksources);
noiseSubspace = eigenVectors(:, Ksources+1:end);

fprintf("M = %d, K = %d, snapshots = %d\n", M, Ksources, Nsnapshots);
fprintf("Signal subspace dimension: %d\n", size(signalSubspace, 2));
fprintf("Noise subspace dimension: %d\n", size(noiseSubspace, 2));
fprintf("Largest eigenvalues: %.2f, %.2f, %.2f\n", ...
    eigenValues(1), eigenValues(2), eigenValues(3));

%% Scan angle
scanAnglesDeg = -20:0.02:60;
beamResponse = zeros(size(scanAnglesDeg));
musicSpectrum = zeros(size(scanAnglesDeg));

for iAngle = 1:numel(scanAnglesDeg)
    candidateSteering = steer(scanAnglesDeg(iAngle));

    beamResponse(iAngle) = real(candidateSteering' * Rhat ...
        * candidateSteering) / M^2;

    denominator = norm(noiseSubspace' * candidateSteering)^2;
    musicSpectrum(iAngle) = 1 / max(denominator, eps);
end

beamResponseDB = 10 * log10(beamResponse / max(beamResponse) + eps);
musicSpectrumDB = 10 * log10(musicSpectrum / max(musicSpectrum) + eps);

%% Plots
figure("Name", "Demo 09: MUSIC Two Targets", "Color", "w");
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(scanAnglesDeg, beamResponseDB, "LineWidth", 1.3);
grid on;
hold on;
xline(targetAnglesDeg(1), "--", "T1", "LabelVerticalAlignment", "bottom");
xline(targetAnglesDeg(2), "--", "T2", "LabelVerticalAlignment", "bottom");
xlabel("Scan angle (deg)");
ylabel("Normalized response (dB)");
title("Conventional beamforming");
xlim([0, 45]);
ylim([-45, 3]);

nexttile;
plot(scanAnglesDeg, musicSpectrumDB, "LineWidth", 1.3);
grid on;
hold on;
xline(targetAnglesDeg(1), "--", "T1", "LabelVerticalAlignment", "bottom");
xline(targetAnglesDeg(2), "--", "T2", "LabelVerticalAlignment", "bottom");
xlabel("Scan angle (deg)");
ylabel("Normalized pseudospectrum (dB)");
title("MUSIC pseudospectrum");
xlim([0, 45]);
ylim([-45, 3]);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_09_music_two_targets.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

