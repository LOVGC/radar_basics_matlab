%% demo_20_cfar_before_after_mti
% Compare 2D CA-CFAR before and after two-pulse MTI.
%
% Data model: x[fast time, slow time]. Stationary clutter concentrates near
% zero Doppler, a faster moving target survives MTI, and a slow target near
% zero Doppler can be attenuated by the MTI notch before CFAR sees it.

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

fastTargetRange = 4.0e3;
fastTargetVelocity = 30;
fastTargetAmplitude = 0.65;

slowTargetRange = 5.25e3;
slowTargetVelocity = 1;
slowTargetAmplitude = 0.95;

clutterBaseRanges = (1.2e3:260:8.8e3).';
clutterBaseRanges(abs(clutterBaseRanges - fastTargetRange) < 350) = [];
clutterBaseRanges(abs(clutterBaseRanges - slowTargetRange) < 350) = [];
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
slowTargetDoppler = 2 * slowTargetVelocity / lambda;
fastTargetDoppler = 2 * fastTargetVelocity / lambda;

fprintf("Theoretical range resolution: %.2f m\n", rangeResolution);
fprintf("Velocity bin spacing: %.2f m/s\n", velocityBin);
fprintf("2D CA-CFAR: Tr=%d, Td=%d, Gr=%d, Gd=%d, Pfa=%.1e\n", ...
    trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
    guardDopplerCells, Pfa);
fprintf("Slow target Doppler: %.2f Hz, velocity %.2f m/s\n", ...
    slowTargetDoppler, slowTargetVelocity);
fprintf("Fast target Doppler: %.2f Hz, velocity %.2f m/s\n", ...
    fastTargetDoppler, fastTargetVelocity);

%% Transmit waveform and echo synthesis
txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);

rng(201);
rx = complex(zeros(Nfast, Np));

fastTargetEcho = localPointEcho(fastTargetRange, fastTargetVelocity, ...
    fastTargetAmplitude, txPulse, tFast, PRI, lambda, c, K, tau, Np);
slowTargetEcho = localPointEcho(slowTargetRange, slowTargetVelocity, ...
    slowTargetAmplitude, txPulse, tFast, PRI, lambda, c, K, tau, Np);

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
rx = fastTargetEcho + slowTargetEcho + clutterEcho + noise;

%% Matched filtering along fast time
matchedFilter = conj(flipud(txPulse));
[matchedOut, rangeAxis] = localMatchedFilter(rx, matchedFilter, fs, c, PRF, Ntx);

%% MTI high-pass filtering along slow time
mtiOut = [complex(zeros(size(matchedOut, 1), 1)), diff(matchedOut, 1, 2)];

%% Doppler FFT before and after MTI
slowTimeWindow = 0.5 - 0.5 * cos(2 * pi * (0:Np-1) / (Np-1));
rangeDopplerBefore = fftshift(fft(matchedOut .* slowTimeWindow, [], 2), 2);
rangeDopplerAfter = fftshift(fft(mtiOut .* slowTimeWindow, [], 2), 2);

dopplerAxis = (-Np/2:Np/2-1) * PRF / Np;
velocityAxis = lambda * dopplerAxis / 2;

rdPowerBefore = abs(rangeDopplerBefore).^2;
rdPowerAfter = abs(rangeDopplerAfter).^2;

%% 2D CA-CFAR before and after MTI
[cfarMaskBefore, cfarThresholdBefore, alpha, numTrainingCells] = ...
    localCaCfar2D(rdPowerBefore, trainingRangeCells, trainingDopplerCells, ...
    guardRangeCells, guardDopplerCells, Pfa);
[cfarMaskAfter, cfarThresholdAfter] = localCaCfar2D(rdPowerAfter, ...
    trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
    guardDopplerCells, Pfa);

componentsBefore = localConnectedComponents2D(cfarMaskBefore);
componentsAfter = localConnectedComponents2D(cfarMaskAfter);

truthNames = ["stationary clutter sample"; "slow 1 m/s target"; ...
    "fast 30 m/s target"];
truthRanges = [clutterRanges(round(numel(clutterRanges) / 2)); ...
    slowTargetRange; fastTargetRange];
truthVelocities = [clutterVelocity; slowTargetVelocity; fastTargetVelocity];

summaryTable = localBuildTruthSummary(truthNames, truthRanges, truthVelocities, ...
    rangeAxis, velocityAxis, rdPowerBefore, rdPowerAfter, ...
    cfarThresholdBefore, cfarThresholdAfter, cfarMaskBefore, cfarMaskAfter);

zeroDopplerIndex = find(abs(velocityAxis) == min(abs(velocityAxis)), 1);
zeroDetectionsBefore = nnz(cfarMaskBefore(:, zeroDopplerIndex));
zeroDetectionsAfter = nnz(cfarMaskAfter(:, zeroDopplerIndex));
zeroPowerBefore = sum(rdPowerBefore(:, zeroDopplerIndex));
zeroPowerAfter = sum(rdPowerAfter(:, zeroDopplerIndex));

