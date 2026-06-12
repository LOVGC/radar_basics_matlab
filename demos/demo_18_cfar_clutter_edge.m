%% demo_18_cfar_clutter_edge
% Show how a clutter edge can break the homogeneous-background assumption
% behind CA-CFAR.
%
% The target is placed just before a strong clutter step. CA-CFAR averages
% training cells from both sides, so high-clutter cells on one side can raise
% the threshold and mask a target that would be obvious in homogeneous noise.

clear; close all; clc;

%% Profile and CFAR parameters
numRangeBins = 512;
rangeBin = (1:numRangeBins).';

edgeIndex = 270;
lowClutterPower = 1;
highClutterPower = 100;     % 20 dB clutter step

targetIndex = 262;
targetPower = 120;          % strong relative to low clutter, weak near edge

numTrainingCells = 24;      % cells on each side of the CUT
numGuardCells = 4;          % cells on each side of the CUT
Pfa = 1e-3;

edgeMargin = numTrainingCells + numGuardCells;
validCutMask = false(numRangeBins, 1);
validCutMask(edgeMargin+1:numRangeBins-edgeMargin) = true;
targetWindow = targetIndex-1:targetIndex+1;

fprintf("1D CA-CFAR clutter-edge demo\n");
fprintf("Low/high clutter powers: %.1f / %.1f (%.1f dB step)\n", ...
    lowClutterPower, highClutterPower, ...
    10 * log10(highClutterPower / lowClutterPower));
fprintf("Target bin: %d, clutter edge starts at bin %d\n", ...
    targetIndex, edgeIndex);
fprintf("Training cells per side: %d, guard cells per side: %d, Pfa = %.1e\n", ...
    numTrainingCells, numGuardCells, Pfa);

%% Synthetic nonhomogeneous range statistic
clutterPower = lowClutterPower * ones(numRangeBins, 1);
clutterPower(edgeIndex:end) = highClutterPower;

rng(181);
specklePower = -log(rand(numRangeBins, 1));    % exponential power samples
rangePower = clutterPower .* specklePower;
rangePower(targetIndex) = rangePower(targetIndex) + targetPower;

%% CFAR thresholds
[caMask, caThreshold, caNoiseEstimate, alphaCa] = localCaCfar1D( ...
    rangePower, numTrainingCells, numGuardCells, Pfa);

[goMask, goThreshold, soMask, soThreshold, leftMean, rightMean, alphaSide] = ...
    localGoSoStyleCfar1D(rangePower, numTrainingCells, numGuardCells, Pfa);

detectorName = ["CA-CFAR"; "GO-style"; "SO-style"];
targetStatistic = repmat(rangePower(targetIndex), 3, 1);
targetThreshold = [caThreshold(targetIndex); goThreshold(targetIndex); ...
    soThreshold(targetIndex)];
targetMargin = targetStatistic ./ targetThreshold;
targetDetected = [any(caMask(targetWindow)); any(goMask(targetWindow)); ...
    any(soMask(targetWindow))];

nonTargetMask = validCutMask;
nonTargetMask(targetWindow) = false;
highClutterEdgeRegion = false(numRangeBins, 1);
highClutterEdgeRegion(edgeIndex:edgeIndex+50) = true;
highClutterEdgeRegion = highClutterEdgeRegion & nonTargetMask;

numDetectionsTotal = [nnz(caMask & nonTargetMask); ...
    nnz(goMask & nonTargetMask); nnz(soMask & nonTargetMask)];
numHighSideEdgeDetections = [nnz(caMask & highClutterEdgeRegion); ...
    nnz(goMask & highClutterEdgeRegion); nnz(soMask & highClutterEdgeRegion)];

summaryTable = table(detectorName, targetStatistic, targetThreshold, ...
    targetMargin, targetDetected, numDetectionsTotal, ...
    numHighSideEdgeDetections);

fprintf("CA alpha using both-side training count: %.3f\n", alphaCa);
fprintf("Side alpha used for GO/SO-style comparison: %.3f\n", alphaSide);
fprintf("At target bin %d: left training mean %.2f, right training mean %.2f, CA mean %.2f\n", ...
    targetIndex, leftMean(targetIndex), rightMean(targetIndex), ...
    caNoiseEstimate(targetIndex));
fprintf("\nClutter-edge summary:\n");
disp(summaryTable);

%% Plots
profileDB = 10 * log10(rangePower + eps);
backgroundDB = 10 * log10(clutterPower + eps);
caThresholdDB = 10 * log10(caThreshold + eps);
goThresholdDB = 10 * log10(goThreshold + eps);
soThresholdDB = 10 * log10(soThreshold + eps);

figure("Name", "Demo 18: CFAR Clutter Edge", "Color", "w", ...
    "Position", [100, 100, 1250, 760]);
