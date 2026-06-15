%% demo_24_clutter_map_background_subtraction
% Learn a simple clutter map from previous RD maps.
%
% Demo 23 used a fixed Doppler mask, which removed clutter reports but also
% suppressed a true slow target. Here we estimate a per-cell background map
% from previous CPIs. A new target can stand out as "surprise" relative to
% the learned background, even when it lies inside the low-Doppler band.

clear; close all; clc;

%% Baseline parameters
c = 299792458;
fc = 10e9;
lambda = c / fc;

B = 10e6;
tau = 10e-6;
fs = 20e6;
PRF = 10e3;
PRI = 1 / PRF;
Np = 128;

slowTargetRange = 5.25e3;
slowTargetVelocity = 2;
slowTargetAmplitude = 0.55;

fastTargetRange = 4.0e3;
fastTargetVelocity = 12;
fastTargetAmplitude = 0.45;

clutterBaseRanges = (1.2e3:160:8.8e3).';
clutterBaseRanges(abs(clutterBaseRanges - slowTargetRange) < 300) = [];
clutterBaseRanges(abs(clutterBaseRanges - fastTargetRange) < 300) = [];
clutterAmplitude = 2.0;
dopplerSpreadStdMps = 2.0;
clutterMaskHalfWidthMps = 5.0;

noisePower = 0.05;
numHistoryFrames = 20;
surpriseThresholdDb = 12;

%% 2D CA-CFAR parameters
trainingRangeCells = 18;
trainingDopplerCells = 7;
guardRangeCells = 4;
guardDopplerCells = 2;
Pfa = 1e-5;

%% Derived values
K = B / tau;
Nfast = round(fs / PRF);
Ntx = round(tau * fs);
tFast = (0:Nfast-1).' / fs;
tPulse = (0:Ntx-1).' / fs;

rangeResolution = c / (2 * B);
velocityBin = lambda * PRF / (2 * Np);

fprintf("Theoretical range resolution: %.2f m\n", rangeResolution);
fprintf("Velocity bin spacing: %.2f m/s\n", velocityBin);
fprintf("History frames for clutter map: %d\n", numHistoryFrames);
fprintf("Doppler-spread clutter std: %.2f m/s\n", dopplerSpreadStdMps);
fprintf("Fixed Doppler report mask: |v| <= %.2f m/s\n", clutterMaskHalfWidthMps);
fprintf("Clutter-map surprise threshold: %.1f dB\n", surpriseThresholdDb);

%% Stable clutter geometry shared by history and current frame
txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);

rng(241);
clutterRanges = clutterBaseRanges + 8 * randn(size(clutterBaseRanges));
clutterPhases = exp(1j * 2 * pi * rand(numel(clutterRanges), 1));
clutterAmplitudes = clutterAmplitude * (0.75 + 0.5 * rand(numel(clutterRanges), 1)) ...
    .* clutterPhases;
clutterVelocities = dopplerSpreadStdMps * randn(size(clutterRanges));
clutterVelocities = max(min(clutterVelocities, 4 * dopplerSpreadStdMps), ...
    -4 * dopplerSpreadStdMps);

%% Build historical clutter map from target-free frames
historyPower = [];
rangeAxis = [];
velocityAxis = [];
for iFrame = 1:numHistoryFrames
    noise = sqrt(noisePower / 2) * (randn(Nfast, Np) + 1j * randn(Nfast, Np));
    [rdPowerAfter, rangeAxis, velocityAxis] = localRunFrame( ...
        clutterRanges, clutterVelocities, clutterAmplitudes, ...
        zeros(0, 1), zeros(0, 1), zeros(0, 1), noise, txPulse, ...
        tFast, PRI, lambda, c, K, tau, Np, fs, PRF, Ntx);

    if isempty(historyPower)
        historyPower = zeros([size(rdPowerAfter), numHistoryFrames]);
    end
    historyPower(:, :, iFrame) = rdPowerAfter;
end

clutterMap = mean(historyPower, 3);
backgroundFloor = median(clutterMap(:));

%% Current frame: same clutter plus new slow and fast targets
noise = sqrt(noisePower / 2) * (randn(Nfast, Np) + 1j * randn(Nfast, Np));
targetRanges = [slowTargetRange; fastTargetRange];
targetVelocities = [slowTargetVelocity; fastTargetVelocity];
targetAmplitudes = [slowTargetAmplitude; fastTargetAmplitude];

