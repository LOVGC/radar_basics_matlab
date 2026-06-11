%% demo_14_cfar_pd_pfa_monte_carlo
% Estimate empirical Pfa and Pd for a simple 1D CA-CFAR detector.
%
% This demo uses a simplified post-processing range-bin statistic model:
% complex Gaussian noise in each range bin plus an optional target in one bin.

clear; close all; clc;

%% Detector and simulation parameters
numRangeBins = 512;
targetIndex = 260;

numTrainingCells = 24;      % cells on each side of the CUT
numGuardCells = 4;          % cells on each side of the CUT
PfaDesign = 1e-3;

numTrialsPfa = 1000;
numTrialsPd = 500;
snrSweepDB = -12:2:16;
exampleLowSnrDB = -12;
exampleHighSnrDB = 16;
maxExampleTrials = 200;

edgeMargin = numTrainingCells + numGuardCells;
validCutMask = false(numRangeBins, 1);
validCutMask(edgeMargin+1:numRangeBins-edgeMargin) = true;
numValidCuts = nnz(validCutMask);
targetDetectionWindow = targetIndex-1:targetIndex+1;

fprintf("1D CA-CFAR Monte Carlo\n");
fprintf("Range bins: %d, valid CUTs per trial: %d\n", ...
    numRangeBins, numValidCuts);
fprintf("Training cells per side: %d, guard cells per side: %d\n", ...
    numTrainingCells, numGuardCells);
fprintf("Design Pfa: %.1e\n", PfaDesign);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end

%% Single-trial Monte Carlo examples
rng(17);
[examplePfaRangePower, examplePfaThreshold, examplePfaMask, ...
    examplePfaTrial] = localFindTargetAbsentExample(numRangeBins, ...
    numTrainingCells, numGuardCells, PfaDesign, validCutMask, ...
    maxExampleTrials);

rng(23);
[lowSnrRangePower, lowSnrThreshold, lowSnrMask, ...
    lowSnrDetected, lowSnrTrial] = localFindTargetPresentExample( ...
    numRangeBins, targetIndex, exampleLowSnrDB, numTrainingCells, ...
    numGuardCells, PfaDesign, targetDetectionWindow, false, ...
    maxExampleTrials);

rng(29);
[highSnrRangePower, highSnrThreshold, highSnrMask, ...
    highSnrDetected, highSnrTrial] = localFindTargetPresentExample( ...
    numRangeBins, targetIndex, exampleHighSnrDB, numTrainingCells, ...
    numGuardCells, PfaDesign, targetDetectionWindow, true, ...
    maxExampleTrials);

figure("Name", "Demo 14: Single-trial CFAR examples", "Color", "w", ...
    "Position", [100, 100, 1000, 850]);
tiledlayout(3, 1, "Padding", "compact", "TileSpacing", "compact");

nexttile;
localPlotCfarProfile(examplePfaRangePower, examplePfaThreshold, ...
    examplePfaMask, validCutMask, [], ...
    sprintf("Target-absent Monte Carlo trial %d", examplePfaTrial));

nexttile;
localPlotCfarProfile(lowSnrRangePower, lowSnrThreshold, lowSnrMask, ...
    validCutMask, targetIndex, ...
    sprintf("Target-present trial %d at %+g dB SNR", ...
    lowSnrTrial, exampleLowSnrDB));

nexttile;
localPlotCfarProfile(highSnrRangePower, highSnrThreshold, highSnrMask, ...
    validCutMask, targetIndex, ...
    sprintf("Target-present trial %d at %+g dB SNR", ...
    highSnrTrial, exampleHighSnrDB));

outputPathExamples = fullfile(outputDir, ...
    "demo_14_cfar_single_trial_examples.png");
exportgraphics(gcf, outputPathExamples, "Resolution", 160);
fprintf("Saved single-trial examples figure: %s\n", outputPathExamples);
fprintf("Low-SNR target-present example detected in target window: %d\n", ...
    lowSnrDetected);
