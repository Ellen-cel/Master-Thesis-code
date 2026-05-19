%% ========================================================================
%  Graphs_temp_WINDOW_ONLY_v17_MOD_P60_P130.m
%  - Enkel ΔT_window + heating rate
%  - GEEN ΔT_max
%  - Interpreter = none
%  - P50→P60 en P105→P130 (alleen display)
%  - ΔT y-as vaste ticks (0.05°C) + extra marge
% ========================================================================

clear; clc;

%% 1. CSV handmatig inlezen via fgetl
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

%% 2. Automatische kolomdetectie
findCol = @(pattern) colNames{contains(lower(colNames), pattern)};

fiberCol = findCol('fiber');
freqCol  = findCol('freq');
pulseCol = findCol('pulse');
powerCol = findCol('power');
dutyCol  = findCol('duty');

dTwinCol = findCol('deltat_window');
flagCol  = findCol('flag');

%% 3. Numeriek maken
numConvert = @(col) str2double(T.(col));

T.(freqCol)  = numConvert(freqCol);
T.(pulseCol) = numConvert(pulseCol);
T.(powerCol) = numConvert(powerCol);
T.(dutyCol)  = numConvert(dutyCol);
T.(dTwinCol) = numConvert(dTwinCol);
T.(flagCol)  = numConvert(flagCol);

%% 4. Fiberlijst
fiberList = unique(T.(fiberCol));

%% === MAPPING: CSV → DISPLAY ===
renameMap = containers.Map( ...
    {'Lambda200','P50','P105'}, ...
    {'P200','P60','P130'} );

%% 5. Power kleuren
powerVals = unique(T.(powerCol));
powerColors = [
    0.2 0.4 0.9;   % 5 mW
    1.0 0.4 0.7;   % 10 mW
    1.0 0.9 0.1    % 14 mW
];

%% 6. Outputmap
rootOut = 'Results_TempAnalysis_feedback_final';
if ~exist(rootOut, 'dir')
    mkdir(rootOut);
end

