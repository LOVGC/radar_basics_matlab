%% demo_25_temporal_clutter_map_tradeoff
% Compare temporal clutter-map update rules under drifting clutter.
%
% Demo 24 used a static target-free clutter map. This demo moves one level
% closer to the research question: if the clutter ridge drifts in Doppler,
% a static map becomes stale; if the map adapts too quickly, a persistent
% slow target can be absorbed into the background estimate.
%
% To focus on the background-modeling problem, this demo works directly on
% synthetic range-Doppler power maps. Think of each frame as the output of:
%
%   x[fast time, slow time, array element]
%     -> matched filtering
%     -> MTI / Doppler FFT
%     -> RD power statistic

clear; close all; clc;

%% Scenario parameters
numRangeBins = 150;
numDopplerBins = 121;
rangeAxisKm = linspace(1.0, 8.5, numRangeBins).';
velocityAxis = linspace(-15, 15, numDopplerBins);

numFrames = 90;
KWindow = 21;
staticMapFrames = 1:KWindow;
calibrationFrames = 50:75;
currentFrame = 82;

initialClutterCenterMps = 0.0;
finalClutterCenterMps = 3.0;
clutterDopplerSpreadMps = 2.0;
clutterPowerScale = 18;
noisePower = 1.0;

targetRangeKm = 5.25;
targetVelocityMps = 2.0;
targetAmplitude = 600;
targetRangeSigmaBins = 1.2;
targetVelocitySigmaMps = 0.45;

targetPfa = 1e-3;
fixedMaskHalfWidthMps = 5.0;
quantileLevel = 0.25;
persistenceValues = 0:KWindow;

rng(251);

fprintf("Demo 25: temporal clutter-map tradeoff\n");
fprintf("Recent-history window K: %d frames\n", KWindow);
fprintf("Clutter ridge drift: %.1f -> %.1f m/s over %d frames\n", ...
    initialClutterCenterMps, finalClutterCenterMps, numFrames);
fprintf("Target: range %.2f km, velocity %.2f m/s\n", ...
    targetRangeKm, targetVelocityMps);
fprintf("Calibration target Pfa: %.1e\n", targetPfa);
fprintf("Median absorption boundary: T > K/2 = %.1f frames\n", KWindow / 2);
fprintf("q=%.2f absorption boundary: T > %.1f frames\n", ...
    quantileLevel, (1 - quantileLevel) * KWindow);

%% Target-free drifting clutter sequence
[targetFreePower, clutterCenters] = localBuildTargetFreeSequence( ...
    numRangeBins, velocityAxis, numFrames, initialClutterCenterMps, ...
    finalClutterCenterMps, clutterDopplerSpreadMps, clutterPowerScale, ...
    noisePower);
fprintf("Current frame clutter center: %.2f m/s\n", clutterCenters(currentFrame));

targetMap = localBuildTargetMap(rangeAxisKm, velocityAxis, targetRangeKm, ...
    targetVelocityMps, targetRangeSigmaBins, targetVelocitySigmaMps, ...
    targetAmplitude);
[~, targetRangeIndex] = min(abs(rangeAxisKm - targetRangeKm));
[~, targetVelocityIndex] = min(abs(velocityAxis - targetVelocityMps));

staticMeanMap = mean(targetFreePower(:, :, staticMapFrames), 3);
backgroundFloor = 0.05 * median(staticMeanMap(:));

methodNames = ["static mean"; "recent mean"; "recent median"; "recent q25"];
numMethods = numel(methodNames);

%% Calibrate each detector on target-free frames
thresholdDb = zeros(numMethods, 1);
empiricalPfa = zeros(numMethods, 1);

for iMethod = 1:numMethods
    calibrationScores = [];
    for frameIndex = calibrationFrames
        historyCube = targetFreePower(:, :, frameIndex-KWindow:frameIndex-1);
        backgroundMap = localEstimateBackground(methodNames(iMethod), ...
            staticMeanMap, historyCube, quantileLevel);
        scoreDb = localSurpriseDb(targetFreePower(:, :, frameIndex), ...
            backgroundMap, backgroundFloor);
        calibrationScores = [calibrationScores; scoreDb(:)]; %#ok<AGROW>
    end

    thresholdDb(iMethod) = localVectorQuantile(calibrationScores, 1 - targetPfa);
    empiricalPfa(iMethod) = mean(calibrationScores > thresholdDb(iMethod));