fprintf("High-SNR target-present example detected in target window: %d\n", ...
    highSnrDetected);

%% Empirical Pfa from target-absent trials
falseAlarmCount = 0;

rng(71);
for trial = 1:numTrialsPfa
    noise = (randn(numRangeBins, 1) + 1j * randn(numRangeBins, 1)) / sqrt(2);
    rangePower = abs(noise).^2;

    [cfarMask, cfarThreshold] = localCaCfar1D(rangePower, numTrainingCells, ...
        numGuardCells, PfaDesign);

    falseAlarmMaskThisTrial = cfarMask & validCutMask;
    falseAlarmCount = falseAlarmCount + nnz(falseAlarmMaskThisTrial);
end

empiricalPfa = falseAlarmCount / (numTrialsPfa * numValidCuts);
fprintf("Empirical Pfa over %d noise-only trials: %.3e\n", ...
    numTrialsPfa, empiricalPfa);

%% Empirical Pd from target-present trials
pdEstimate = zeros(size(snrSweepDB));

for iSnr = 1:numel(snrSweepDB)
    snrLinear = 10^(snrSweepDB(iSnr) / 10);
    targetAmplitude = sqrt(snrLinear);
    detectionCount = 0;

    for trial = 1:numTrialsPd
        noise = (randn(numRangeBins, 1) + 1j * randn(numRangeBins, 1)) / sqrt(2);
        rangeData = noise;
        rangeData(targetIndex) = rangeData(targetIndex) + targetAmplitude;
        rangePower = abs(rangeData).^2;

        [cfarMask, cfarThreshold] = localCaCfar1D(rangePower, numTrainingCells, ...
            numGuardCells, PfaDesign);

        detectedThisTrial = any(cfarMask(targetDetectionWindow));
        detectionCount = detectionCount + detectedThisTrial;
    end

    pdEstimate(iSnr) = detectionCount / numTrialsPd;
    fprintf("SNR %+4.1f dB: Pd = %.3f\n", ...
        snrSweepDB(iSnr), pdEstimate(iSnr));
end

%% Plot
figure("Name", "Demo 14: CFAR Pd/Pfa Monte Carlo", "Color", "w", ...
    "Position", [140, 140, 1000, 500]);
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(snrSweepDB, pdEstimate, "o-", "LineWidth", 1.4);
grid on;
xlabel("Target SNR (dB)");
ylabel("Empirical detection probability, Pd");
title("Pd vs SNR");
ylim([0, 1.05]);

nexttile;
bar(1, empiricalPfa);
grid on;
hold on;
yline(PfaDesign, "r--", "Design Pfa", "LineWidth", 1.2);
set(gca, "YScale", "log");
set(gca, "XTick", 1, "XTickLabel", "Noise-only");
ylabel("False alarm probability");
title("Empirical Pfa");
ylim([PfaDesign / 5, PfaDesign * 5]);

outputPath = fullfile(outputDir, "demo_14_cfar_pd_pfa_monte_carlo.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved Monte Carlo summary figure: %s\n", outputPath);

%% Local function
function [cfarMask, cfarThreshold] = localCaCfar1D( ...
    rangePower, numTrainingCells, numGuardCells, Pfa)

    numCells = numel(rangePower);
    numTrainingTotal = 2 * numTrainingCells;
    alpha = numTrainingTotal * (Pfa^(-1 / numTrainingTotal) - 1);

    cfarThreshold = nan(numCells, 1);
    cfarMask = false(numCells, 1);
    edgeMargin = numTrainingCells + numGuardCells;

    for cutIndex = edgeMargin+1:numCells-edgeMargin
        leftTraining = cutIndex - numGuardCells - numTrainingCells ...
            : cutIndex - numGuardCells - 1;
        rightTraining = cutIndex + numGuardCells + 1 ...
            : cutIndex + numGuardCells + numTrainingCells;

        noiseEstimate = mean(rangePower([leftTraining, rightTraining]));
        cfarThreshold(cutIndex) = alpha * noiseEstimate;
        cfarMask(cutIndex) = rangePower(cutIndex) > cfarThreshold(cutIndex);
    end
