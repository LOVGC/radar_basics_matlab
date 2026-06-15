%% demo_22_doppler_spread_clutter_mti
% Compare MTI on exactly stationary clutter versus Doppler-spread clutter.
%
% Stationary clutter is nearly constant in slow time, so two-pulse MTI can
% strongly suppress its zero-Doppler ridge. Real clutter can have a velocity
% spread from platform motion, wind, sea/foliage motion, or model mismatch;
% that spread moves energy away from the exact MTI notch and leaves residual
% low-Doppler clutter after filtering.

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

targetRange = 4.0e3;
targetVelocity = 12;
targetAmplitude = 0.45;

clutterBaseRanges = (1.2e3:160:8.8e3).';
clutterBaseRanges(abs(clutterBaseRanges - targetRange) < 300) = [];
clutterAmplitude = 2.0;
dopplerSpreadStdMps = 2.0;

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
targetDoppler = 2 * targetVelocity / lambda;

fprintf("Theoretical range resolution: %.2f m\n", rangeResolution);
fprintf("Velocity bin spacing: %.2f m/s\n", velocityBin);
fprintf("Target Doppler: %.2f Hz, target velocity %.2f m/s\n", ...
    targetDoppler, targetVelocity);
fprintf("Doppler-spread clutter std: %.2f m/s\n", dopplerSpreadStdMps);
fprintf("2D CA-CFAR: Tr=%d, Td=%d, Gr=%d, Gd=%d, Pfa=%.1e\n", ...
    trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
    guardDopplerCells, Pfa);

%% Shared waveform, clutter geometry, and noise
txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);

rng(221);
clutterRanges = clutterBaseRanges + 8 * randn(size(clutterBaseRanges));
clutterPhases = exp(1j * 2 * pi * rand(numel(clutterRanges), 1));
clutterAmplitudes = clutterAmplitude * (0.75 + 0.5 * rand(numel(clutterRanges), 1)) ...
    .* clutterPhases;

stationaryClutterVelocities = zeros(size(clutterRanges));
spreadClutterVelocities = dopplerSpreadStdMps * randn(size(clutterRanges));
spreadClutterVelocities = max(min(spreadClutterVelocities, 4 * dopplerSpreadStdMps), ...
    -4 * dopplerSpreadStdMps);

noise = sqrt(noisePower / 2) * (randn(Nfast, Np) + 1j * randn(Nfast, Np));

%% Run both clutter scenarios
scenarioNames = ["stationary clutter"; "Doppler-spread clutter"];
clutterVelocitySets = {stationaryClutterVelocities, spreadClutterVelocities};
scenarioResults = cell(2, 1);

for iScenario = 1:2
    scenarioResults{iScenario} = localRunScenario( ...
        clutterVelocitySets{iScenario}, targetRange, targetVelocity, ...
        targetAmplitude, clutterRanges, clutterAmplitudes, noise, ...
        txPulse, tFast, PRI, lambda, c, K, tau, Np, fs, PRF, Ntx, ...
        trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
        guardDopplerCells, Pfa);
end

summaryTable = localBuildScenarioSummary(scenarioNames, scenarioResults, ...
    targetRange, targetVelocity);

fprintf("\nMTI and CFAR summary:\n");
disp(summaryTable);

fprintf("Spread-clutter velocity percentiles (m/s): %.2f, %.2f, %.2f\n", ...
    prctile(spreadClutterVelocities, 10), prctile(spreadClutterVelocities, 50), ...
    prctile(spreadClutterVelocities, 90));

%% Plots
referencePower = max(scenarioResults{1}.rdPowerBefore(:));

figure("Name", "Demo 22: Doppler-Spread Clutter and MTI", "Color", "w", ...
    "Position", [60, 80, 1500, 760]);
tiledlayout(2, 4, "Padding", "compact", "TileSpacing", "compact");

nexttile(1);
localPlotRangeDoppler(scenarioResults{1}, referencePower, ...
    "Stationary clutter: before MTI", targetRange, targetVelocity);

nexttile(2);
localPlotRangeDopplerAfter(scenarioResults{1}, referencePower, ...
    "Stationary clutter: after MTI", targetRange, targetVelocity);

nexttile(3);
localPlotCfarMask(scenarioResults{1}, ...
    "Stationary clutter: after-MTI CFAR", targetRange, targetVelocity);

nexttile(5);
localPlotRangeDoppler(scenarioResults{2}, referencePower, ...
    "Doppler-spread clutter: before MTI", targetRange, targetVelocity);

