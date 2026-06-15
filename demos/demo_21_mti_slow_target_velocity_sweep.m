%% demo_21_mti_slow_target_velocity_sweep
% Sweep target velocity to show slow-target loss from two-pulse MTI.
%
% Demo 20 showed one slow target. This demo turns that into a curve: for the
% same target range and amplitude, lower radial velocity means lower Doppler
% frequency, stronger MTI attenuation, and potentially lower CFAR margin.

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

targetRange = 5.25e3;
targetAmplitude = 0.18;
velocitySweep = [0, 0.1, 0.25, 0.5, 0.75, 1, 1.5, 2, 3, 5, 8, 12, 20, 30].';

clutterBaseRanges = (1.2e3:260:8.8e3).';
clutterBaseRanges(abs(clutterBaseRanges - targetRange) < 350) = [];
clutterVelocity = 0;
clutterAmplitude = 3.2;

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
fprintf("Target amplitude: %.3f\n", targetAmplitude);
fprintf("2D CA-CFAR: Tr=%d, Td=%d, Gr=%d, Gd=%d, Pfa=%.1e\n", ...
    trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
    guardDopplerCells, Pfa);

%% Transmit waveform and fixed background synthesis
txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);

rng(211);
clutterEcho = complex(zeros(Nfast, Np));
clutterRanges = clutterBaseRanges + 8 * randn(size(clutterBaseRanges));
clutterPhase = exp(1j * 2 * pi * rand(numel(clutterRanges), 1));
for iClutter = 1:numel(clutterRanges)
    amplitudeJitter = clutterAmplitude * (0.75 + 0.5 * rand);
    clutterEcho = clutterEcho + localPointEcho( ...
        clutterRanges(iClutter), clutterVelocity, ...
        amplitudeJitter * clutterPhase(iClutter), txPulse, tFast, ...
        PRI, lambda, c, K, tau, Np);
end

noise = sqrt(noisePower / 2) * (randn(Nfast, Np) + 1j * randn(Nfast, Np));
backgroundRx = clutterEcho + noise;

%% Sweep target velocity
matchedFilter = conj(flipud(txPulse));
numVelocities = numel(velocitySweep);

statisticBefore = zeros(numVelocities, 1);
statisticAfter = zeros(numVelocities, 1);
thresholdBefore = zeros(numVelocities, 1);
thresholdAfter = zeros(numVelocities, 1);
marginBefore = zeros(numVelocities, 1);
marginAfter = zeros(numVelocities, 1);
powerChangeDb = zeros(numVelocities, 1);
detectedBefore = false(numVelocities, 1);
detectedAfter = false(numVelocities, 1);
expectedMtiGainDb = zeros(numVelocities, 1);

for iVelocity = 1:numVelocities
    targetVelocity = velocitySweep(iVelocity);
    targetEcho = localPointEcho(targetRange, targetVelocity, ...
        targetAmplitude, txPulse, tFast, PRI, lambda, c, K, tau, Np);
    rx = backgroundRx + targetEcho;

    [matchedOut, rangeAxis] = localMatchedFilter(rx, matchedFilter, fs, c, PRF, Ntx);
    mtiOut = [complex(zeros(size(matchedOut, 1), 1)), diff(matchedOut, 1, 2)];

    [rdPowerBefore, rdPowerAfter, velocityAxis] = localRangeDopplerPower( ...
        matchedOut, mtiOut, Np, PRF, lambda);

    [cfarMaskBefore, cfarThresholdBefore] = localCaCfar2D(rdPowerBefore, ...
        trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
        guardDopplerCells, Pfa);
    [cfarMaskAfter, cfarThresholdAfter] = localCaCfar2D(rdPowerAfter, ...
        trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
        guardDopplerCells, Pfa);

    summary = localTruthCellSummary(targetRange, targetVelocity, ...
        rangeAxis, velocityAxis, rdPowerBefore, rdPowerAfter, ...
        cfarThresholdBefore, cfarThresholdAfter, cfarMaskBefore, cfarMaskAfter);

    statisticBefore(iVelocity) = summary.statisticBefore;
    statisticAfter(iVelocity) = summary.statisticAfter;
    thresholdBefore(iVelocity) = summary.thresholdBefore;
    thresholdAfter(iVelocity) = summary.thresholdAfter;
    marginBefore(iVelocity) = summary.marginBefore;
    marginAfter(iVelocity) = summary.marginAfter;
    powerChangeDb(iVelocity) = summary.powerChangeDb;
    detectedBefore(iVelocity) = summary.detectedBefore;
    detectedAfter(iVelocity) = summary.detectedAfter;

    dopplerHz = 2 * targetVelocity / lambda;
    mtiGain = abs(1 - exp(-1j * 2 * pi * dopplerHz / PRF));
    expectedMtiGainDb(iVelocity) = 20 * log10(mtiGain + eps);
end

resultTable = table(velocitySweep, statisticBefore, thresholdBefore, ...
    marginBefore, detectedBefore, statisticAfter, thresholdAfter, ...
    marginAfter, detectedAfter, powerChangeDb, expectedMtiGainDb);

fprintf("\nSlow-target velocity sweep:\n");
disp(resultTable);

firstDetectedIndex = find(detectedAfter, 1, "first");
if isempty(firstDetectedIndex)
    fprintf("After MTI, no swept velocity was detected near the target cell.\n");