end

%% Sweep target persistence in the recent-history window
targetMarginDb = zeros(numel(persistenceValues), numMethods);
targetBackground = zeros(numel(persistenceValues), numMethods);
targetDetected = false(numel(persistenceValues), numMethods);
currentTargetPower = targetFreePower(:, :, currentFrame) + targetMap;

for iPersistence = 1:numel(persistenceValues)
    persistenceLength = persistenceValues(iPersistence);
    sequenceWithTarget = targetFreePower;

    contaminatedFrames = currentFrame-persistenceLength:currentFrame;
    contaminatedFrames = contaminatedFrames(contaminatedFrames >= 1);
    for frameIndex = contaminatedFrames
        sequenceWithTarget(:, :, frameIndex) = sequenceWithTarget(:, :, frameIndex) ...
            + targetMap;
    end

    historyCube = sequenceWithTarget(:, :, currentFrame-KWindow:currentFrame-1);

    for iMethod = 1:numMethods
        backgroundMap = localEstimateBackground(methodNames(iMethod), ...
            staticMeanMap, historyCube, quantileLevel);
        scoreDb = localSurpriseDb(currentTargetPower, backgroundMap, backgroundFloor);
        targetScoreDb = scoreDb(targetRangeIndex, targetVelocityIndex);

        targetMarginDb(iPersistence, iMethod) = targetScoreDb - thresholdDb(iMethod);
        targetBackground(iPersistence, iMethod) = backgroundMap( ...
            targetRangeIndex, targetVelocityIndex);
        targetDetected(iPersistence, iMethod) = targetMarginDb(iPersistence, iMethod) > 0;
    end
end

fixedMaskReportsSlowTarget = abs(targetVelocityMps) > fixedMaskHalfWidthMps;

summaryTable = localBuildSummaryTable(methodNames, thresholdDb, empiricalPfa, ...
    persistenceValues, targetMarginDb, targetDetected);

fprintf("\nCalibrated detector summary:\n");
disp(summaryTable);
fprintf("Fixed Doppler report mask |v| <= %.1f m/s reports slow target: %d\n", ...
    fixedMaskHalfWidthMps, fixedMaskReportsSlowTarget);

%% Example maps for the current frame with no target contamination in history
targetFreeHistory = targetFreePower(:, :, currentFrame-KWindow:currentFrame-1);
recentMedianMap = localEstimateBackground("recent median", staticMeanMap, ...
    targetFreeHistory, quantileLevel);

%% Plots
figure("Name", "Demo 25: Temporal Clutter Map Tradeoff", "Color", "w", ...
    "Position", [50, 70, 1480, 820]);
tiledlayout(2, 3, "Padding", "compact", "TileSpacing", "compact");

nexttile;
localPlotPowerMap(velocityAxis, rangeAxisKm, currentTargetPower, ...
    "Current RD power: drifted clutter + target", targetVelocityMps, ...
    targetRangeKm, fixedMaskHalfWidthMps);

nexttile;
localPlotPowerMap(velocityAxis, rangeAxisKm, staticMeanMap, ...
    "Static mean map: old clutter near 0 m/s", targetVelocityMps, ...
    targetRangeKm, fixedMaskHalfWidthMps);

nexttile;
localPlotPowerMap(velocityAxis, rangeAxisKm, recentMedianMap, ...
    "Recent median map: tracks drift", targetVelocityMps, ...
    targetRangeKm, fixedMaskHalfWidthMps);

nexttile;
localPlotMarginCurves(persistenceValues, targetMarginDb, methodNames, KWindow, ...
    quantileLevel);

nexttile;
localPlotBackgroundCurves(persistenceValues, targetBackground, methodNames, ...
    currentTargetPower(targetRangeIndex, targetVelocityIndex), KWindow, quantileLevel);

