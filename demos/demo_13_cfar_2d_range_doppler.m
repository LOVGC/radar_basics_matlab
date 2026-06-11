%% demo_13_cfar_2d_range_doppler
% 2D CA-CFAR on a range-Doppler power map.

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

detectedLinearIndices = find(cfarMask);
if isempty(detectedLinearIndices)
    fprintf("No detections.\n");
    estimatedRange = nan;
    estimatedVelocity = nan;
else
    [detectedRangeIndices, detectedDopplerIndices] = ind2sub(size(cfarMask), ...
        detectedLinearIndices);
    [~, strongestDetectionLocalIndex] = max(rdPower(detectedLinearIndices));
    strongestDetectionIndex = detectedLinearIndices(strongestDetectionLocalIndex);
    [strongestRangeIndex, strongestDopplerIndex] = ind2sub(size(rdPower), ...
        strongestDetectionIndex);

    estimatedRange = rangeAxis(strongestRangeIndex);
    estimatedVelocity = velocityAxis(strongestDopplerIndex);

    fprintf("Number of detected CUTs: %d\n", numel(detectedLinearIndices));
    fprintf("Strongest detection: range %.2f m, velocity %.2f m/s\n", ...
        estimatedRange, estimatedVelocity);
    fprintf("Truth: range %.2f m, velocity %.2f m/s\n", ...
        targetRange, targetVelocity);
end

%% Plots
rdPowerDB = 10 * log10(rdPower / max(rdPower(:)) + eps);
thresholdDB = 10 * log10(cfarThreshold / max(rdPower(:)) + eps);

figure("Name", "Demo 13: 2D CA-CFAR Range-Doppler", "Color", "w");
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

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, thresholdDB);
axis xy;
colorbar;
clim([-60, 0]);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("2D CA-CFAR threshold");

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, cfarMask);
axis xy;
colormap(gca, gray);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("Detection mask");
hold on;
if ~isempty(detectedLinearIndices)
    plot(velocityAxis(detectedDopplerIndices), ...
        rangeAxis(detectedRangeIndices) / 1e3, "ro", ...
        "MarkerSize", 4, "LineWidth", 1.1);
    plot(estimatedVelocity, estimatedRange / 1e3, "gx", ...
        "MarkerSize", 9, "LineWidth", 1.8);
end
plot(targetVelocity, targetRange / 1e3, "bo", "MarkerSize", 7, ...
    "LineWidth", 1.3);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_13_cfar_2d_range_doppler.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