else
    fprintf("First swept velocity detected after MTI: %.2f m/s\n", ...
        velocitySweep(firstDetectedIndex));
end

%% Plots
velocityFine = linspace(0, max(velocitySweep), 500).';
dopplerFine = 2 * velocityFine / lambda;
mtiGainFine = abs(1 - exp(-1j * 2 * pi * dopplerFine / PRF));
mtiGainFineDB = 20 * log10(mtiGainFine + eps);

figure("Name", "Demo 21: MTI Slow-Target Velocity Sweep", "Color", "w", ...
    "Position", [100, 100, 1250, 760]);
tiledlayout(2, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(velocityFine, mtiGainFineDB, "k-", "LineWidth", 1.2);
hold on;
plot(velocitySweep, expectedMtiGainDb, "o", "LineWidth", 1.2);
grid on;
xlabel("Target radial velocity (m/s)");
ylabel("MTI magnitude (dB)");
title("Two-pulse MTI response near zero velocity");
ylim([-80, 8]);

nexttile;
plot(velocitySweep, powerChangeDb, "o-", "LineWidth", 1.2);
grid on;
xlabel("Target radial velocity (m/s)");
ylabel("Post/Pre target statistic (dB)");
title("Measured RD power change after MTI");
ylim([-80, 8]);

nexttile;
marginBeforeDB = 10 * log10(marginBefore + eps);
marginAfterDB = 10 * log10(marginAfter + eps);
plot(velocitySweep, marginBeforeDB, "o-", "LineWidth", 1.2, ...
    "DisplayName", "Before MTI");
hold on;
plot(velocitySweep, marginAfterDB, "s-", "LineWidth", 1.2, ...
    "DisplayName", "After MTI");
yline(0, "k--", "CFAR threshold", "HandleVisibility", "off");
grid on;
xlabel("Target radial velocity (m/s)");
ylabel("Statistic / threshold (dB)");
title("CFAR margin versus target velocity");
legend("Location", "southoutside", "Orientation", "horizontal");

nexttile;
plot(velocitySweep, double(detectedBefore), "o-", "LineWidth", 1.2, ...
    "DisplayName", "Before MTI");
hold on;
plot(velocitySweep, double(detectedAfter), "s-", "LineWidth", 1.2, ...
    "DisplayName", "After MTI");
grid on;
xlabel("Target radial velocity (m/s)");
ylabel("Detected near target cell");
title("CFAR detection decision");
yticks([0, 1]);
yticklabels(["missed", "detected"]);
legend("Location", "southoutside", "Orientation", "horizontal");
ylim([0, 1.2]);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_21_mti_slow_target_velocity_sweep.png");
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

function [rdPowerBefore, rdPowerAfter, velocityAxis] = localRangeDopplerPower( ...
    matchedOut, mtiOut, Np, PRF, lambda)

    slowTimeWindow = 0.5 - 0.5 * cos(2 * pi * (0:Np-1) / (Np-1));
    rangeDopplerBefore = fftshift(fft(matchedOut .* slowTimeWindow, [], 2), 2);
    rangeDopplerAfter = fftshift(fft(mtiOut .* slowTimeWindow, [], 2), 2);

    dopplerAxis = (-Np/2:Np/2-1) * PRF / Np;
    velocityAxis = lambda * dopplerAxis / 2;

    rdPowerBefore = abs(rangeDopplerBefore).^2;
    rdPowerAfter = abs(rangeDopplerAfter).^2;
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

function summary = localTruthCellSummary(targetRange, targetVelocity, ...
    rangeAxis, velocityAxis, rdPowerBefore, rdPowerAfter, ...
    cfarThresholdBefore, cfarThresholdAfter, cfarMaskBefore, cfarMaskAfter)

    [~, rangeIndex] = min(abs(rangeAxis - targetRange));
    [~, velocityIndex] = min(abs(velocityAxis - targetVelocity));
    rangeWindow = max(1, rangeIndex-2):min(numel(rangeAxis), rangeIndex+2);
    velocityWindow = max(1, velocityIndex-2):min(numel(velocityAxis), velocityIndex+2);

    beforePatch = rdPowerBefore(rangeWindow, velocityWindow);
    afterPatch = rdPowerAfter(rangeWindow, velocityWindow);
    thresholdBeforePatch = cfarThresholdBefore(rangeWindow, velocityWindow);
    thresholdAfterPatch = cfarThresholdAfter(rangeWindow, velocityWindow);

    [summary.statisticBefore, beforeLocalIndex] = max(beforePatch(:));
    [summary.statisticAfter, afterLocalIndex] = max(afterPatch(:));

    summary.thresholdBefore = thresholdBeforePatch(beforeLocalIndex);
    summary.thresholdAfter = thresholdAfterPatch(afterLocalIndex);
    summary.marginBefore = summary.statisticBefore / summary.thresholdBefore;
    summary.marginAfter = summary.statisticAfter / summary.thresholdAfter;
    summary.powerChangeDb = 10 * log10((summary.statisticAfter + eps) ...
        / (summary.statisticBefore + eps));
    summary.detectedBefore = any(cfarMaskBefore(rangeWindow, velocityWindow), "all");
    summary.detectedAfter = any(cfarMaskAfter(rangeWindow, velocityWindow), "all");
end