nexttile;
localPlotThresholdSummary(methodNames, thresholdDb, empiricalPfa, targetPfa);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_25_temporal_clutter_map_tradeoff.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

%% Local functions
function [powerCube, clutterCenters] = localBuildTargetFreeSequence( ...
    numRangeBins, velocityAxis, numFrames, initialCenter, finalCenter, ...
    dopplerSpread, clutterPowerScale, noisePower)

    numDopplerBins = numel(velocityAxis);
    powerCube = zeros(numRangeBins, numDopplerBins, numFrames);
    clutterCenters = linspace(initialCenter, finalCenter, numFrames);

    rangeIndex = (1:numRangeBins).';
    rangeTexture = 0.45 ...
        + 1.15 * exp(-0.5 * ((rangeIndex - 70) / 18).^2) ...
        + 0.75 * exp(-0.5 * ((rangeIndex - 112) / 10).^2) ...
        + 0.25 * rand(numRangeBins, 1);
    rangeTexture = rangeTexture / median(rangeTexture);

    for frameIndex = 1:numFrames
        center = clutterCenters(frameIndex);
        ridge = exp(-0.5 * ((velocityAxis - center) / dopplerSpread).^2);
        weakWideClutter = 0.22 * exp(-0.5 * (velocityAxis / 8).^2);
        meanPower = noisePower + clutterPowerScale * rangeTexture ...
            * (ridge + weakWideClutter);

        slowPowerScale = 1 + 0.08 * sin(2 * pi * frameIndex / 23);
        speckle = -log(max(rand(numRangeBins, numDopplerBins), realmin));
        powerCube(:, :, frameIndex) = slowPowerScale * meanPower .* speckle;
    end
end

function targetMap = localBuildTargetMap(rangeAxisKm, velocityAxis, targetRangeKm, ...
    targetVelocityMps, rangeSigmaBins, velocitySigmaMps, targetAmplitude)

    [~, rangeIndex] = min(abs(rangeAxisKm - targetRangeKm));
    rangeGrid = (1:numel(rangeAxisKm)).';
    rangeShape = exp(-0.5 * ((rangeGrid - rangeIndex) / rangeSigmaBins).^2);
    velocityShape = exp(-0.5 * ((velocityAxis - targetVelocityMps) ...
        / velocitySigmaMps).^2);
    targetMap = targetAmplitude * rangeShape * velocityShape;
end

function backgroundMap = localEstimateBackground(methodName, staticMeanMap, ...
    historyCube, quantileLevel)

    switch methodName
        case "static mean"
            backgroundMap = staticMeanMap;
        case "recent mean"
            backgroundMap = mean(historyCube, 3);
        case "recent median"
            backgroundMap = localQuantileAlong3(historyCube, 0.50);
        case "recent q25"
            backgroundMap = localQuantileAlong3(historyCube, quantileLevel);
        otherwise
            error("Unknown background method: %s", methodName);
    end
end

function scoreDb = localSurpriseDb(currentPower, backgroundMap, backgroundFloor)
    scoreDb = 10 * log10(currentPower ./ (backgroundMap + backgroundFloor) + eps);
end

function quantileMap = localQuantileAlong3(dataCube, q)
    sortedCube = sort(dataCube, 3, "ascend");
    numSamples = size(sortedCube, 3);
    quantileIndex = min(numSamples, max(1, ceil(q * numSamples)));
    quantileMap = sortedCube(:, :, quantileIndex);
end

function value = localVectorQuantile(values, q)
    sortedValues = sort(values(:), "ascend");
    quantileIndex = min(numel(sortedValues), max(1, ceil(q * numel(sortedValues))));
    value = sortedValues(quantileIndex);
end

