%% demo_06_single_target_rda_cube
% First end-to-end range-Doppler-angle demo.
% Data model: x[fast time, slow time, array element].

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

M = 8;
d = lambda / 2;
targetRange = 4e3;
targetVelocity = 30;
targetAngleDeg = 20;
SNRdB = 15;

%% Derived values
K = B / tau;
Nfast = round(fs / PRF);
Ntx = round(tau * fs);
tFast = (0:Nfast-1).' / fs;
tPulse = (0:Ntx-1).' / fs;
elementIndex = (0:M-1).';

delayTime = 2 * targetRange / c;
fD = 2 * targetVelocity / lambda;

rangeResolution = c / (2 * B);
dopplerBinHz = PRF / Np;
velocityBin = lambda * dopplerBinHz / 2;

fprintf("Theoretical range resolution: %.2f m\n", rangeResolution);
fprintf("Velocity bin spacing: %.2f m/s\n", velocityBin);

%% Waveform and ULA steering vector
txPulse = exp(1j * pi * K * (tPulse - tau/2).^2);
steer = @(thetaDeg) exp(-1j * 2 * pi * elementIndex * d ...
    .* sind(thetaDeg) / lambda);
targetSteering = steer(targetAngleDeg);

%% Echo synthesis: x[fast time, slow time, array element]
rng(19);
targetEcho = complex(zeros(Nfast, Np, M));
tDelayed = tFast - delayTime;
echoMask = (tDelayed >= 0) & (tDelayed < tau);

for p = 1:Np
    absoluteTime = tFast + (p-1) * PRI;

    fastSlowEcho = complex(zeros(Nfast, 1));
    delayedPulse = exp(1j * pi * K * (tDelayed(echoMask) - tau/2).^2);
    dopplerPhase = exp(1j * 2 * pi * fD * absoluteTime(echoMask));
    fastSlowEcho(echoMask) = delayedPulse .* dopplerPhase;

    for m = 1:M
        targetEcho(:, p, m) = fastSlowEcho * targetSteering(m);
    end
end

signalPower = mean(abs(targetEcho(echoMask, 1, 1)).^2);
noisePower = signalPower / 10^(SNRdB / 10);
noise = sqrt(noisePower / 2) ...
    * (randn(Nfast, Np, M) + 1j * randn(Nfast, Np, M));
rx = targetEcho + noise;

fprintf("rx size: [%d fast-time samples, %d pulses, %d elements]\n", ...
    size(rx, 1), size(rx, 2), size(rx, 3));

%% Matched filter along fast time
matchedFilter = conj(flipud(txPulse));
NrangeFull = Nfast + Ntx - 1;
matchedOut = complex(zeros(NrangeFull, Np, M));

for m = 1:M
    for p = 1:Np
        matchedOut(:, p, m) = conv(rx(:, p, m), matchedFilter, "full");
    end
end

rangeAxis = ((0:NrangeFull-1).' - (Ntx - 1)) / fs * c / 2;
validRange = (rangeAxis >= 0) & (rangeAxis <= c / (2 * PRF));
rangeAxis = rangeAxis(validRange);
matchedOut = matchedOut(validRange, :, :);

%% Doppler FFT along slow time
slowTimeWindow = reshape(0.5 - 0.5 * cos(2 * pi * (0:Np-1) / (Np-1)), ...
    1, Np, 1);
rangeDopplerAngle = fftshift(fft(matchedOut .* slowTimeWindow, [], 2), 2);

dopplerAxis = (-Np/2:Np/2-1) * PRF / Np;
velocityAxis = lambda * dopplerAxis / 2;

%% Pick range-Doppler peak using noncoherent sum across elements
rangeDopplerPower = sum(abs(rangeDopplerAngle).^2, 3);
[~, peakLinearIndex] = max(rangeDopplerPower(:));
[peakRangeIndex, peakDopplerIndex] = ind2sub(size(rangeDopplerPower), peakLinearIndex);

estimatedRange = rangeAxis(peakRangeIndex);
estimatedVelocity = velocityAxis(peakDopplerIndex);
arraySnapshot = squeeze(rangeDopplerAngle(peakRangeIndex, peakDopplerIndex, :));

%% Angle scan along array element
scanAnglesDeg = -90:0.05:90;
beamResponse = zeros(size(scanAnglesDeg));

for iAngle = 1:numel(scanAnglesDeg)
    candidateSteering = steer(scanAnglesDeg(iAngle));
    beamResponse(iAngle) = abs(candidateSteering' * arraySnapshot) / M;
end

beamResponseDB = 20 * log10(beamResponse / max(beamResponse) + eps);
[~, peakAngleIndex] = max(beamResponse);
estimatedAngleDeg = scanAnglesDeg(peakAngleIndex);

fprintf("Estimated range: %.2f m (truth %.2f m)\n", ...
    estimatedRange, targetRange);
fprintf("Estimated velocity: %.2f m/s (truth %.2f m/s)\n", ...
    estimatedVelocity, targetVelocity);
fprintf("Estimated angle: %.2f deg (truth %.2f deg)\n", ...
    estimatedAngleDeg, targetAngleDeg);

%% Plots
mfProfile = sqrt(sum(abs(matchedOut(:, 1, :)).^2, 3));
mfProfileDB = 20 * log10(mfProfile / max(mfProfile) + eps);

rdMagnitudeDB = 10 * log10(rangeDopplerPower / max(rangeDopplerPower(:)) + eps);

figure("Name", "Demo 06: Single Target RDA Cube", "Color", "w");
tiledlayout(1, 3, "Padding", "compact", "TileSpacing", "compact");

nexttile;
plot(rangeAxis / 1e3, mfProfileDB, "LineWidth", 1.2);
grid on;
xlabel("Range (km)");
ylabel("Normalized magnitude (dB)");
title("Matched filter output");
xlim([0, c / (2 * PRF) / 1e3]);
ylim([-60, 5]);

nexttile;
imagesc(velocityAxis, rangeAxis / 1e3, rdMagnitudeDB);
axis xy;
colorbar;
clim([-60, 0]);
xlabel("Velocity (m/s)");
ylabel("Range (km)");
title("Range-Doppler map");
hold on;
plot(estimatedVelocity, estimatedRange / 1e3, "wo", ...
    "MarkerSize", 8, "LineWidth", 1.5);

nexttile;
plot(scanAnglesDeg, beamResponseDB, "LineWidth", 1.3);
grid on;
hold on;
xline(targetAngleDeg, "--", "Truth", "LabelVerticalAlignment", "bottom");
plot(estimatedAngleDeg, beamResponseDB(peakAngleIndex), "ro", ...
    "MarkerSize", 7, "LineWidth", 1.4);
xlabel("Scan angle (deg)");
ylabel("Normalized response (dB)");
title("Angle spectrum at RD peak");
xlim([-90, 90]);
ylim([-45, 3]);

outputDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "outputs");
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end
outputPath = fullfile(outputDir, "demo_06_single_target_rda_cube.png");
exportgraphics(gcf, outputPath, "Resolution", 160);
fprintf("Saved figure: %s\n", outputPath);

