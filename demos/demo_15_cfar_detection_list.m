%% demo_15_cfar_detection_list
% Convert a 2D CA-CFAR binary mask into a detection list.
%
% This extends demo_13: CFAR first marks candidate cells, then connected
% component clustering groups adjacent cells into target-report candidates.

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
Np = 64;

targetRange = 4e3;
targetVelocity = 30;
SNRdB = 12;

%% 2D CA-CFAR parameters
trainingRangeCells = 18;
trainingDopplerCells = 6;
guardRangeCells = 4;
guardDopplerCells = 2;
Pfa = 1e-5;

%% Derived values
K = B / tau;
Nfast = round(fs / PRF);
Ntx = round(tau * fs);
tFast = (0:Nfast-1).' / fs;
tPulse = (0:Ntx-1).' / fs;

delayTime = 2 * targetRange / c;
fD = 2 * targetVelocity / lambda;

rangeResolution = c / (2 * B);
velocityBin = lambda * PRF / (2 * Np);

fprintf("Theoretical range resolution: %.2f m\n", rangeResolution);
fprintf("Velocity bin spacing: %.2f m/s\n", velocityBin);
fprintf("2D CA-CFAR: Tr=%d, Td=%d, Gr=%d, Gd=%d, Pfa=%.1e\n", ...
    trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
    guardDopplerCells, Pfa);

%% Transmit waveform and echo synthesis
txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);

rng(61);
targetEcho = complex(zeros(Nfast, Np));
tDelayed = tFast - delayTime;
echoMask = (tDelayed >= 0) & (tDelayed < tau);

for p = 1:Np
    absoluteTime = tFast + (p-1) * PRI;

    onePulseEcho = complex(zeros(Nfast, 1));
    delayedPulse = exp(1j * pi * K * (tDelayed(echoMask) - tau/2).^2);
    dopplerPhase = exp(1j * 2 * pi * fD * absoluteTime(echoMask));
    onePulseEcho(echoMask) = delayedPulse .* dopplerPhase;

    targetEcho(:, p) = onePulseEcho;
end

signalPower = mean(abs(targetEcho(echoMask, 1)).^2);
noisePower = signalPower / 10^(SNRdB / 10);
noise = sqrt(noisePower / 2) * (randn(Nfast, Np) + 1j * randn(Nfast, Np));
rx = targetEcho + noise;

%% Matched filtering along fast time
matchedFilter = conj(flipud(txPulse));
NrangeFull = Nfast + Ntx - 1;
matchedOut = complex(zeros(NrangeFull, Np));

for p = 1:Np
    matchedOut(:, p) = conv(rx(:, p), matchedFilter, "full");
end

rangeAxis = ((0:NrangeFull-1).' - (Ntx - 1)) / fs * c / 2;
validRange = (rangeAxis >= 0) & (rangeAxis <= c / (2 * PRF));
rangeAxis = rangeAxis(validRange);
matchedOut = matchedOut(validRange, :);

%% Doppler FFT along slow time
slowTimeWindow = 0.5 - 0.5 * cos(2 * pi * (0:Np-1) / (Np-1));
rangeDoppler = fftshift(fft(matchedOut .* slowTimeWindow, [], 2), 2);

dopplerAxis = (-Np/2:Np/2-1) * PRF / Np;
velocityAxis = lambda * dopplerAxis / 2;
rdPower = abs(rangeDoppler).^2;

%% 2D CA-CFAR
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

%% Connected components and detection-list postprocessing
components = localConnectedComponents2D(cfarMask);
labelMap = zeros(size(cfarMask));

for iComponent = 1:numel(components)
    labelMap(components{iComponent}) = iComponent;
end

detectionList = localBuildDetectionList(components, rdPower, cfarThreshold, ...
    rangeAxis, velocityAxis, rangeMargin, dopplerMargin);

fprintf("Number of detected CUTs: %d\n", nnz(cfarMask));
fprintf("Number of connected components: %d\n", numel(components));

if isempty(detectionList)
    fprintf("Detection list is empty.\n");
else
    fprintf("Detection list:\n");
    disp(detectionList);
    fprintf("Truth: range %.2f m, velocity %.2f m/s\n", ...
        targetRange, targetVelocity);
end

%% Plots
rdPowerDB = 10 * log10(rdPower / max(rdPower(:)) + eps);

figure("Name", "Demo 15: CFAR Detection List", "Color", "w", ...
    "Position", [100, 100, 1200, 500]);
tiledlayout(1, 3, "Padding", "compact", "TileSpacing", "compact");

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, rdPowerDB);
axis xy;
colorbar;
clim([-60, 0]);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("Range-Doppler power");
hold on;
plot(targetVelocity, targetRange / 1e3, "wo", "MarkerSize", 7, ...
    "LineWidth", 1.3);
localPlotDetectionPeaks(detectionList);

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, cfarMask);
axis xy;
colormap(gca, gray);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("CFAR binary mask");
hold on;
localPlotComponentBoxes(components, rangeAxis, velocityAxis);
localPlotDetectionPeaks(detectionList);

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, labelMap);
axis xy;
colorbar;
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("Connected components");
hold on;
plot(targetVelocity, targetRange / 1e3, "wo", "MarkerSize", 7, ...
    "LineWidth", 1.3);
