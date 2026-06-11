%% demo_17_cfar_roc_pfa_snr_sweep
% Sweep target SNR and design Pfa for a simple 1D CA-CFAR detector.
%
% This demo extends demo_14: instead of one design Pfa, compare several
% thresholds. Lower design Pfa gives fewer false alarms, but weak targets
% need more SNR to reach the higher threshold.

clear; close all; clc;

%% Detector and simulation parameters
numRangeBins = 512;
targetIndex = 260;

numTrainingCells = 24;      % cells on each side of the CUT
numGuardCells = 4;          % cells on each side of the CUT
pfaDesignSweep = [1e-2, 1e-3, 1e-5, 1e-7];

numTrialsPfa = 2000;
numTrialsPd = 500;
snrSweepDB = -12:2:20;

edgeMargin = numTrainingCells + numGuardCells;
validCutMask = false(numRangeBins, 1);
validCutMask(edgeMargin+1:numRangeBins-edgeMargin) = true;
numValidCuts = nnz(validCutMask);
targetDetectionWindow = targetIndex-1:targetIndex+1;

numPfaCases = numel(pfaDesignSweep);
numSnrCases = numel(snrSweepDB);

fprintf("1D CA-CFAR ROC-style Monte Carlo sweep\n");
fprintf("Range bins: %d, valid CUTs per trial: %d\n", ...
    numRangeBins, numValidCuts);
fprintf("Training cells per side: %d, guard cells per side: %d\n", ...
    numTrainingCells, numGuardCells);
fprintf("Design Pfa sweep: %s\n", mat2str(pfaDesignSweep));
fprintf("Pfa trials: %d, Pd trials per SNR: %d\n", ...
    numTrialsPfa, numTrialsPd);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end

%% Empirical Pfa from target-absent trials
falseAlarmCount = zeros(numPfaCases, 1);
alphaByPfa = zeros(numPfaCases, 1);

rng(171);
for trial = 1:numTrialsPfa
    noise = (randn(numRangeBins, 1) + 1j * randn(numRangeBins, 1)) / sqrt(2);
    rangePower = abs(noise).^2;

    for iPfa = 1:numPfaCases
        [cfarMask, ~, alphaByPfa(iPfa)] = localCaCfar1D(rangePower, ...
            numTrainingCells, numGuardCells, pfaDesignSweep(iPfa));
        falseAlarmCount(iPfa) = falseAlarmCount(iPfa) ...
            + nnz(cfarMask & validCutMask);
    end
end

empiricalPfa = falseAlarmCount / (numTrialsPfa * numValidCuts);

%% Empirical Pd from target-present trials
pdEstimate = zeros(numSnrCases, numPfaCases);

rng(173);
for iSnr = 1:numSnrCases
    snrLinear = 10^(snrSweepDB(iSnr) / 10);
    targetAmplitude = sqrt(snrLinear);
    detectionCount = zeros(numPfaCases, 1);

    for trial = 1:numTrialsPd
        noise = (randn(numRangeBins, 1) + 1j * randn(numRangeBins, 1)) / sqrt(2);
        rangeData = noise;
        rangeData(targetIndex) = rangeData(targetIndex) + targetAmplitude;
        rangePower = abs(rangeData).^2;

        for iPfa = 1:numPfaCases
            [cfarMask, ~] = localCaCfar1D(rangePower, ...
                numTrainingCells, numGuardCells, pfaDesignSweep(iPfa));
            detectedThisTrial = any(cfarMask(targetDetectionWindow));
            detectionCount(iPfa) = detectionCount(iPfa) + detectedThisTrial;
        end
    end

    pdEstimate(iSnr, :) = detectionCount.' / numTrialsPd;
    fprintf("SNR %+5.1f dB Pd: %s\n", ...
        snrSweepDB(iSnr), mat2str(pdEstimate(iSnr, :), 3));
end