%% 7. Loop over fibers — ΔT_window per fiber
for f = 1:numel(fiberList)

    fiberOriginal = fiberList{f};   % naam in CSV
    fiber = fiberOriginal;

    % === Apply mapping for display ===
    if isKey(renameMap, fiber)
        fiber = renameMap(fiber);
    end

    idx = strcmp(T.(fiberCol), fiberOriginal);
    Tf = T(idx, :);

    Tf = sortrows(Tf, {dutyCol, pulseCol}, {'descend','descend'});

    combos = string(Tf.(freqCol)) + "_" + string(Tf.(pulseCol)) + "_" + string(Tf.(dutyCol));
    [uCombos, ~, ic] = unique(combos, 'stable');

    Tf.comboID = ic;

    fiberOut = fullfile(rootOut, fiber);
    if ~exist(fiberOut,'dir')
        mkdir(fiberOut);
    end

    compactLabels = strings(numel(uCombos),1);
    for k = 1:numel(uCombos)
        idxC = find(Tf.comboID == k, 1, 'first');
        fval = Tf.(freqCol)(idxC);
        pval = Tf.(pulseCol)(idxC);
        dval = Tf.(dutyCol)(idxC);
        compactLabels(k) = sprintf('%gHz_%gms_%g%%', fval, pval, dval);
    end

    %% FIGUUR — ΔT_window (per fiber)
    figA = figure('Visible','off','Color','w');
    hold on;

    for pIdx = 1:numel(powerVals)
        pval = powerVals(pIdx);
        rows = Tf.(powerCol) == pval;
        if ~any(rows), continue; end

        xline = Tf.comboID(rows);
        yline = Tf.(dTwinCol)(rows);

        [xSorted, sortIdx] = sort(xline);
        plot(xSorted, yline(sortIdx), '-', ...
            'Color', powerColors(pIdx,:), ...
            'LineWidth', 1.5);
    end

    for i = 1:height(Tf)
        x = Tf.comboID(i);
        y = Tf.(dTwinCol)(i);

        p = Tf.(powerCol)(i);
        pIdx = find(powerVals == p);
        faceColor = powerColors(pIdx, :);

        if Tf.(flagCol)(i) == 1
            edgeColor = [0 0.7 0];
        else
            edgeColor = [0.8 0 0];
        end

        plot(x, y, 'o', ...
            'MarkerFaceColor', faceColor, ...
            'MarkerEdgeColor', edgeColor, ...
            'LineWidth', 1.5, ...
            'MarkerSize', 10);
    end

    xlabel('Parameter combinations (frequency_pulse duration_duty cycle)', 'Interpreter','none');
    ylabel('DeltaT (°C)', 'Interpreter','none');
    title([fiber ' — DeltaT'], 'Interpreter','none');

    xticks(1:numel(uCombos));
    xticklabels(compactLabels);
    set(gca,'TickLabelInterpreter','none');
    xtickangle(45);

    %% === Y-AS: vaste ticks van 0.05°C + extra marge ===
    allY = Tf.(dTwinCol);
    tick_step = 0.05;

    ymin = min(allY);
    ymax = max(allY);

    ymin_new = floor((ymin - tick_step) / tick_step) * tick_step;
    ymax_new = ceil((ymax + tick_step) / tick_step) * tick_step;

    ylim([ymin_new, ymax_new]);
    yticks(ymin_new : tick_step : ymax_new);

    xlim([0.5, numel(uCombos)+0.5]);
    set(gcf, 'Position', [100 100 1600 550]);

    legendHandlesA = [];
    legendTextA = {};
    for i = 1:numel(powerVals)
        legendHandlesA(end+1) = plot(nan,nan,'o','MarkerFaceColor',powerColors(i,:), ...
            'MarkerEdgeColor','k','MarkerSize',10);
        legendTextA{end+1} = sprintf('%d mW', powerVals(i));
    end
    legendHandlesA(end+1) = plot(nan,nan,'o','MarkerFaceColor','w', ...
        'MarkerEdgeColor',[0 0.7 0],'LineWidth',1.5,'MarkerSize',10);
    legendTextA{end+1} = 'DeltaT above baseline range';
    legendHandlesA(end+1) = plot(nan,nan,'o','MarkerFaceColor','w', ...
        'MarkerEdgeColor',[0.8 0 0],'LineWidth',1.5,'MarkerSize',10);
    legendTextA{end+1} = 'DeltaT within baseline range';

    legend(legendHandlesA, legendTextA, 'Interpreter','none', 'Location','best');

    grid on;
    hold off;

    saveas(figA, fullfile(fiberOut, 'DT_window.png'));
    close(figA);

end
%% ========================================================================
%  EXTRA MODULE — BARPLOTS (alle fibers, ΔT_window + heating rate)
%% ========================================================================

% Originele namen zoals ze in de CSV staan  (BELANGRIJK!)
fiberIDs_original = ["F50","P50","F105","P105","F200","Lambda200"];

% Namen die in de figuren moeten verschijnen (via mapping)
fiberIDs_display = fiberIDs_original;
for i = 1:numel(fiberIDs_display)
    if isKey(renameMap, fiberIDs_display(i))
        fiberIDs_display(i) = renameMap(fiberIDs_display(i));
    end
end

% Kleuren per fiber (volgorde = fiberIDs_original)
fiberColors = [
    0.2 0.4 0.9;       % F50 blauw
    1.0 0.6 0.2;       % P50 → P60 oranje
    0.6 0.2 0.8;       % F105 paars
    0.678 0.847 0.902; % P105 → P130 grijs
    1.0 0.9 0.1;       % F200 geel
    0.0 0.0 0.0        % Lambda200 → P200 zwart
];

powerLevels = [5, 10, 14];

%% MASTER X-AS bepalen
comboCounts = zeros(numel(fiberIDs_original),1);
for fi = 1:numel(fiberIDs_original)
    idxF = strcmp(T.(fiberCol), fiberIDs_original(fi));
    combos_f = string(T.(freqCol)(idxF)) + "_" + string(T.(pulseCol)(idxF)) + "_" + string(T.(dutyCol)(idxF));
    comboCounts(fi) = numel(unique(combos_f));
end

[~, maxIdx] = max(comboCounts);
masterFiber = fiberIDs_original(maxIdx);