function summaryTable = localBuildSummaryTable(methodNames, thresholdDb, ...
    empiricalPfa, persistenceValues, targetMarginDb, targetDetected)

    marginAtT0Db = targetMarginDb(1, :).';
    marginAtKDb = targetMarginDb(end, :).';
    firstMissT = nan(numel(methodNames), 1);

    for iMethod = 1:numel(methodNames)
        missIndex = find(~targetDetected(:, iMethod), 1, "first");
        if ~isempty(missIndex)
            firstMissT(iMethod) = persistenceValues(missIndex);
        end
    end

    summaryTable = table(methodNames, thresholdDb, empiricalPfa, ...
        marginAtT0Db, marginAtKDb, firstMissT, 'VariableNames', { ...
        'method', 'thresholdDb', 'empiricalPfa', 'marginAtT0Db', ...
        'marginAtKDb', 'firstMissT'});
end

function localPlotPowerMap(velocityAxis, rangeAxisKm, powerMap, plotTitle, ...
    targetVelocityMps, targetRangeKm, fixedMaskHalfWidthMps)

    powerDb = 10 * log10(powerMap / max(powerMap(:)) + eps);
    imagesc(velocityAxis, rangeAxisKm, powerDb);
    axis xy;
    colorbar;
    clim([-45, 0]);
    xlabel("Velocity (m/s)");
    ylabel("Range (km)");
    title(plotTitle);
    hold on;
    plot(targetVelocityMps, targetRangeKm, "c^", "MarkerSize", 8, ...
        "LineWidth", 1.6);
    xline(-fixedMaskHalfWidthMps, "w--", "mask", "HandleVisibility", "off");
    xline(fixedMaskHalfWidthMps, "w--", "mask", "HandleVisibility", "off");
end

function localPlotMarginCurves(persistenceValues, targetMarginDb, methodNames, ...
    KWindow, quantileLevel)

    hold on;
    colors = lines(numel(methodNames));
    for iMethod = 1:numel(methodNames)
        plot(persistenceValues, targetMarginDb(:, iMethod), "o-", ...
            "Color", colors(iMethod, :), "LineWidth", 1.2, ...
            "DisplayName", methodNames(iMethod));
    end
    grid on;
    yline(0, "k--", "detection threshold", "HandleVisibility", "off");
    xline(KWindow / 2, "r--", "median boundary", "HandleVisibility", "off");
    xline((1 - quantileLevel) * KWindow, "m--", "q25 boundary", ...
        "HandleVisibility", "off");
    xlabel("Target persistence T in recent K-frame history");
    ylabel("Target surprise margin (dB)");
    title("Target margin versus persistence");
    legend("Location", "southwest");
end

function localPlotBackgroundCurves(persistenceValues, targetBackground, ...
    methodNames, currentTargetPower, KWindow, quantileLevel)

    hold on;
    colors = lines(numel(methodNames));
    for iMethod = 1:numel(methodNames)
        relativeBackgroundDb = 10 * log10(targetBackground(:, iMethod) ...
            / currentTargetPower + eps);
        plot(persistenceValues, relativeBackgroundDb, "o-", ...
            "Color", colors(iMethod, :), "LineWidth", 1.2, ...
            "DisplayName", methodNames(iMethod));
    end
    grid on;
    xline(KWindow / 2, "r--", "median boundary", "HandleVisibility", "off");
    xline((1 - quantileLevel) * KWindow, "m--", "q25 boundary", ...
        "HandleVisibility", "off");
    xlabel("Target persistence T in recent K-frame history");
    ylabel("Background at target cell (dB rel. current)");
    title("Absorption raises the target-cell background");
    legend("Location", "southeast");
end

function localPlotThresholdSummary(methodNames, thresholdDb, empiricalPfa, targetPfa)
    x = 1:numel(methodNames);

    yyaxis left;
    bar(x, thresholdDb);
    ylabel("Calibrated surprise threshold (dB)");
    ylim([0, 1.15 * max(thresholdDb)]);
    grid on;

    yyaxis right;
    plot(x, empiricalPfa, "ko", "MarkerFaceColor", "k", "LineWidth", 1.2);
    yline(targetPfa, "k--", "target Pfa", "HandleVisibility", "off");
    ylim([0, 1.5 * targetPfa]);
    ylabel("Empirical Pfa on calibration frames");

    xticks(x);
    xticklabels(methodNames);
    xtickangle(20);
    title("Thresholds set from target-free calibration");
end
