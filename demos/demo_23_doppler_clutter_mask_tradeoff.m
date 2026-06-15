%% demo_23_doppler_clutter_mask_tradeoff
% Use a Doppler-domain clutter mask after MTI + CFAR.
%
% A simple way to avoid reporting Doppler-spread clutter is to exclude a
% low-velocity band from automatic reporting. This reduces clutter reports,
% but it also creates a blind zone for slow targets in the same velocity band.

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
slowTargetAmplitude = 0.90;

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
fprintf("Doppler-spread clutter std: %.2f m/s\n", dopplerSpreadStdMps);
fprintf("Report-stage clutter mask: |v| <= %.2f m/s\n", clutterMaskHalfWidthMps);
fprintf("2D CA-CFAR: Tr=%d, Td=%d, Gr=%d, Gd=%d, Pfa=%.1e\n", ...
    trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
    guardDopplerCells, Pfa);

%% Waveform, target, clutter, and noise synthesis
txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);

rng(231);
clutterRanges = clutterBaseRanges + 8 * randn(size(clutterBaseRanges));
clutterPhases = exp(1j * 2 * pi * rand(numel(clutterRanges), 1));
clutterAmplitudes = clutterAmplitude * (0.75 + 0.5 * rand(numel(clutterRanges), 1)) ...
    .* clutterPhases;
clutterVelocities = dopplerSpreadStdMps * randn(size(clutterRanges));
clutterVelocities = max(min(clutterVelocities, 4 * dopplerSpreadStdMps), ...
    -4 * dopplerSpreadStdMps);

rx = complex(zeros(Nfast, Np));
for iClutter = 1:numel(clutterRanges)
    rx = rx + localPointEcho(clutterRanges(iClutter), ...
        clutterVelocities(iClutter), clutterAmplitudes(iClutter), ...
        txPulse, tFast, PRI, lambda, c, K, tau, Np);
end

rx = rx + localPointEcho(slowTargetRange, slowTargetVelocity, ...
    slowTargetAmplitude, txPulse, tFast, PRI, lambda, c, K, tau, Np);
rx = rx + localPointEcho(fastTargetRange, fastTargetVelocity, ...
    fastTargetAmplitude, txPulse, tFast, PRI, lambda, c, K, tau, Np);

noise = sqrt(noisePower / 2) * (randn(Nfast, Np) + 1j * randn(Nfast, Np));
rx = rx + noise;

%% Matched filtering, MTI, Doppler FFT, and CFAR
matchedFilter = conj(flipud(txPulse));
[matchedOut, rangeAxis] = localMatchedFilter(rx, matchedFilter, fs, c, PRF, Ntx);
mtiOut = [complex(zeros(size(matchedOut, 1), 1)), diff(matchedOut, 1, 2)];

slowTimeWindow = 0.5 - 0.5 * cos(2 * pi * (0:Np-1) / (Np-1));
rangeDopplerAfter = fftshift(fft(mtiOut .* slowTimeWindow, [], 2), 2);
dopplerAxis = (-Np/2:Np/2-1) * PRF / Np;
velocityAxis = lambda * dopplerAxis / 2;
rdPowerAfter = abs(rangeDopplerAfter).^2;

[cfarMaskAfter, cfarThresholdAfter] = localCaCfar2D(rdPowerAfter, ...
    trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
    guardDopplerCells, Pfa);

lowDopplerMask = abs(velocityAxis) <= clutterMaskHalfWidthMps;
reportableDopplerMask = ~lowDopplerMask;
reportMask = cfarMaskAfter & repmat(reportableDopplerMask, numel(rangeAxis), 1);

truthNames = ["slow target"; "fast target"];
truthRanges = [slowTargetRange; fastTargetRange];
truthVelocities = [slowTargetVelocity; fastTargetVelocity];
summaryTable = localBuildTruthSummary(truthNames, truthRanges, truthVelocities, ...
    rangeAxis, velocityAxis, rdPowerAfter, cfarThresholdAfter, ...
    cfarMaskAfter, reportMask);

fprintf("Raw after-MTI CFAR detected CUTs: %d\n", nnz(cfarMaskAfter));
fprintf("Raw after-MTI low-Doppler detected CUTs: %d\n", ...
    nnz(cfarMaskAfter(:, lowDopplerMask)));
fprintf("Reportable detected CUTs after Doppler clutter mask: %d\n", nnz(reportMask));
fprintf("Reportable low-Doppler detected CUTs after mask: %d\n", ...
    nnz(reportMask(:, lowDopplerMask)));
fprintf("\nTruth summary:\n");
disp(summaryTable);

%% Plots
rdPowerDB = 10 * log10(rdPowerAfter / max(rdPowerAfter(:)) + eps);

figure("Name", "Demo 23: Doppler Clutter Mask Tradeoff", "Color", "w", ...
    "Position", [80, 80, 1350, 760]);