nexttile(6);
localPlotRangeDopplerAfter(scenarioResults{2}, referencePower, ...
    "Doppler-spread clutter: after MTI", targetRange, targetVelocity);

nexttile(7);
localPlotCfarMask(scenarioResults{2}, ...
    "Doppler-spread clutter: after-MTI CFAR", targetRange, targetVelocity);

nexttile(4, [2, 1]);
localPlotDopplerProfiles(scenarioResults, scenarioNames);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_22_doppler_spread_clutter_mti.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

%% Local functions
function result = localRunScenario(clutterVelocities, targetRange, targetVelocity, ...
    targetAmplitude, clutterRanges, clutterAmplitudes, noise, txPulse, tFast, ...
    PRI, lambda, c, K, tau, Np, fs, PRF, Ntx, trainingRangeCells, ...
    trainingDopplerCells, guardRangeCells, guardDopplerCells, Pfa)

    Nfast = numel(tFast);
    clutterEcho = complex(zeros(Nfast, Np));
    for iClutter = 1:numel(clutterRanges)
        clutterEcho = clutterEcho + localPointEcho( ...
            clutterRanges(iClutter), clutterVelocities(iClutter), ...
            clutterAmplitudes(iClutter), txPulse, tFast, PRI, lambda, ...
            c, K, tau, Np);
    end

    targetEcho = localPointEcho(targetRange, targetVelocity, targetAmplitude, ...
        txPulse, tFast, PRI, lambda, c, K, tau, Np);
    rx = clutterEcho + targetEcho + noise;

    matchedFilter = conj(flipud(txPulse));
    [matchedOut, rangeAxis] = localMatchedFilter(rx, matchedFilter, fs, c, PRF, Ntx);
    mtiOut = [complex(zeros(size(matchedOut, 1), 1)), diff(matchedOut, 1, 2)];

    slowTimeWindow = 0.5 - 0.5 * cos(2 * pi * (0:Np-1) / (Np-1));
    rangeDopplerBefore = fftshift(fft(matchedOut .* slowTimeWindow, [], 2), 2);
    rangeDopplerAfter = fftshift(fft(mtiOut .* slowTimeWindow, [], 2), 2);

    dopplerAxis = (-Np/2:Np/2-1) * PRF / Np;
    velocityAxis = lambda * dopplerAxis / 2;
    rdPowerBefore = abs(rangeDopplerBefore).^2;
    rdPowerAfter = abs(rangeDopplerAfter).^2;

    [cfarMaskAfter, cfarThresholdAfter] = localCaCfar2D(rdPowerAfter, ...
        trainingRangeCells, trainingDopplerCells, guardRangeCells, ...
        guardDopplerCells, Pfa);

    result.rangeAxis = rangeAxis;
    result.velocityAxis = velocityAxis;
    result.rdPowerBefore = rdPowerBefore;
    result.rdPowerAfter = rdPowerAfter;
    result.cfarMaskAfter = cfarMaskAfter;
    result.cfarThresholdAfter = cfarThresholdAfter;
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

