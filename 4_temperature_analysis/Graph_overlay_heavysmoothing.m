%% ========================================================================
%  Overlay_6Fibers_v7_SG_HEAVY.m
%  Overlay van alle fibers/probes met optionele Savitzky–Golay smoothing
%  Inclusief heavy smoothing mode
%  → Lambda200 in legenda als P200
%  → Y-as = DeltaT(t) t.o.v. T_base_before_mean
% ========================================================================

clear; clc;

%% === 0. Instellingen =====================================================
applySmoothing   = true;   % smoothing aan/uit
useHeavySmoothing = true;  % HEAVY smoothing mode

% Normale smoothing (v6)
sgolayOrder_normal  = 3;
sgolayWindow_normal = 11;

% HEAVY smoothing (v7)
sgolayOrder_heavy   = 3;
sgolayWindow_heavy  = 41;  % ≈ 4 s smoothing

%% === 1. CSV inlezen ======================================================
fid = fopen('master_temp_overview_windows_v7.csv','r');
headerLine = fgetl(fid);
colNamesOriginal = strsplit(headerLine, ',');
colNames = matlab.lang.makeValidName(colNamesOriginal);
colNames = matlab.lang.makeUniqueStrings(colNames);

dataLines = {};
line = fgetl(fid);
while ischar(line)
    dataLines{end+1,1} = line;
    line = fgetl(fid);
end
fclose(fid);

numCols = numel(colNames);
data = strings(numel(dataLines), numCols);

for i = 1:numel(dataLines)
    parts = strsplit(dataLines{i}, ',');
    if numel(parts) < numCols
        parts(end+1:numCols) = {''};
    end
    if numel(parts) > numCols
        parts = parts(1:numCols);
    end
    data(i,:) = string(parts);
end

T = array2table(data, 'VariableNames', colNames);

%% === 2. Kolomdetectie ====================================================
findCol = @(pattern) colNames{contains(lower(colNames), lower(pattern))};

fiberCol      = findCol('fiber');
freqCol       = findCol('freq');
pulseCol      = findCol('pulse');
powerCol      = findCol('power');
dutyCol       = findCol('duty');
laserCol      = findCol('laserpath');
baseBeforeCol = findCol('base_before_mean');   % T_base_before_mean

%% === 3. Numeriek maken ===================================================
numConvert = @(col) str2double(T.(col));
T.(freqCol)        = numConvert(freqCol);
T.(pulseCol)       = numConvert(pulseCol);
T.(powerCol)       = numConvert(powerCol);
T.(dutyCol)        = numConvert(dutyCol);
T.(baseBeforeCol)  = numConvert(baseBeforeCol);

%% === 4. Selectie parametercombinatie =====================================
targetFreq  = 0.5;
targetPulse = 1000;
targetDuty  = 50;
targetPower = 14;

idx = T.(freqCol)  == targetFreq  & ...
      T.(pulseCol) == targetPulse & ...
      T.(dutyCol)  == targetDuty  & ...
      T.(powerCol) == targetPower;

Tsel = T(idx,:);

%% === 5. Fiber volgorde + kleuren =========================================
fiberIDs = ["F50","P50","F105","P105","F200","Lambda200"];

fiberColors = [
    0.2 0.4 0.9;   % F50
    1.0 0.6 0.2;   % P50
    0.6 0.2 0.8;   % F105
    0.55 0.55 0.55;% P105
    1.0 0.9 0.1;   % F200
    0.0 0.0 0.0    % Lambda200 → P200 (zwart)
];

% Mapping voor weergave in legenda
renameMap = containers.Map({'Lambda200'}, {'P200'});
fiberIDs_display = fiberIDs;
for i = 1:numel(fiberIDs_display)
    if isKey(renameMap, fiberIDs_display(i))
        fiberIDs_display(i) = renameMap(fiberIDs_display(i));
    end
end

%% === 6. Figuur ============================================================
figure('Color','w','Position',[100 100 1600 600]);
hold on;