[rdPowerAfter, rangeAxis, velocityAxis] = localRunFrame( ...
    clutterRanges, clutterVelocities, clutterAmplitudes, ...
    targetRanges, targetVelocities, targetAmplitudes, noise, txPulse, ...
    tFast, PRI, lambda, c, K, tau, Np, fs, PRF, Ntx);

[cfarMaskAfter, cfarThresholdAfter] = localCaCfar2D(rdPowerAfter, ...
    trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
    guardDopplerCells, Pfa);

lowDopplerMask = abs(velocityAxis) <= clutterMaskHalfWidthMps;
fixedReportMask = cfarMaskAfter & repmat(~lowDopplerMask, numel(rangeAxis), 1);

surpriseRatio = rdPowerAfter ./ (clutterMap + backgroundFloor);
surpriseMapDB = 10 * log10(surpriseRatio + eps);
clutterMapMask = surpriseMapDB > surpriseThresholdDb;

truthNames = ["slow target"; "fast target"];
truthSummary = localBuildTruthSummary(truthNames, targetRanges, targetVelocities, ...
    rangeAxis, velocityAxis, rdPowerAfter, cfarThresholdAfter, ...
    cfarMaskAfter, fixedReportMask, clutterMapMask, surpriseMapDB);

fprintf("Raw after-MTI CFAR detected CUTs: %d\n", nnz(cfarMaskAfter));
fprintf("Raw after-MTI low-Doppler detected CUTs: %d\n", nnz(cfarMaskAfter(:, lowDopplerMask)));
fprintf("Fixed Doppler-mask reportable CUTs: %d\n", nnz(fixedReportMask));
fprintf("Fixed Doppler-mask low-Doppler reportable CUTs: %d\n", ...
    nnz(fixedReportMask(:, lowDopplerMask)));
fprintf("Clutter-map surprise CUTs: %d\n", nnz(clutterMapMask));
fprintf("Clutter-map low-Doppler surprise CUTs: %d\n", ...
    nnz(clutterMapMask(:, lowDopplerMask)));
fprintf("\nTruth summary:\n");
disp(truthSummary);

%% Plots
rdPowerDB = 10 * log10(rdPowerAfter / max(rdPowerAfter(:)) + eps);
clutterMapDB = 10 * log10(clutterMap / max(clutterMap(:)) + eps);

figure("Name", "Demo 24: Clutter Map Background Subtraction", "Color", "w", ...
    "Position", [70, 80, 1400, 780]);
tiledlayout(2, 3, "Padding", "compact", "TileSpacing", "compact");

nexttile;
localPlotPowerMap(velocityAxis, rangeAxis, rdPowerDB, ...
    "Current after-MTI RD power", targetRanges, targetVelocities, ...
    clutterMaskHalfWidthMps);

nexttile;
localPlotPowerMap(velocityAxis, rangeAxis, clutterMapDB, ...
    "Learned clutter/background map", targetRanges, targetVelocities, ...
    clutterMaskHalfWidthMps);

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, surpriseMapDB);
axis xy;
colorbar;
clim([-5, 30]);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("Current / clutter-map surprise (dB)");
hold on;
localPlotTruthMarkers(targetRanges, targetVelocities);
xline(-clutterMaskHalfWidthMps, "w--", "mask", "HandleVisibility", "off");
xline(clutterMaskHalfWidthMps, "w--", "mask", "HandleVisibility", "off");

nexttile;
localPlotMask(velocityAxis, rangeAxis, cfarMaskAfter, ...
    "Raw after-MTI CFAR mask", targetRanges, targetVelocities, ...
    clutterMaskHalfWidthMps);

nexttile;
localPlotMask(velocityAxis, rangeAxis, fixedReportMask, ...
    "Fixed Doppler-mask reports", targetRanges, targetVelocities, ...
    clutterMaskHalfWidthMps);

nexttile;
localPlotMask(velocityAxis, rangeAxis, clutterMapMask, ...
    "Clutter-map surprise mask", targetRanges, targetVelocities, ...
    clutterMaskHalfWidthMps);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_24_clutter_map_background_subtraction.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