fprintf("CFAR alpha: %.3f using %d training cells\n", alpha, numTrainingCells);
fprintf("Detected CUTs before MTI: %d, components: %d\n", ...
    nnz(cfarMaskBefore), numel(componentsBefore));
fprintf("Detected CUTs after  MTI: %d, components: %d\n", ...
    nnz(cfarMaskAfter), numel(componentsAfter));
fprintf("Zero-Doppler detected CUTs before/after MTI: %d / %d\n", ...
    zeroDetectionsBefore, zeroDetectionsAfter);
fprintf("Zero-Doppler total power suppression: %.2f dB\n", ...
    10 * log10((zeroPowerBefore + eps) / (zeroPowerAfter + eps)));
fprintf("\nTruth-cell summary:\n");
disp(summaryTable);

%% Plots
referencePower = max(rdPowerBefore(:));
rdBeforeDB = 10 * log10(rdPowerBefore / referencePower + eps);
rdAfterDB = 10 * log10(rdPowerAfter / referencePower + eps);

figure("Name", "Demo 20: CFAR Before and After MTI", "Color", "w", ...
    "Position", [80, 80, 1350, 780]);
tiledlayout(2, 3, "Padding", "compact", "TileSpacing", "compact");

nexttile;
localPlotRangeDoppler(velocityAxis, rangeAxis, rdBeforeDB, ...
    "Before MTI: RD power", truthRanges, truthVelocities);

nexttile;
localPlotCfarMask(velocityAxis, rangeAxis, cfarMaskBefore, ...
    "Before MTI: CFAR mask", truthRanges, truthVelocities);

nexttile;
localPlotTruthMargins(summaryTable);

nexttile;
localPlotRangeDoppler(velocityAxis, rangeAxis, rdAfterDB, ...
    "After MTI: RD power", truthRanges, truthVelocities);

nexttile;
localPlotCfarMask(velocityAxis, rangeAxis, cfarMaskAfter, ...
    "After MTI: CFAR mask", truthRanges, truthVelocities);

nexttile;
localPlotMtiResponse(velocityAxis, PRF, lambda, truthVelocities);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_20_cfar_before_after_mti.png");
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

function components = localConnectedComponents2D(mask)
    [numRows, numCols] = size(mask);
    visited = false(numRows, numCols);
    components = {};
    candidateIndices = find(mask).';

    for seedIndex = candidateIndices
        if visited(seedIndex)
            continue;
        end

        stack = seedIndex;
        visited(seedIndex) = true;
        component = zeros(nnz(mask), 1);
        componentCount = 0;

        while ~isempty(stack)
            currentIndex = stack(end);
            stack(end) = [];
            componentCount = componentCount + 1;
            component(componentCount) = currentIndex;

            [row, col] = ind2sub([numRows, numCols], currentIndex);

            for dRow = -1:1
                for dCol = -1:1
                    if dRow == 0 && dCol == 0
                        continue;
                    end

                    neighborRow = row + dRow;
                    neighborCol = col + dCol;
                    if neighborRow < 1 || neighborRow > numRows ...
                            || neighborCol < 1 || neighborCol > numCols
                        continue;
                    end

                    neighborIndex = sub2ind([numRows, numCols], ...
                        neighborRow, neighborCol);
                    if mask(neighborIndex) && ~visited(neighborIndex)
                        visited(neighborIndex) = true;
                        stack(end+1) = neighborIndex; %#ok<AGROW>
                    end
                end
            end
        end

        components{end+1} = component(1:componentCount); %#ok<AGROW>
    end
end