%% === 7. Loop over fibers =================================================
for f = 1:numel(fiberIDs)

    fiber = fiberIDs(f);
    row   = strcmp(Tsel.(fiberCol), fiber);

    if ~any(row)
        warning('Fiber %s niet gevonden in selectie', fiber);
        continue;
    end

    laserFile = strtrim(Tsel.(laserCol)(row));

    if ~isfile(laserFile)
        warning('Laserbestand niet gevonden: %s', laserFile);
        continue;
    end

    [time, temp] = readLaserCSV(laserFile);

    % Baseline uit CSV (T_base_before_mean)
    baseline = Tsel.(baseBeforeCol)(row);

    % Savitzky–Golay smoothing (op absolute T)
    if applySmoothing
        if useHeavySmoothing
            temp = sgolayfilt(temp, sgolayOrder_heavy, sgolayWindow_heavy);
        else
            temp = sgolayfilt(temp, sgolayOrder_normal, sgolayWindow_normal);
        end
    end

    % DeltaT(t) t.o.v. baseline_before
    deltaT = temp - baseline;

    plot(time, deltaT, 'LineWidth', 1.8, 'Color', fiberColors(f,:));

end

%% === 8. START/STOP lijnen ===============================================
xStart = 0;
xStop  = 120;

yl = ylim;

xline(xStart, 'Color', [0 0.6 0], 'LineStyle', '--', 'LineWidth', 2);
text(xStart + 2, yl(2) - 0.02*(yl(2)-yl(1)), 'START', ...
    'Color', [0 0.6 0], 'FontWeight', 'bold', 'FontSize', 12);

xline(xStop, 'Color', [0.8 0 0], 'LineStyle', '--', 'LineWidth', 2);
text(xStop + 2, yl(2) - 0.02*(yl(2)-yl(1)), 'STOP', ...
    'Color', [0.8 0 0], 'FontWeight', 'bold', 'FontSize', 12);

%% === 9. X-as marge + ticks ===============================================
xlim([-15 350]);
xticks(0:20:350);

%% === 10. Y-as ticks per 0.05°C ===========================================
yl = ylim;
ymin = floor(yl(1)*20)/20;
ymax = ceil(yl(2)*20)/20;
yticks(ymin:0.05:ymax);

%% === 11. Layout ==========================================================
xlabel('Time (s)', 'Interpreter','none');
ylabel('DeltaT (°C)', 'Interpreter','none');

title(sprintf('overlay — all fibers/probes — %g mW — %gHz, %gms, %g%% (heavy SG smoothing, DeltaT)', ...
    targetPower, targetFreq, targetPulse, targetDuty), ...
    'Interpreter','none');

legend(cellstr(fiberIDs_display), 'Location','best');
grid on;
hold off;

%% === 12. Opslaan =========================================================
outNamePNG = sprintf('Overlay_allFibers_SGheavy_DeltaT_%gmW_%gHz_%gms_%g%%.png', ...
    targetPower, targetFreq, targetPulse, targetDuty);
outNamePDF = sprintf('Overlay_allFibers_SGheavy_DeltaT_%gmW_%gHz_%gms_%g%%.pdf', ...
    targetPower, targetFreq, targetPulse, targetDuty);

saveas(gcf, outNamePNG);
saveas(gcf, outNamePDF);

%% ========================================================================
%  FUNCTIE: readLaserCSV
% ========================================================================
function [time_s, temp_C] = readLaserCSV(filename)

    raw = readtable(filename, ...
        'Delimiter',';', ...
        'TextType','string', ...
        'ReadVariableNames', true, ...
        'Format','%s%s%s');

    t = raw.(1);
    t = replace(t, ',', '.');
    t0 = datetime(t(1), 'InputFormat','HH:mm:ss.SSS');
    time_s = seconds(datetime(t, 'InputFormat','HH:mm:ss.SSS') - t0);

    temp = raw.(2);
    temp = replace(temp, ',', '.');
    temp_C = str2double(temp);
end