localPlotDetectionPeaks(detectionList);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_15_cfar_detection_list.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

%% Local functions
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

function detectionList = localBuildDetectionList(components, rdPower, ...
    cfarThreshold, rangeAxis, velocityAxis, rangeMargin, dopplerMargin)

    if isempty(components)
        detectionList = table();
        return;
    end

    [numRangeBins, numDopplerBins] = size(rdPower);
    numDetections = numel(components);

    detectionId = (1:numDetections).';
    rangeM = zeros(numDetections, 1);
    velocityMps = zeros(numDetections, 1);
    clusterSizeCells = zeros(numDetections, 1);
    statisticToThreshold = zeros(numDetections, 1);
    peakPowerDBRel = zeros(numDetections, 1);
    rangeSpanM = zeros(numDetections, 1);
    velocitySpanMps = zeros(numDetections, 1);
    numStrongLocalPeaks = zeros(numDetections, 1);
    touchesTestedEdge = false(numDetections, 1);
    status = strings(numDetections, 1);

    globalPeakPower = max(rdPower(:));

    for iDetection = 1:numDetections
        component = components{iDetection};
        [componentRows, componentCols] = ind2sub(size(rdPower), component);
        componentPower = rdPower(component);
        [peakPower, peakLocalIndex] = max(componentPower);
        peakIndex = component(peakLocalIndex);
        [peakRow, peakCol] = ind2sub(size(rdPower), peakIndex);

        rangeM(iDetection) = rangeAxis(peakRow);
        velocityMps(iDetection) = velocityAxis(peakCol);
        clusterSizeCells(iDetection) = numel(component);
        statisticToThreshold(iDetection) = peakPower / cfarThreshold(peakIndex);
        peakPowerDBRel(iDetection) = 10 * log10(peakPower / globalPeakPower + eps);
        rangeSpanM(iDetection) = max(rangeAxis(componentRows)) ...
            - min(rangeAxis(componentRows));
        velocitySpanMps(iDetection) = max(velocityAxis(componentCols)) ...
            - min(velocityAxis(componentCols));
        numStrongLocalPeaks(iDetection) = localCountStrongLocalPeaks( ...
            component, rdPower, peakPower);

        touchesTestedEdge(iDetection) = any(componentRows <= rangeMargin+1) ...
            || any(componentRows >= numRangeBins-rangeMargin) ...
            || any(componentCols <= dopplerMargin+1) ...
            || any(componentCols >= numDopplerBins-dopplerMargin);

        if touchesTestedEdge(iDetection)
            status(iDetection) = "edge_caveat";
        elseif statisticToThreshold(iDetection) < 3
            status(iDetection) = "weak_margin_review";
        elseif numStrongLocalPeaks(iDetection) > 1
            status(iDetection) = "multi_peak_review";
        else
            status(iDetection) = "resolved_single_peak";
        end
    end

    detectionList = table(detectionId, rangeM, velocityMps, ...
        clusterSizeCells, statisticToThreshold, peakPowerDBRel, ...
        rangeSpanM, velocitySpanMps, numStrongLocalPeaks, ...
        touchesTestedEdge, status);
end

function numStrongLocalPeaks = localCountStrongLocalPeaks(component, rdPower, peakPower)
    [numRows, numCols] = size(rdPower);
    strongPeakThreshold = peakPower / 10^(6 / 10);
    numStrongLocalPeaks = 0;

    for componentIndex = component(:).'
        [row, col] = ind2sub(size(rdPower), componentIndex);
        rowMin = max(1, row - 1);
        rowMax = min(numRows, row + 1);
        colMin = max(1, col - 1);
        colMax = min(numCols, col + 1);

        neighborPatch = rdPower(rowMin:rowMax, colMin:colMax);
        cellPower = rdPower(componentIndex);
        isLocalPeak = cellPower >= max(neighborPatch(:));
        isStrongEnough = cellPower >= strongPeakThreshold;

        if isLocalPeak && isStrongEnough
            numStrongLocalPeaks = numStrongLocalPeaks + 1;
        end
    end
end

function localPlotDetectionPeaks(detectionList)
    if isempty(detectionList)
        return;
    end

    plot(detectionList.velocityMps, detectionList.rangeM / 1e3, "yx", ...
        "MarkerSize", 9, "LineWidth", 1.8);
end

function localPlotComponentBoxes(components, rangeAxis, velocityAxis)
    for iComponent = 1:numel(components)
        [componentRows, componentCols] = ind2sub( ...
            [numel(rangeAxis), numel(velocityAxis)], components{iComponent});

        minVelocity = min(velocityAxis(componentCols));
        maxVelocity = max(velocityAxis(componentCols));
        minRangeKm = min(rangeAxis(componentRows)) / 1e3;
        maxRangeKm = max(rangeAxis(componentRows)) / 1e3;

        width = max(maxVelocity - minVelocity, eps);
        heightKm = max(maxRangeKm - minRangeKm, eps);
        rectangle("Position", [minVelocity, minRangeKm, width, heightKm], ...
            "EdgeColor", "y", "LineWidth", 1.4);
    end
end