%% Summary table
pdAt0dB = localInterpolatePd(snrSweepDB, pdEstimate, 0);
pdAt6dB = localInterpolatePd(snrSweepDB, pdEstimate, 6);
snrForPd90 = localFirstSnrForPd(snrSweepDB, pdEstimate, 0.90);

summaryTable = table(pfaDesignSweep(:), alphaByPfa, empiricalPfa, ...
    pdAt0dB(:), pdAt6dB(:), snrForPd90(:), ...
    'VariableNames', {'pfaDesign', 'alpha', 'empiricalPfa', ...
    'pdAt0dB', 'pdAt6dB', 'snrForPd90dB'});

fprintf("\nROC-style summary:\n");
disp(summaryTable);

%% Plot
figure("Name", "Demo 17: CFAR ROC Pfa/SNR Sweep", "Color", "w", ...
    "Position", [120, 120, 1200, 520]);
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
hold on;
for iPfa = 1:numPfaCases
    plot(snrSweepDB, pdEstimate(:, iPfa), "o-", "LineWidth", 1.4, ...
        "DisplayName", sprintf("Pfa = %.0e", pfaDesignSweep(iPfa)));
end
grid on;
xlabel("Target SNR (dB)");
ylabel("Empirical detection probability, Pd");
title("Pd vs SNR for different design Pfa");
ylim([0, 1.05]);
legend("Location", "southeast");

nexttile;
pfaPlotFloor = 0.5 / (numTrialsPfa * numValidCuts);
empiricalPfaForPlot = max(empiricalPfa, pfaPlotFloor);
loglog(pfaDesignSweep, empiricalPfaForPlot, "bo-", ...
    "LineWidth", 1.4, "MarkerSize", 7, "DisplayName", "Empirical Pfa");
grid on;
hold on;
loglog(pfaDesignSweep, pfaDesignSweep, "ro--", ...
    "LineWidth", 1.2, "MarkerSize", 7, "DisplayName", "Design Pfa");
set(gca, "XScale", "log", "YScale", "log", "XDir", "reverse");
xlim([min(pfaDesignSweep) / 3, max(pfaDesignSweep) * 3]);
ylim([pfaPlotFloor / 3, max(pfaDesignSweep) * 3]);
xlabel("Design Pfa");
ylabel("False alarm probability");
title("Empirical Pfa from noise-only trials");
if any(empiricalPfa == 0)
    zeroObserved = empiricalPfa == 0;
    text(pfaDesignSweep(zeroObserved), empiricalPfaForPlot(zeroObserved) * 1.8, ...
        "0 observed", "HorizontalAlignment", "center", "FontSize", 9);
end
legend("Location", "northwest");

outputPath = fullfile(outputDir, "demo_17_cfar_roc_pfa_snr_sweep.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

%% Local functions
function [cfarMask, cfarThreshold, alpha] = localCaCfar1D( ...
    rangePower, numTrainingCells, numGuardCells, pfaDesign)

    numCells = numel(rangePower);
    numTrainingTotal = 2 * numTrainingCells;
    alpha = numTrainingTotal * (pfaDesign^(-1 / numTrainingTotal) - 1);

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

function pdAtSnr = localInterpolatePd(snrSweepDB, pdEstimate, querySnrDB)
    numPfaCases = size(pdEstimate, 2);
    pdAtSnr = zeros(numPfaCases, 1);

    for iPfa = 1:numPfaCases
        pdAtSnr(iPfa) = interp1(snrSweepDB, pdEstimate(:, iPfa), ...
            querySnrDB, "linear", "extrap");
    end
end

function snrForPd = localFirstSnrForPd(snrSweepDB, pdEstimate, targetPd)
    numPfaCases = size(pdEstimate, 2);
    snrForPd = nan(numPfaCases, 1);

    for iPfa = 1:numPfaCases
        firstIndex = find(pdEstimate(:, iPfa) >= targetPd, 1, "first");
        if ~isempty(firstIndex)
            snrForPd(iPfa) = snrSweepDB(firstIndex);
        end
    end
end