function summaryTable = localBuildScenarioSummary(scenarioNames, scenarioResults, ...
    targetRange, targetVelocity)

    numScenarios = numel(scenarioResults);
    zeroDopplerSuppressionDb = zeros(numScenarios, 1);
    lowDopplerPowerSuppressionDb = zeros(numScenarios, 1);
    afterMtiDetectedCuts = zeros(numScenarios, 1);
    afterMtiLowDopplerDetectedCuts = zeros(numScenarios, 1);
    targetStatistic = zeros(numScenarios, 1);
    targetThreshold = zeros(numScenarios, 1);
    targetMargin = zeros(numScenarios, 1);
    targetDetected = false(numScenarios, 1);

    for iScenario = 1:numScenarios
        result = scenarioResults{iScenario};
        velocityAxis = result.velocityAxis;
        rangeAxis = result.rangeAxis;
        zeroDopplerIndex = find(abs(velocityAxis) == min(abs(velocityAxis)), 1);
        lowDopplerMask = abs(velocityAxis) <= 5;

        zeroBefore = sum(result.rdPowerBefore(:, zeroDopplerIndex));
        zeroAfter = sum(result.rdPowerAfter(:, zeroDopplerIndex));
        lowBefore = sum(result.rdPowerBefore(:, lowDopplerMask), "all");
        lowAfter = sum(result.rdPowerAfter(:, lowDopplerMask), "all");

        zeroDopplerSuppressionDb(iScenario) = 10 * log10((zeroBefore + eps) ...
            / (zeroAfter + eps));
        lowDopplerPowerSuppressionDb(iScenario) = 10 * log10((lowBefore + eps) ...
            / (lowAfter + eps));
        afterMtiDetectedCuts(iScenario) = nnz(result.cfarMaskAfter);
        afterMtiLowDopplerDetectedCuts(iScenario) = nnz( ...
            result.cfarMaskAfter(:, lowDopplerMask));

        [~, rangeIndex] = min(abs(rangeAxis - targetRange));
        [~, velocityIndex] = min(abs(velocityAxis - targetVelocity));
        rangeWindow = max(1, rangeIndex-2):min(numel(rangeAxis), rangeIndex+2);
        velocityWindow = max(1, velocityIndex-2):min(numel(velocityAxis), velocityIndex+2);
        targetPatch = result.rdPowerAfter(rangeWindow, velocityWindow);
        thresholdPatch = result.cfarThresholdAfter(rangeWindow, velocityWindow);
        [targetStatistic(iScenario), localIndex] = max(targetPatch(:));
        targetThreshold(iScenario) = thresholdPatch(localIndex);
        targetMargin(iScenario) = targetStatistic(iScenario) / targetThreshold(iScenario);
        targetDetected(iScenario) = any(result.cfarMaskAfter(rangeWindow, velocityWindow), "all");
    end

    summaryTable = table(scenarioNames(:), zeroDopplerSuppressionDb, ...
        lowDopplerPowerSuppressionDb, afterMtiDetectedCuts, ...
        afterMtiLowDopplerDetectedCuts, targetStatistic, targetThreshold, ...
        targetMargin, targetDetected, 'VariableNames', { ...
        'scenario', 'zeroDopplerSuppressionDb', 'lowDopplerPowerSuppressionDb', ...
        'afterMtiDetectedCuts', 'afterMtiLowDopplerDetectedCuts', ...
        'targetStatistic', 'targetThreshold', 'targetMargin', 'targetDetected'});
end

function localPlotRangeDoppler(result, referencePower, plotTitle, targetRange, targetVelocity)
    rdPowerDB = 10 * log10(result.rdPowerBefore / referencePower + eps);
    imagesc(result.velocityAxis, result.rangeAxis / 1e3, rdPowerDB);
    axis xy;
    colorbar;
    clim([-65, 0]);
    xlabel("Velocity (m/s)");
    ylabel("Range (km)");
    title(plotTitle);
    hold on;
    plot(targetVelocity, targetRange / 1e3, "wo", "MarkerSize", 8, ...
        "LineWidth", 1.4);
    xline(0, "w--", "0 m/s", "HandleVisibility", "off");
end

function localPlotRangeDopplerAfter(result, referencePower, plotTitle, targetRange, targetVelocity)
    rdPowerDB = 10 * log10(result.rdPowerAfter / referencePower + eps);
    imagesc(result.velocityAxis, result.rangeAxis / 1e3, rdPowerDB);
    axis xy;
    colorbar;
    clim([-65, 0]);
    xlabel("Velocity (m/s)");
    ylabel("Range (km)");
    title(plotTitle);
    hold on;
    plot(targetVelocity, targetRange / 1e3, "wo", "MarkerSize", 8, ...
        "LineWidth", 1.4);
    xline(0, "w--", "0 m/s", "HandleVisibility", "off");
end

function localPlotCfarMask(result, plotTitle, targetRange, targetVelocity)
    imagesc(result.velocityAxis, result.rangeAxis / 1e3, result.cfarMaskAfter);
    axis xy;
    colormap(gca, gray);
    xlabel("Velocity (m/s)");
    ylabel("Range (km)");
    title(plotTitle);
    hold on;
    plot(targetVelocity, targetRange / 1e3, "co", "MarkerSize", 8, ...
        "LineWidth", 1.4);
    xline(0, "r--", "0 m/s", "HandleVisibility", "off");
end

function localPlotDopplerProfiles(scenarioResults, scenarioNames)
    hold on;
    colors = lines(numel(scenarioResults));
    for iScenario = 1:numel(scenarioResults)
        result = scenarioResults{iScenario};
        profileAfter = sum(result.rdPowerAfter, 1);
        profileAfterDB = 10 * log10(profileAfter / max(profileAfter) + eps);
        plot(result.velocityAxis, profileAfterDB, "LineWidth", 1.2, ...
            "Color", colors(iScenario, :), ...
            "DisplayName", scenarioNames(iScenario));
    end
    grid on;
    xlabel("Velocity (m/s)");
    ylabel("After-MTI power (dB rel.)");
    title("Doppler profile after MTI");
    xlim([-18, 18]);
    ylim([-70, 3]);
    legend("Location", "southoutside", "Orientation", "horizontal");
end