end

function [exampleRangePower, exampleThreshold, exampleMask, ...
    exampleTrial] = localFindTargetAbsentExample(numRangeBins, ...
    numTrainingCells, numGuardCells, Pfa, validCutMask, maxTrials)

    exampleRangePower = [];
    exampleThreshold = [];
    exampleMask = [];
    exampleTrial = 1;

    for trial = 1:maxTrials
        noise = (randn(numRangeBins, 1) + 1j * randn(numRangeBins, 1)) / sqrt(2);
        rangePower = abs(noise).^2;

        [cfarMask, cfarThreshold] = localCaCfar1D(rangePower, ...
            numTrainingCells, numGuardCells, Pfa);
        hasFalseAlarm = any(cfarMask & validCutMask);

        if trial == 1 || hasFalseAlarm
            exampleRangePower = rangePower;
            exampleThreshold = cfarThreshold;
            exampleMask = cfarMask;
            exampleTrial = trial;
        end

        if hasFalseAlarm
            return;
        end
    end
end

function [exampleRangePower, exampleThreshold, exampleMask, ...
    exampleDetected, exampleTrial] = localFindTargetPresentExample( ...
    numRangeBins, targetIndex, snrDB, numTrainingCells, numGuardCells, ...
    Pfa, targetDetectionWindow, preferredDetection, maxTrials)

    snrLinear = 10^(snrDB / 10);
    targetAmplitude = sqrt(snrLinear);
    exampleRangePower = [];
    exampleThreshold = [];
    exampleMask = [];
    exampleDetected = false;
    exampleTrial = 1;

    for trial = 1:maxTrials
        noise = (randn(numRangeBins, 1) + 1j * randn(numRangeBins, 1)) / sqrt(2);
        rangeData = noise;
        rangeData(targetIndex) = rangeData(targetIndex) + targetAmplitude;
        rangePower = abs(rangeData).^2;

        [cfarMask, cfarThreshold] = localCaCfar1D(rangePower, ...
            numTrainingCells, numGuardCells, Pfa);
        detectedThisTrial = any(cfarMask(targetDetectionWindow));

        if trial == 1 || detectedThisTrial == preferredDetection
            exampleRangePower = rangePower;
            exampleThreshold = cfarThreshold;
            exampleMask = cfarMask;
            exampleDetected = detectedThisTrial;
            exampleTrial = trial;
        end

        if detectedThisTrial == preferredDetection
            return;
        end
    end
end

function localPlotCfarProfile(rangePower, cfarThreshold, cfarMask, ...
    validCutMask, targetIndex, plotTitle)

    rangeBin = (1:numel(rangePower)).';
    rangePowerDB = 10 * log10(rangePower + eps);
    thresholdDB = 10 * log10(cfarThreshold + eps);
    detectionMask = cfarMask & validCutMask;
    detectionBins = rangeBin(detectionMask);

    plot(rangeBin, rangePowerDB, "b-", "LineWidth", 1.0, ...
        "DisplayName", "Range power");
    hold on;
    plot(rangeBin, thresholdDB, "k--", "LineWidth", 1.2, ...
        "DisplayName", "CFAR threshold");

    if ~isempty(detectionBins)
        scatter(detectionBins, rangePowerDB(detectionMask), 38, "r", ...
            "filled", "DisplayName", "CFAR detections");
    end

    if ~isempty(targetIndex)
        xline(targetIndex, "m:", "LineWidth", 1.2, ...
            "DisplayName", "Target bin");
    end

    grid on;
    xlabel("Range bin");
    ylabel("Power (dB)");
    title(plotTitle);
    legend("Location", "best");
end