tiledlayout(2, 3, "Padding", "compact", "TileSpacing", "compact");

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, rdPowerDB);
axis xy;
colorbar;
clim([-65, 0]);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("After MTI: RD power");
hold on;
localPlotTruthMarkers(truthRanges, truthVelocities);
xline(-clutterMaskHalfWidthMps, "w--", "mask", "HandleVisibility", "off");
xline(clutterMaskHalfWidthMps, "w--", "mask", "HandleVisibility", "off");
xline(0, "w:", "0 m/s", "HandleVisibility", "off");

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, cfarMaskAfter);
axis xy;
colormap(gca, gray);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("Raw after-MTI CFAR mask");
hold on;
localPlotTruthMarkers(truthRanges, truthVelocities);
xline(-clutterMaskHalfWidthMps, "r--", "mask", "HandleVisibility", "off");
xline(clutterMaskHalfWidthMps, "r--", "mask", "HandleVisibility", "off");

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, reportMask);
axis xy;
colormap(gca, gray);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("Report mask after Doppler clutter mask");
hold on;
localPlotTruthMarkers(truthRanges, truthVelocities);
xline(-clutterMaskHalfWidthMps, "r--", "mask", "HandleVisibility", "off");
xline(clutterMaskHalfWidthMps, "r--", "mask", "HandleVisibility", "off");

nexttile;
localPlotDopplerProfile(rdPowerAfter, velocityAxis, clutterMaskHalfWidthMps);

nexttile;
marginDB = 10 * log10(summaryTable.marginAfter + eps);
bar(categorical(summaryTable.truthNames), marginDB);
grid on;
yline(0, "k--", "CFAR threshold", "HandleVisibility", "off");
ylabel("Statistic / threshold (dB)");
title("CFAR margin before report mask");

nexttile;
reportedNumeric = double(summaryTable.reportedAfterDopplerMask);
bar(categorical(summaryTable.truthNames), reportedNumeric);
grid on;
ylim([0, 1.2]);
yticks([0, 1]);
yticklabels(["not reported", "reported"]);
title("Final reporting decision");

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_23_doppler_clutter_mask_tradeoff.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

%% Local functions
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
    truthVelocities, rangeAxis, velocityAxis, rdPowerAfter, ...
    cfarThresholdAfter, cfarMaskAfter, reportMask)

    numTruth = numel(truthNames);
    nearestRangeM = zeros(numTruth, 1);
    nearestVelocityMps = zeros(numTruth, 1);
    statisticAfter = zeros(numTruth, 1);
    thresholdAfter = zeros(numTruth, 1);
    marginAfter = zeros(numTruth, 1);
    rawCfarDetected = false(numTruth, 1);
    reportedAfterDopplerMask = false(numTruth, 1);

    for iTruth = 1:numTruth
        [~, rangeIndex] = min(abs(rangeAxis - truthRanges(iTruth)));
        [~, velocityIndex] = min(abs(velocityAxis - truthVelocities(iTruth)));
        rangeWindow = max(1, rangeIndex-2):min(numel(rangeAxis), rangeIndex+2);
        velocityWindow = max(1, velocityIndex-2):min(numel(velocityAxis), velocityIndex+2);

        targetPatch = rdPowerAfter(rangeWindow, velocityWindow);
        thresholdPatch = cfarThresholdAfter(rangeWindow, velocityWindow);
        [statisticAfter(iTruth), localIndex] = max(targetPatch(:));
        thresholdAfter(iTruth) = thresholdPatch(localIndex);
        marginAfter(iTruth) = statisticAfter(iTruth) / thresholdAfter(iTruth);
        rawCfarDetected(iTruth) = any(cfarMaskAfter(rangeWindow, velocityWindow), "all");
        reportedAfterDopplerMask(iTruth) = any(reportMask(rangeWindow, velocityWindow), "all");
        nearestRangeM(iTruth) = rangeAxis(rangeIndex);
        nearestVelocityMps(iTruth) = velocityAxis(velocityIndex);
    end

    summaryTable = table(truthNames, nearestRangeM, nearestVelocityMps, ...
        statisticAfter, thresholdAfter, marginAfter, rawCfarDetected, ...
        reportedAfterDopplerMask);
end

function localPlotTruthMarkers(truthRanges, truthVelocities)
    plot(truthVelocities(1), truthRanges(1) / 1e3, "c^", ...
        "MarkerSize", 8, "LineWidth", 1.5);
    plot(truthVelocities(2), truthRanges(2) / 1e3, "wo", ...
        "MarkerSize", 8, "LineWidth", 1.5);
end

function localPlotDopplerProfile(rdPowerAfter, velocityAxis, clutterMaskHalfWidthMps)
    profileAfter = sum(rdPowerAfter, 1);
    profileAfterDB = 10 * log10(profileAfter / max(profileAfter) + eps);
    plot(velocityAxis, profileAfterDB, "k-", "LineWidth", 1.2);
    grid on;
    xlabel("Velocity (m/s)");
    ylabel("After-MTI power (dB rel.)");
    title("All-range Doppler profile after MTI");
    xlim([-18, 18]);
    ylim([-60, 3]);
    xline(-clutterMaskHalfWidthMps, "r--", "mask", "HandleVisibility", "off");
    xline(clutterMaskHalfWidthMps, "r--", "mask", "HandleVisibility", "off");
end