idxMaster = strcmp(T.(fiberCol), masterFiber);
Tmaster   = T(idxMaster, :);
Tmaster   = sortrows(Tmaster, {dutyCol, pulseCol}, {'descend','descend'});

combosMaster = string(Tmaster.(freqCol)) + "_" + string(Tmaster.(pulseCol)) + "_" + string(Tmaster.(dutyCol));
[uCombosMaster, ~, icMaster] = unique(combosMaster, 'stable');

compactLabelsMaster = strings(numel(uCombosMaster),1);
for k = 1:numel(uCombosMaster)
    idxC = find(icMaster == k, 1, 'first');
    fval = Tmaster.(freqCol)(idxC);
    pval = Tmaster.(pulseCol)(idxC);
    dval = Tmaster.(dutyCol)(idxC);
    compactLabelsMaster(k) = sprintf('%gHz_%gms_%g%%', fval, pval, dval);
end

%% ========================================================================
%  BARPLOTS — ΔT_window
%% ========================================================================

for pIdx = 1:numel(powerLevels)

    pval = powerLevels(pIdx);

    figC = figure('Visible','off','Color','w','Position',[100 100 1800 600]);
    hold on;

    Y = nan(numel(uCombosMaster), numel(fiberIDs_original));
    edgeColors = cell(numel(uCombosMaster), numel(fiberIDs_original));

    for fi = 1:numel(fiberIDs_original)

        fiberNameCSV = fiberIDs_original(fi);   % naam in CSV
        idxF = strcmp(T.(fiberCol), fiberNameCSV) & T.(powerCol) == pval;

        combosF = string(T.(freqCol)(idxF)) + "_" + string(T.(pulseCol)(idxF)) + "_" + string(T.(dutyCol)(idxF));
        yvals = T.(dTwinCol)(idxF);
        flags = T.(flagCol)(idxF);

        for i = 1:numel(combosF)
            xIndex = find(uCombosMaster == combosF(i));
            Y(xIndex, fi) = yvals(i);

            if flags(i) == 1
                edgeColors{xIndex,fi} = [0 0.7 0];   % laser effect
            else
                edgeColors{xIndex,fi} = [0.8 0 0];   % no laser effect
            end
        end
    end

    % BARPLOT
    b = bar(Y, 'grouped', 'LineWidth', 1.5);

    % Kleuren instellen
    for fi = 1:numel(fiberIDs_original)
        b(fi).FaceColor = fiberColors(fi,:);
    end

    % Edge colors instellen
    for fi = 1:numel(fiberIDs_original)
        for ci = 1:numel(uCombosMaster)
            if ~isnan(Y(ci,fi))
                b(fi).EdgeColor = 'flat';
                b(fi).CData(ci,:) = edgeColors{ci,fi};
            end
        end
    end

    xlabel('Parameter combinations (frequency_pulse duration_duty cycle)', 'Interpreter','none');
    ylabel('DeltaT (°C)', 'Interpreter','none');
    title(sprintf('DeltaT — %d mW (all fibers)', pval), 'Interpreter','none');

    xticks(1:numel(uCombosMaster));
    xticklabels(compactLabelsMaster);
    set(gca,'TickLabelInterpreter','none');
    xtickangle(45);

    %% === Y-AS: vaste ticks van 0.05°C + extra marge ===
    allY = Y(~isnan(Y));
    tick_step = 0.05;

    ymin = min(allY);
    ymax = max(allY);

    ymin_new = floor((ymin - tick_step) / tick_step) * tick_step;
    ymax_new = ceil((ymax + tick_step) / tick_step) * tick_step;

    ylim([ymin_new, ymax_new]);
    yticks(ymin_new : tick_step : ymax_new);

    xlim([0.1, numel(uCombosMaster) + 0.9]);

    % Legende
    hEffect = plot(nan,nan,'s','MarkerFaceColor','w','MarkerEdgeColor',[0 0.7 0],'LineWidth',1.5,'MarkerSize',10);
    hNoEffect = plot(nan,nan,'s','MarkerFaceColor','w','MarkerEdgeColor',[0.8 0 0],'LineWidth',1.5,'MarkerSize',10);

    legend([b, hEffect, hNoEffect], [cellstr(fiberIDs_display), {'DeltaT above baseline range'}, {'DeltaT within baseline range'}], ...
        'Interpreter','none','Location','bestoutside');

    grid on;
    hold off;

    saveas(figC, fullfile(rootOut, sprintf('BAR_DT_window_%dmW_allFibers.png', pval)));
    close(figC);

