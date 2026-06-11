%% demo_12_cfar_1d_range_profile
% 1D CA-CFAR on a matched-filter range profile.

clear; close all; clc;

%% Baseline parameters
c = 299792458;

B = 10e6;
tau = 10e-6;
fs = 20e6;
PRF = 10e3;

targetRange = 4e3;
SNRdB = 14;

numTrainingCells = 32;      % cells on each side of the CUT
numGuardCells = 6;          % cells on each side of the CUT
Pfa = 1e-4;

%% Derived values
K = B / tau;
Nfast = round(fs / PRF);
Ntx = round(tau * fs);
tFast = (0:Nfast-1).' / fs;
tPulse = (0:Ntx-1).' / fs;

rangeResolution = c / (2 * B);
fprintf("Theoretical range resolution: %.2f m\n", rangeResolution);
fprintf("CA-CFAR: %d training cells per side, %d guard cells per side, Pfa = %.1e\n", ...
    numTrainingCells, numGuardCells, Pfa);

%% Transmit waveform and single-target echo
txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);

delayTime = 2 * targetRange / c;
tDelayed = tFast - delayTime;
echoMask = (tDelayed >= 0) & (tDelayed < tau);

targetEcho = complex(zeros(Nfast, 1));
targetEcho(echoMask) = exp(1j * pi * K * (tDelayed(echoMask) - tau/2).^2);

rng(53);
signalPower = mean(abs(targetEcho(echoMask)).^2);
noisePower = signalPower / 10^(SNRdB / 10);
noise = sqrt(noisePower / 2) * (randn(Nfast, 1) + 1j * randn(Nfast, 1));
rx = targetEcho + noise;

%% Matched filter / pulse compression
matchedFilter = conj(flipud(txPulse));
matchedOut = conv(rx, matchedFilter, "full");

rangeAxis = ((0:numel(matchedOut)-1).' - (Ntx - 1)) / fs * c / 2;
validRange = (rangeAxis >= 0) & (rangeAxis <= c / (2 * PRF));
rangeAxis = rangeAxis(validRange);
matchedOut = matchedOut(validRange);

rangePower = abs(matchedOut).^2;

%% CA-CFAR threshold
numCells = numel(rangePower);
numTrainingTotal = 2 * numTrainingCells;
alpha = numTrainingTotal * (Pfa^(-1 / numTrainingTotal) - 1);

cfarThreshold = nan(numCells, 1);
detections = false(numCells, 1);
edgeMargin = numTrainingCells + numGuardCells;

for cutIndex = edgeMargin+1:numCells-edgeMargin
    leftTraining = cutIndex - numGuardCells - numTrainingCells ...
        : cutIndex - numGuardCells - 1;
    rightTraining = cutIndex + numGuardCells + 1 ...
        : cutIndex + numGuardCells + numTrainingCells;

    noiseEstimate = mean(rangePower([leftTraining, rightTraining]));
    cfarThreshold(cutIndex) = alpha * noiseEstimate;
    detections(cutIndex) = rangePower(cutIndex) > cfarThreshold(cutIndex);
end

detectedIndices = find(detections);
detectedRanges = rangeAxis(detectedIndices);

if isempty(detectedRanges)
    fprintf("No detections.\n");
else
    clusterBreaks = [true; diff(detectedIndices) > 1];
    clusterIds = cumsum(clusterBreaks);
    numClusters = clusterIds(end);

    [~, strongestDetectionLocalIndex] = max(rangePower(detectedIndices));
    strongestDetectionIndex = detectedIndices(strongestDetectionLocalIndex);
    estimatedRange = rangeAxis(strongestDetectionIndex);

    fprintf("Number of detected CUTs: %d\n", numel(detectedRanges));
    fprintf("Number of contiguous detection clusters: %d\n", numClusters);
    fprintf("Strongest detection range: %.2f m (truth %.2f m)\n", ...
        estimatedRange, targetRange);
end

%% Plots
profileDB = 10 * log10(rangePower / max(rangePower) + eps);
thresholdDB = 10 * log10(cfarThreshold / max(rangePower) + eps);

figure("Name", "Demo 12: 1D CA-CFAR Range Profile", "Color", "w");
tiledlayout(1, 2, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(rangeAxis / 1e3, profileDB, "LineWidth", 1.1);
grid on;
hold on;
plot(rangeAxis / 1e3, thresholdDB, "LineWidth", 1.2);
if ~isempty(detectedIndices)
    plot(detectedRanges / 1e3, profileDB(detectedIndices), "ro", ...
        "MarkerSize", 5, "LineWidth", 1.2);
end
xline(targetRange / 1e3, "--", "Truth", "LabelVerticalAlignment", "bottom");
xlabel("Range (km)");
ylabel("Normalized power (dB)");
title("Matched-filter range profile with CA-CFAR");
legend("Range profile", "CFAR threshold", "Detected CUTs", ...
    "Location", "southoutside");
xlim([0, c / (2 * PRF) / 1e3]);
ylim([-70, 5]);

nexttile;
rangeZoom = (rangeAxis >= targetRange - 300) & (rangeAxis <= targetRange + 300);
plot(rangeAxis(rangeZoom), profileDB(rangeZoom), "LineWidth", 1.1);
grid on;
hold on;
plot(rangeAxis(rangeZoom), thresholdDB(rangeZoom), "LineWidth", 1.2);
zoomDetectionMask = detections & rangeZoom;
if any(zoomDetectionMask)
    plot(rangeAxis(zoomDetectionMask), profileDB(zoomDetectionMask), "ro", ...
        "MarkerSize", 5, "LineWidth", 1.2);
end
xline(targetRange, "--", "Truth", "LabelVerticalAlignment", "bottom");
xlabel("Range (m)");
ylabel("Normalized power (dB)");
title("Zoom near target");
ylim([-45, 5]);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_12_cfar_1d_range_profile.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);
