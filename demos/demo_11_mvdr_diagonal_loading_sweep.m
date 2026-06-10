%% demo_11_mvdr_diagonal_loading_sweep
% Sweep diagonal loading to show the MVDR stability/null-depth tradeoff.

clear; close all; clc;

%% Scenario
c = 299792458;
fc = 10e9;
lambda = c / fc;

M = 16;
d = lambda / 2;
lookAngleDeg = 20;
jammerAngleDeg = -30;
Nsnapshots = 80;            % deliberately modest to make loading relevant
jammerPowerDB = 40;
loadingFactors = [1e-6, 1e-2, 1e1];

elementIndex = (0:M-1).';
steer = @(thetaDeg) exp(-1j * 2 * pi * elementIndex * d ...
    .* sind(thetaDeg) / lambda);

aLook = steer(lookAngleDeg);
aJammer = steer(jammerAngleDeg);

%% Estimate covariance from jammer-plus-noise training snapshots
rng(43);
jammerPower = 10^(jammerPowerDB / 10);
jammerSignal = sqrt(jammerPower) ...
    * (randn(1, Nsnapshots) + 1j * randn(1, Nsnapshots)) / sqrt(2);
noise = (randn(M, Nsnapshots) + 1j * randn(M, Nsnapshots)) / sqrt(2);

Xtraining = aJammer * jammerSignal + noise;
Rhat = (Xtraining * Xtraining') / Nsnapshots;

wConventional = aLook / (aLook' * aLook);

scanAnglesDeg = -90:0.05:90;
conventionalPattern = zeros(size(scanAnglesDeg));
for iAngle = 1:numel(scanAnglesDeg)
    conventionalPattern(iAngle) = abs(wConventional' * steer(scanAnglesDeg(iAngle)));
end
conventionalPatternDB = 20 * log10(conventionalPattern + eps);

fprintf("Look direction: %.2f deg\n", lookAngleDeg);
fprintf("Jammer direction: %.2f deg\n", jammerAngleDeg);
fprintf("Snapshots: %d\n", Nsnapshots);
fprintf("Conventional jammer gain: %.2f dB\n", ...
    20 * log10(abs(wConventional' * aJammer) + eps));

%% Sweep diagonal loading
mvdrPatternsDB = zeros(numel(loadingFactors), numel(scanAnglesDeg));
jammerGainsDB = zeros(size(loadingFactors));

for iLoading = 1:numel(loadingFactors)
    loadingFactor = loadingFactors(iLoading);
    diagonalLoading = loadingFactor * trace(Rhat) / M;
    Rloaded = Rhat + diagonalLoading * eye(M);

    RinvALook = Rloaded \ aLook;
    wMvdr = RinvALook / (aLook' * RinvALook);

    jammerGainsDB(iLoading) = 20 * log10(abs(wMvdr' * aJammer) + eps);

    for iAngle = 1:numel(scanAnglesDeg)
        candidateSteering = steer(scanAnglesDeg(iAngle));
        mvdrPatternsDB(iLoading, iAngle) = 20 ...
            * log10(abs(wMvdr' * candidateSteering) + eps);
    end

    fprintf("Loading factor %.0e: jammer gain %.2f dB\n", ...
        loadingFactor, jammerGainsDB(iLoading));
end

%% Plot
figure("Name", "Demo 11: MVDR Diagonal Loading Sweep", "Color", "w");
plot(scanAnglesDeg, conventionalPatternDB, "k--", "LineWidth", 1.2);
grid on;
hold on;

for iLoading = 1:numel(loadingFactors)
    plot(scanAnglesDeg, mvdrPatternsDB(iLoading, :), "LineWidth", 1.3);
end

xline(lookAngleDeg, "--", "Look", "LabelVerticalAlignment", "bottom");
xline(jammerAngleDeg, ":", "Jammer", "LabelVerticalAlignment", "bottom");
xlabel("Angle (deg)");
ylabel("Array gain (dB)");
title("MVDR diagonal loading sweep");
legendEntries = ["Conventional", "MVDR loading 1e-6", ...
    "MVDR loading 1e-2", "MVDR loading 1e1"];
legend(legendEntries, "Location", "southoutside");
xlim([-90, 90]);
ylim([-100, 10]);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_11_mvdr_diagonal_loading_sweep.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);