tiledlayout(3, 1, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(rangeBin, profileDB, "b-", "LineWidth", 1.0, ...
    "DisplayName", "Range statistic");
hold on;
plot(rangeBin, backgroundDB, "Color", [0.45, 0.45, 0.45], ...
    "LineWidth", 1.2, "DisplayName", "Mean clutter level");
plot(rangeBin, caThresholdDB, "r-", "LineWidth", 1.2, ...
    "DisplayName", "CA threshold");
xline(edgeIndex, "k--", "Clutter edge", "LabelVerticalAlignment", "bottom", ...
    "HandleVisibility", "off");
xline(targetIndex, "m:", "Target", "LabelVerticalAlignment", "bottom", ...
    "HandleVisibility", "off");
grid on;
xlabel("Range bin");
ylabel("Power (dB)");
title("CA-CFAR threshold rises near a clutter edge");
legend("Location", "southoutside", "Orientation", "horizontal");
ylim([-20, 35]);

nexttile;
zoomWindow = targetIndex-45:edgeIndex+70;
plot(rangeBin(zoomWindow), profileDB(zoomWindow), "b-", ...
    "LineWidth", 1.1, "DisplayName", "Range statistic");
hold on;
plot(rangeBin(zoomWindow), caThresholdDB(zoomWindow), "r-", ...
    "LineWidth", 1.3, "DisplayName", "CA threshold");
plot(rangeBin(zoomWindow), goThresholdDB(zoomWindow), "Color", [0.85, 0.45, 0], ...
    "LineWidth", 1.1, "DisplayName", "GO-style threshold");
plot(rangeBin(zoomWindow), soThresholdDB(zoomWindow), "g-", ...
    "LineWidth", 1.1, "DisplayName", "SO-style threshold");
scatter(targetIndex, profileDB(targetIndex), 55, "m", "filled", ...
    "DisplayName", "Injected target");
xline(edgeIndex, "k--", "Clutter edge", "LabelVerticalAlignment", "bottom", ...
    "HandleVisibility", "off");
grid on;
xlabel("Range bin");
ylabel("Power (dB)");
title("Zoom: one-sided clutter contamination masks the target for CA/GO");
legend("Location", "southoutside", "Orientation", "horizontal");
ylim([-10, 35]);

nexttile;
hold on;
localPlotDetections(rangeBin, caMask, 3, "r", "CA detections");
localPlotDetections(rangeBin, goMask, 2, [0.85, 0.45, 0], "GO-style detections");
localPlotDetections(rangeBin, soMask, 1, "g", "SO-style detections");
xline(edgeIndex, "k--", "Clutter edge", "HandleVisibility", "off");
xline(targetIndex, "m:", "Target", "HandleVisibility", "off");
grid on;
xlabel("Range bin");
yticks([1, 2, 3]);
yticklabels(["SO-style", "GO-style", "CA-CFAR"]);
ylim([0.5, 3.5]);
title("Detection masks: different edge behavior from different training estimates");
legend("Location", "southoutside", "Orientation", "horizontal");

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_18_cfar_clutter_edge.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

%% Local functions
function [cfarMask, cfarThreshold, noiseEstimate, alpha] = localCaCfar1D( ...
    rangePower, numTrainingCells, numGuardCells, Pfa)

    numCells = numel(rangePower);
    numTrainingTotal = 2 * numTrainingCells;
    alpha = numTrainingTotal * (Pfa^(-1 / numTrainingTotal) - 1);

    cfarThreshold = nan(numCells, 1);
    noiseEstimate = nan(numCells, 1);
    cfarMask = false(numCells, 1);
    edgeMargin = numTrainingCells + numGuardCells;

    for cutIndex = edgeMargin+1:numCells-edgeMargin
        leftTraining = cutIndex - numGuardCells - numTrainingCells ...
            : cutIndex - numGuardCells - 1;
        rightTraining = cutIndex + numGuardCells + 1 ...
            : cutIndex + numGuardCells + numTrainingCells;

        trainingCells = [leftTraining, rightTraining];
        noiseEstimate(cutIndex) = mean(rangePower(trainingCells));
        cfarThreshold(cutIndex) = alpha * noiseEstimate(cutIndex);
        cfarMask(cutIndex) = rangePower(cutIndex) > cfarThreshold(cutIndex);
    end
end

function [goMask, goThreshold, soMask, soThreshold, leftMean, rightMean, alphaSide] = ...
    localGoSoStyleCfar1D(rangePower, numTrainingCells, numGuardCells, Pfa)

    numCells = numel(rangePower);
    alphaSide = numTrainingCells * (Pfa^(-1 / numTrainingCells) - 1);

    goThreshold = nan(numCells, 1);
    soThreshold = nan(numCells, 1);
    leftMean = nan(numCells, 1);
    rightMean = nan(numCells, 1);
    goMask = false(numCells, 1);
    soMask = false(numCells, 1);
    edgeMargin = numTrainingCells + numGuardCells;

    for cutIndex = edgeMargin+1:numCells-edgeMargin
        leftTraining = cutIndex - numGuardCells - numTrainingCells ...
            : cutIndex - numGuardCells - 1;
        rightTraining = cutIndex + numGuardCells + 1 ...
            : cutIndex + numGuardCells + numTrainingCells;

        leftMean(cutIndex) = mean(rangePower(leftTraining));
        rightMean(cutIndex) = mean(rangePower(rightTraining));

        goEstimate = max(leftMean(cutIndex), rightMean(cutIndex));
        soEstimate = min(leftMean(cutIndex), rightMean(cutIndex));

        goThreshold(cutIndex) = alphaSide * goEstimate;
        soThreshold(cutIndex) = alphaSide * soEstimate;
        goMask(cutIndex) = rangePower(cutIndex) > goThreshold(cutIndex);
        soMask(cutIndex) = rangePower(cutIndex) > soThreshold(cutIndex);
    end
end

function localPlotDetections(rangeBin, detectionMask, yLevel, colorSpec, displayName)
    detectionBins = rangeBin(detectionMask);
    if isempty(detectionBins)
        plot(nan, nan, "o", "Color", colorSpec, "DisplayName", displayName);
        return;
    end

    plot(detectionBins, yLevel * ones(size(detectionBins)), "o", ...
        "Color", colorSpec, "MarkerFaceColor", colorSpec, ...
        "MarkerSize", 4, "DisplayName", displayName);
end