%% Local functions
function [rdPowerAfter, rangeAxis, velocityAxis] = localRunFrame( ...
    clutterRanges, clutterVelocities, clutterAmplitudes, targetRanges, ...
    targetVelocities, targetAmplitudes, noise, txPulse, tFast, PRI, lambda, ...
    c, K, tau, Np, fs, PRF, Ntx)

    Nfast = numel(tFast);
    rx = complex(zeros(Nfast, Np));

    for iClutter = 1:numel(clutterRanges)
        rx = rx + localPointEcho(clutterRanges(iClutter), ...
            clutterVelocities(iClutter), clutterAmplitudes(iClutter), ...
            txPulse, tFast, PRI, lambda, c, K, tau, Np);
    end

    for iTarget = 1:numel(targetRanges)
        rx = rx + localPointEcho(targetRanges(iTarget), ...
            targetVelocities(iTarget), targetAmplitudes(iTarget), ...
            txPulse, tFast, PRI, lambda, c, K, tau, Np);
    end

    rx = rx + noise;

    matchedFilter = conj(flipud(txPulse));
    [matchedOut, rangeAxis] = localMatchedFilter(rx, matchedFilter, fs, c, PRF, Ntx);
    mtiOut = [complex(zeros(size(matchedOut, 1), 1)), diff(matchedOut, 1, 2)];

    slowTimeWindow = 0.5 - 0.5 * cos(2 * pi * (0:Np-1) / (Np-1));
    rangeDopplerAfter = fftshift(fft(mtiOut .* slowTimeWindow, [], 2), 2);
    dopplerAxis = (-Np/2:Np/2-1) * PRF / Np;
    velocityAxis = lambda * dopplerAxis / 2;
    rdPowerAfter = abs(rangeDopplerAfter).^2;
end

function echo = localPointEcho(targetRange, targetVelocity, amplitude, ...
    txPulse, tFast, PRI, lambda, c, K, tau, Np)

    Nfast = numel(tFast);
    echo = complex(zeros(Nfast, Np));
    delayTime = 2 * targetRange / c;
    dopplerHz = 2 * targetVelocity / lambda;
    tDelayed = tFast - delayTime;
    echoMask = (tDelayed >= 0) & (tDelayed < tau);

    for p = 1:Np
        absoluteTime = tFast + (p-1) * PRI;

        onePulseEcho = complex(zeros(Nfast, 1));
        delayedPulse = exp(1j * pi * K * (tDelayed(echoMask) - tau/2).^2);
        dopplerPhase = exp(1j * 2 * pi * dopplerHz * absoluteTime(echoMask));
        onePulseEcho(echoMask) = amplitude * delayedPulse .* dopplerPhase;

        echo(:, p) = onePulseEcho;
    end
end