end
%% ========================================================================
%  BARPLOTS — Heating rate (°C/s) in first 20 seconds
%% ========================================================================

for pIdx = 1:numel(powerLevels)

    pval = powerLevels(pIdx);

    figH = figure('Visible','off','Color','w','Position',[100 100 1800 600]);
    hold on;

    Y = nan(numel(uCombosMaster), numel(fiberIDs_original));
    edgeColors = cell(numel(uCombosMaster), numel(fiberIDs_original));

    for fi = 1:numel(fiberIDs_original)

        fiberNameCSV = fiberIDs_original(fi);   % naam zoals in CSV
        idxF = strcmp(T.(fiberCol), fiberNameCSV) & T.(powerCol) == pval;

        combosF = string(T.(freqCol)(idxF)) + "_" + string(T.(pulseCol)(idxF)) + "_" + string(T.(dutyCol)(idxF));
        yvals = T.heating_rate_20s(idxF);
        flags = T.(flagCol)(idxF);

        for i = 1:numel(combosF)
            xIndex = find(uCombosMaster == combosF(i));
            Y(xIndex, fi) = yvals(i);

            if flags(i) == 1
                edgeColors{xIndex,fi} = [0 0.7 0];   % laser effect
            else
                edgeColors{xIndex,fi} = [0.8 0 0];   % no laser effect
            end
        end
    end

    % BARPLOT
    b = bar(Y, 'grouped', 'LineWidth', 1.5);

    % Kleuren instellen
    for fi = 1:numel(fiberIDs_original)
        b(fi).FaceColor = fiberColors(fi,:);
    end

    % Edge colors instellen
    for fi = 1:numel(fiberIDs_original)
        for ci = 1:numel(uCombosMaster)
            if ~isnan(Y(ci,fi))
                b(fi).EdgeColor = 'flat';
                b(fi).CData(ci,:) = edgeColors{ci,fi};
            end
        end
    end

    xlabel('Parameter combinations (frequency_pulse duration_duty cycle)', 'Interpreter','none');
    ylabel('Heating rate (°C/s)', 'Interpreter','none');
    title(sprintf('Heating rate (first 20s) — %d mW (all fibers)', pval), 'Interpreter','none');

    xticks(1:numel(uCombosMaster));
    xticklabels(compactLabelsMaster);
    set(gca,'TickLabelInterpreter','none');
    xtickangle(45);

    %% === Y-AS: vaste ticks van 0.005°C/s + extra marge ===
    allY = Y(~isnan(Y));
    tick_step = 0.005;

    ymin = min(allY);
    ymax = max(allY);

    ymin_new = floor((ymin - tick_step) / tick_step) * tick_step;
    ymax_new = ceil((ymax + tick_step) / tick_step) * tick_step;

    ylim([ymin_new, ymax_new]);
    yticks(ymin_new : tick_step : ymax_new);

    ax = gca;
    ax.YRuler.Exponent = 0;
    ytickformat('%.3f');

    xlim([0.1, numel(uCombosMaster) + 0.9]);

    % Legende
    hEffect = plot(nan,nan,'s','MarkerFaceColor','w','MarkerEdgeColor',[0 0.7 0],'LineWidth',1.5,'MarkerSize',10);
    hNoEffect = plot(nan,nan,'s','MarkerFaceColor','w','MarkerEdgeColor',[0.8 0 0],'LineWidth',1.5,'MarkerSize',10);

    legend([b, hEffect, hNoEffect], [cellstr(fiberIDs_display), {'DeltaT above baseline range'}, {'DeltaT within baseline range'}], ...
        'Interpreter','none','Location','bestoutside');

    grid on;
    hold off;

    saveas(figH, fullfile(rootOut, sprintf('BAR_heatingRate_%dmW_allFibers.png', pval)));
    close(figH);

end