function summaryTable = localBuildTruthSummary(truthNames, truthRanges, truthVelocities, ...
    rangeAxis, velocityAxis, rdPowerBefore, rdPowerAfter, ...
    cfarThresholdBefore, cfarThresholdAfter, cfarMaskBefore, cfarMaskAfter)

    numTruth = numel(truthNames);
    nearestRangeM = zeros(numTruth, 1);
    nearestVelocityMps = zeros(numTruth, 1);
    statisticBefore = zeros(numTruth, 1);
    statisticAfter = zeros(numTruth, 1);
    thresholdBefore = zeros(numTruth, 1);
    thresholdAfter = zeros(numTruth, 1);
    marginBefore = zeros(numTruth, 1);
    marginAfter = zeros(numTruth, 1);
    powerChangeDb = zeros(numTruth, 1);
    detectedBefore = false(numTruth, 1);
    detectedAfter = false(numTruth, 1);

    for iTruth = 1:numTruth
        [~, rangeIndex] = min(abs(rangeAxis - truthRanges(iTruth)));
        [~, velocityIndex] = min(abs(velocityAxis - truthVelocities(iTruth)));
        rangeWindow = max(1, rangeIndex-2):min(numel(rangeAxis), rangeIndex+2);
        velocityWindow = max(1, velocityIndex-2):min(numel(velocityAxis), velocityIndex+2);

        beforePatch = rdPowerBefore(rangeWindow, velocityWindow);
        afterPatch = rdPowerAfter(rangeWindow, velocityWindow);
        thresholdBeforePatch = cfarThresholdBefore(rangeWindow, velocityWindow);
        thresholdAfterPatch = cfarThresholdAfter(rangeWindow, velocityWindow);

        [statisticBefore(iTruth), beforeLocalIndex] = max(beforePatch(:));
        [statisticAfter(iTruth), afterLocalIndex] = max(afterPatch(:));

        beforeThresholdValue = thresholdBeforePatch(beforeLocalIndex);
        afterThresholdValue = thresholdAfterPatch(afterLocalIndex);
        thresholdBefore(iTruth) = beforeThresholdValue;
        thresholdAfter(iTruth) = afterThresholdValue;
        marginBefore(iTruth) = statisticBefore(iTruth) / beforeThresholdValue;
        marginAfter(iTruth) = statisticAfter(iTruth) / afterThresholdValue;
        powerChangeDb(iTruth) = 10 * log10((statisticAfter(iTruth) + eps) ...
            / (statisticBefore(iTruth) + eps));

        detectedBefore(iTruth) = any(cfarMaskBefore(rangeWindow, velocityWindow), "all");
        detectedAfter(iTruth) = any(cfarMaskAfter(rangeWindow, velocityWindow), "all");

        nearestRangeM(iTruth) = rangeAxis(rangeIndex);
        nearestVelocityMps(iTruth) = velocityAxis(velocityIndex);
    end

    summaryTable = table(truthNames, nearestRangeM, nearestVelocityMps, ...
        statisticBefore, thresholdBefore, marginBefore, detectedBefore, ...
        statisticAfter, thresholdAfter, marginAfter, detectedAfter, ...
        powerChangeDb);
end

function localPlotRangeDoppler(velocityAxis, rangeAxis, rdPowerDB, plotTitle, ...
    truthRanges, truthVelocities)

    imagesc(velocityAxis, rangeAxis / 1e3, rdPowerDB);
    axis xy;
    colorbar;
    clim([-65, 0]);
    xlabel("Velocity (m/s)");
    ylabel("Range (km)");
    title(plotTitle);
    hold on;
    localPlotTruthMarkers(truthRanges, truthVelocities);
    xline(0, "w--", "0 m/s", "HandleVisibility", "off");
end

function localPlotCfarMask(velocityAxis, rangeAxis, cfarMask, plotTitle, ...
    truthRanges, truthVelocities)

    imagesc(velocityAxis, rangeAxis / 1e3, cfarMask);
    axis xy;
    colormap(gca, gray);
    xlabel("Velocity (m/s)");
    ylabel("Range (km)");
    title(plotTitle);
    hold on;
    localPlotTruthMarkers(truthRanges, truthVelocities);
    xline(0, "r--", "0 m/s", "HandleVisibility", "off");
end

function localPlotTruthMarkers(truthRanges, truthVelocities)
    plot(truthVelocities(1), truthRanges(1) / 1e3, "ys", ...
        "MarkerSize", 8, "LineWidth", 1.5, "DisplayName", "clutter sample");
    plot(truthVelocities(2), truthRanges(2) / 1e3, "c^", ...
        "MarkerSize", 8, "LineWidth", 1.5, "DisplayName", "slow target");
    plot(truthVelocities(3), truthRanges(3) / 1e3, "wo", ...
        "MarkerSize", 8, "LineWidth", 1.5, "DisplayName", "fast target");
end

function localPlotTruthMargins(summaryTable)
    margins = [summaryTable.marginBefore, summaryTable.marginAfter];
    marginsDB = 10 * log10(margins + eps);
    bar(marginsDB);
    grid on;
    yline(0, "k--", "threshold", "HandleVisibility", "off");
    xticks(1:height(summaryTable));
    xticklabels(["clutter", "slow", "fast"]);
    ylabel("Statistic / threshold (dB)");
    title("Truth-cell CFAR margins");
    legend(["Before MTI", "After MTI"], "Location", "southoutside", ...
        "Orientation", "horizontal");
end

function localPlotMtiResponse(velocityAxis, PRF, lambda, truthVelocities)
    dopplerHz = 2 * velocityAxis / lambda;
    response = abs(1 - exp(-1j * 2 * pi * dopplerHz / PRF));
    responseDB = 20 * log10(response + eps);

    plot(velocityAxis, responseDB, "k-", "LineWidth", 1.2);
    grid on;
    xlabel("Velocity (m/s)");
    ylabel("Magnitude (dB)");
    title("Two-pulse MTI response");
    xline(0, "r--", "0 m/s notch", "HandleVisibility", "off");
    hold on;
    for iTruth = 1:numel(truthVelocities)
        truthResponse = abs(1 - exp(-1j * 2 * pi ...
            * (2 * truthVelocities(iTruth) / lambda) / PRF));
        plot(truthVelocities(iTruth), 20 * log10(truthResponse + eps), ...
            "o", "MarkerSize", 6, "LineWidth", 1.4);
    end
    ylim([-70, 8]);
end