function [matchedOut, rangeAxis] = localMatchedFilter(rx, matchedFilter, fs, c, PRF, Ntx)
    [Nfast, Np] = size(rx);
    NrangeFull = Nfast + Ntx - 1;
    matchedOut = complex(zeros(NrangeFull, Np));

    for p = 1:Np
        matchedOut(:, p) = conv(rx(:, p), matchedFilter, "full");
    end

    rangeAxis = ((0:NrangeFull-1).' - (Ntx - 1)) / fs * c / 2;
    validRange = (rangeAxis >= 0) & (rangeAxis <= c / (2 * PRF));
    rangeAxis = rangeAxis(validRange);
    matchedOut = matchedOut(validRange, :);
end

function [cfarMask, cfarThreshold, alpha, numTrainingCells] = localCaCfar2D( ...
    rdPower, trainingRangeCells, trainingDopplerCells, ...
    guardRangeCells, guardDopplerCells, Pfa)

    [numRangeBins, numDopplerBins] = size(rdPower);
    cfarThreshold = nan(numRangeBins, numDopplerBins);
    cfarMask = false(numRangeBins, numDopplerBins);

    rangeMargin = trainingRangeCells + guardRangeCells;
    dopplerMargin = trainingDopplerCells + guardDopplerCells;

    windowRows = -rangeMargin:rangeMargin;
    windowCols = -dopplerMargin:dopplerMargin;
    [rowOffsetGrid, colOffsetGrid] = ndgrid(windowRows, windowCols);
    guardMask = abs(rowOffsetGrid) <= guardRangeCells ...
        & abs(colOffsetGrid) <= guardDopplerCells;
    trainingMask = ~guardMask;
    numTrainingCells = nnz(trainingMask);
    alpha = numTrainingCells * (Pfa^(-1 / numTrainingCells) - 1);

    for r = rangeMargin+1:numRangeBins-rangeMargin
        for dBin = dopplerMargin+1:numDopplerBins-dopplerMargin
            localWindow = rdPower(r + windowRows, dBin + windowCols);
            noiseEstimate = mean(localWindow(trainingMask));
            cfarThreshold(r, dBin) = alpha * noiseEstimate;
            cfarMask(r, dBin) = rdPower(r, dBin) > cfarThreshold(r, dBin);
        end
    end
end

function summaryTable = localBuildTruthSummary(truthNames, truthRanges, ...
    truthVelocities, rangeAxis, velocityAxis, rdPowerAfter, cfarThresholdAfter, ...
    cfarMaskAfter, fixedReportMask, clutterMapMask, surpriseMapDB)

    numTruth = numel(truthNames);
    nearestRangeM = zeros(numTruth, 1);
    nearestVelocityMps = zeros(numTruth, 1);
    statisticAfter = zeros(numTruth, 1);
    thresholdAfter = zeros(numTruth, 1);
    marginAfter = zeros(numTruth, 1);
    surpriseDb = zeros(numTruth, 1);
    rawCfarDetected = false(numTruth, 1);
    fixedDopplerReported = false(numTruth, 1);
    clutterMapDetected = false(numTruth, 1);

    for iTruth = 1:numTruth
        [~, rangeIndex] = min(abs(rangeAxis - truthRanges(iTruth)));
        [~, velocityIndex] = min(abs(velocityAxis - truthVelocities(iTruth)));
        rangeWindow = max(1, rangeIndex-2):min(numel(rangeAxis), rangeIndex+2);
        velocityWindow = max(1, velocityIndex-2):min(numel(velocityAxis), velocityIndex+2);

        targetPatch = rdPowerAfter(rangeWindow, velocityWindow);
        thresholdPatch = cfarThresholdAfter(rangeWindow, velocityWindow);
        surprisePatch = surpriseMapDB(rangeWindow, velocityWindow);

        [statisticAfter(iTruth), localIndex] = max(targetPatch(:));
        thresholdAfter(iTruth) = thresholdPatch(localIndex);
        marginAfter(iTruth) = statisticAfter(iTruth) / thresholdAfter(iTruth);
        surpriseDb(iTruth) = max(surprisePatch(:));
        rawCfarDetected(iTruth) = any(cfarMaskAfter(rangeWindow, velocityWindow), "all");
        fixedDopplerReported(iTruth) = any(fixedReportMask(rangeWindow, velocityWindow), "all");
        clutterMapDetected(iTruth) = any(clutterMapMask(rangeWindow, velocityWindow), "all");
        nearestRangeM(iTruth) = rangeAxis(rangeIndex);
        nearestVelocityMps(iTruth) = velocityAxis(velocityIndex);
    end

    summaryTable = table(truthNames, nearestRangeM, nearestVelocityMps, ...
        statisticAfter, thresholdAfter, marginAfter, surpriseDb, ...
        rawCfarDetected, fixedDopplerReported, clutterMapDetected);
end

function localPlotPowerMap(velocityAxis, rangeAxis, powerDB, plotTitle, ...
    truthRanges, truthVelocities, clutterMaskHalfWidthMps)

    imagesc(velocityAxis, rangeAxis / 1e3, powerDB);
    axis xy;
    colorbar;
    clim([-65, 0]);
    xlabel("Velocity (m/s)");
    ylabel("Range (km)");
    title(plotTitle);
    hold on;
    localPlotTruthMarkers(truthRanges, truthVelocities);
    xline(-clutterMaskHalfWidthMps, "w--", "mask", "HandleVisibility", "off");
    xline(clutterMaskHalfWidthMps, "w--", "mask", "HandleVisibility", "off");
end

function localPlotMask(velocityAxis, rangeAxis, mask, plotTitle, ...
    truthRanges, truthVelocities, clutterMaskHalfWidthMps)

    imagesc(velocityAxis, rangeAxis / 1e3, mask);
    axis xy;
    colormap(gca, gray);
    xlabel("Velocity (m/s)");
    ylabel("Range (km)");
    title(plotTitle);
    hold on;
    localPlotTruthMarkers(truthRanges, truthVelocities);
    xline(-clutterMaskHalfWidthMps, "r--", "mask", "HandleVisibility", "off");
    xline(clutterMaskHalfWidthMps, "r--", "mask", "HandleVisibility", "off");
end

function localPlotTruthMarkers(truthRanges, truthVelocities)
    plot(truthVelocities(1), truthRanges(1) / 1e3, "c^", ...
        "MarkerSize", 8, "LineWidth", 1.5);
    plot(truthVelocities(2), truthRanges(2) / 1e3, "wo", ...
        "MarkerSize", 8, "LineWidth", 1.5);
end
