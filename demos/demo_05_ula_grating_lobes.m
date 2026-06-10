%% demo_05_ula_grating_lobes
% Show spatial aliasing / grating lobes when ULA spacing is too large.

clear; close all; clc;

%% Scenario
c = 299792458;
fc = 10e9;
lambda = c / fc;

M = 16;
targetAngleDeg = 30;
spacingList = [lambda/2, lambda];
scanAnglesDeg = -90:0.05:90;
elementIndex = (0:M-1).';

figure("Name", "Demo 05: ULA Grating Lobes", "Color", "w");
tiledlayout(numel(spacingList), 1, "Padding", "compact", "TileSpacing", "compact");

for iSpacing = 1:numel(spacingList)
    d = spacingList(iSpacing);

    steer = @(thetaDeg) exp(-1j * 2 * pi * elementIndex * d ...
        .* sind(thetaDeg) / lambda);

    arraySnapshot = steer(targetAngleDeg);
    beamResponse = zeros(size(scanAnglesDeg));

    for iAngle = 1:numel(scanAnglesDeg)
        candidateSteering = steer(scanAnglesDeg(iAngle));
        beamResponse(iAngle) = abs(candidateSteering' * arraySnapshot) / M;
    end

    beamResponseDB = 20 * log10(beamResponse / max(beamResponse) + eps);
    truthResponseDB = interp1(scanAnglesDeg, beamResponseDB, targetAngleDeg);
    aliasResponseDB = interp1(scanAnglesDeg, beamResponseDB, -targetAngleDeg);

    fprintf("d = %.1f lambda: response at %+g deg = %.2f dB, at %+g deg = %.2f dB\n", ...
        d / lambda, targetAngleDeg, truthResponseDB, -targetAngleDeg, aliasResponseDB);

    nexttile;
    plot(scanAnglesDeg, beamResponseDB, "LineWidth", 1.3);
    grid on;
    hold on;
    xline(targetAngleDeg, "--", "Truth", "LabelVerticalAlignment", "bottom");
    xline(-targetAngleDeg, ":", "Alias candidate", ...
        "LabelVerticalAlignment", "bottom");
    xlabel("Scan angle (deg)");
    ylabel("Normalized response (dB)");
    title(sprintf("M = %d, d = %.1f\\lambda, target = %d deg", ...
        M, d / lambda, targetAngleDeg));
    xlim([-90, 90]);
    ylim([-55, 3]);
end

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_05_ula_grating_lobes.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

