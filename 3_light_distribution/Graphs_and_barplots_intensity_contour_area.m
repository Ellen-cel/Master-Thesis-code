%% =========================================================
%% FULL EDA SCRIPT — Per Fiber Spread + Hybrid Bar Comparison
%% =========================================================

clear; clc;

T = readtable('parameters_FINAL.csv');

%% =========================================================
%% FIBER RENAME MAP (ORIGINEEL → THESIS)
%% =========================================================
renameMap = containers.Map( ...
    {'50std','50flexF','105std','105flexA','200std','200lambda'}, ...
    {'F50','P60','F105','P130','F200','P200'} );

mapName = @(old) renameMap(old);

%% =========================================================
%% Outputmap
%% =========================================================
outBase = 'EDA2_adapted_feedback';
if ~exist(outBase,'dir')
    mkdir(outBase);
end

%% =========================================================
%% DEFINIEER VASTE Y-AS PER VIEW (AUTOMATISCH)
%% =========================================================

isoNames  = {'area_100pct','area_75pct','area_50pct','area_25pct','area_5pct'};
isoLabels = {'100%','75%','50%','25%','5%'};

%% Verzamel alle SIDE waarden (in mm²)
T_side_all = T(~isnan(T.depth50pct),:);
sideVals = [];
for i = 1:5
    sideVals = [sideVals; T_side_all.(isoNames{i})/1e6];
end

%% Verzamel alle BOTTOM waarden (in mm²)
T_bottom_all = T(~isnan(T.height50pct),:);
bottomVals = [];
for i = 1:5
    bottomVals = [bottomVals; T_bottom_all.(isoNames{i})/1e6];
end

%% Stapgrootte (2×10^4 µm² → 0.02 mm²)
stepFiber = 20000/1e6;   % per-fiber (SIDE/BOTTOM)
stepComp  = 20000/1e6;   % comparison

%% SIDE schaal (per-fiber)
sideMax   = ceil(max(sideVals)   / stepFiber) * stepFiber;
sideTicks = 0:stepFiber:sideMax;

%% BOTTOM schaal (per-fiber)
bottomMax   = ceil(max(bottomVals) / stepFiber) * stepFiber;
bottomTicks = 0:stepFiber:bottomMax;

%% =========================================================
%% PER-FIBER SPREAD MODULE
%% =========================================================

outFiber = fullfile(outBase, 'PerFiber');
if ~exist(outFiber,'dir')
    mkdir(outFiber);
end

%% ⭐ Nieuwe kleuren volgens jouw specificatie
% Volgorde: 100%, 75%, 50%, 25%, 5%
colors = [
    0.7 0.7 0.7;   % 100%  → lichtgrijs
    0   0   0;     % 75%   → zwart
    0   0.45 0.74; % 50%   → blauw
    0   0.6  0;    % 25%   → groen
    1   0.5  0     % 5%    → oranje
];

origFibers = unique(T.Var2,'stable');

%% LOOP OVER FIBERS — SPREAD FIGURES
for f = 1:numel(origFibers)

    F_orig = string(origFibers{f});
    F_new  = mapName(F_orig);

    T_f = T(strcmp(T.Var2,F_orig),:);

    fiberDir = fullfile(outFiber, F_new);
    if ~exist(fiberDir,'dir')
        mkdir(fiberDir);
    end

    %% ---------- SIDE ----------
    T_side = T_f(~isnan(T_f.depth50pct),:);

    if ~isempty(T_side)
        for L = [405 488]

            T_SL = T_side(T_side.thisLambda == L,:);
            if isempty(T_SL), continue; end

            fig = figure('Visible','off','Position',[100 100 1400 600]);
            hold on;

            %% ⭐ Nieuwe stijl: dikkere lijnen, grotere markers, nieuwe kleuren
            for i = 1:5
                lw = 1.8; if i==5, lw = 3.2; end
                x = T_SL.Var4;
                y = T_SL.(isoNames{i}) / 1e6;
                plot(x, y, '-o', ...
                    'Color',           colors(i,:), ...
                    'MarkerFaceColor', colors(i,:), ...
                    'MarkerSize',      6, ...
                    'LineWidth',       lw);
            end

            %% ⭐ Grotere fonts
            xlabel('Depth (mm)', 'FontSize', 20);
            ylabel('Area (mm^2)', 'FontSize', 20);
            title(sprintf('%s — %dnm — SIDE', F_new, L), 'FontSize', 22, 'Interpreter','none');

            %% ⭐ Legende buiten de figuur
            lg = legend(strcat(isoLabels, " iso-intensity contour"), ...
                        'Location','eastoutside');
            set(lg, 'FontSize', 18, 'Box','on');

            grid on;

            ylim([0 sideMax]);
            yticks(sideTicks);
            xlim([0 max(T_SL.Var4)]);

            set(gca, 'FontSize', 18);
            ax = gca;
            ax.XAxis.Exponent = 0;

            saveas(fig, fullfile(fiberDir, sprintf('%s_%dnm_SIDE.png',F_new,L)));
            close(fig);
        end
    end

    %% ---------- BOTTOM ----------
    T_bottom = T_f(~isnan(T_f.height50pct),:);

    if ~isempty(T_bottom)
        for L = [405 488]

            T_BL = T_bottom(T_bottom.thisLambda == L,:);
            if isempty(T_BL), continue; end

            fig = figure('Visible','off','Position',[100 100 1400 600]);
            hold on;

            %% ⭐ Nieuwe stijl
            for i = 1:5
                lw = 1.8; if i==5, lw = 3.2; end
                x = T_BL.Var5;
                y = T_BL.(isoNames{i}) / 1e6;
                plot(x, y, '-o', ...
                    'Color',           colors(i,:), ...
                    'MarkerFaceColor', colors(i,:), ...
                    'MarkerSize',      6, ...
                    'LineWidth',       lw);
            end

            %% ⭐ Grotere fonts
            xlabel('Height (mm)', 'FontSize', 20);
            ylabel('Area (mm^2)', 'FontSize', 20);
            title(sprintf('%s — %dnm — BOTTOM', F_new, L), 'FontSize', 22, 'Interpreter','none');

            %% ⭐ Legende buiten de figuur
            lg = legend(strcat(isoLabels, " iso-intensity contour"), ...
                        'Location','eastoutside');
            set(lg, 'FontSize', 18, 'Box','on');

            grid on;

            ylim([0 bottomMax]);
            yticks(bottomTicks);
            xlim([0 max(T_BL.Var5)]);

            set(gca, 'FontSize', 18);
            ax = gca;
            ax.XAxis.Exponent = 0;

            saveas(fig, fullfile(fiberDir, sprintf('%s_%dnm_BOTTOM.png',F_new,L)));
            close(fig);
        end
    end
end

disp('Per-fiber spread module voltooid.');

%% =========================================================
%% HYBRID BAR COMPARISON MODULE — NU OOK MET GROTE FONTS + LEGENDE BUITEN
%% =========================================================

outHybrid = fullfile(outBase, 'Hybrid_Comparison_Bars');
if ~exist(outHybrid,'dir')
    mkdir(outHybrid);
end

fiberOrder_orig = {'50std','50flexF','105std','105flexA','200std','200lambda'};
fiberOrder_new  = cellfun(mapName, fiberOrder_orig, 'UniformOutput', false);

nLevels_SIDE_488   = [1 2 2 3 5];
nLevels_SIDE_405   = [1 1 1 2 3];
nLevels_BOTTOM_488 = [1 1 1 2 2];
nLevels_BOTTOM_405 = [1 1 1 1 2];

T_side   = T(~isnan(T.depth50pct),:);
T_bottom = T(~isnan(T.height50pct),:);

barColors = lines(5);

views   = {'SIDE','BOTTOM'};
lambdas = [488 405];

for v = 1:numel(views)
    viewName = views{v};

    switch viewName
        case 'SIDE'
            T_view = T_side;
        case 'BOTTOM'
            T_view = T_bottom;
    end

    for L = lambdas

        for iso = 1:5

            isoField = isoNames{iso};
            isoLabel = isoLabels{iso};

            if strcmp(viewName,'SIDE') && L == 488
                nLevels = nLevels_SIDE_488(iso);
            elseif strcmp(viewName,'SIDE') && L == 405
                nLevels = nLevels_SIDE_405(iso);
            elseif strcmp(viewName,'BOTTOM') && L == 488
                nLevels = nLevels_BOTTOM_488(iso);
            elseif strcmp(viewName,'BOTTOM') && L == 405
                nLevels = nLevels_BOTTOM_405(iso);
            end

            nFib = numel(fiberOrder_orig);
            barData = nan(nFib, nLevels);

            for fi = 1:nFib
                F_orig = fiberOrder_orig{fi};

                T_FL = T_view(strcmp(T_view.Var2, F_orig) & T_view.thisLambda == L, :);
                if isempty(T_FL), continue; end

                switch viewName
                    case 'SIDE'
                        coords = T_FL.Var4;
                    case 'BOTTOM'
                        coords = T_FL.Var5;
                end

                uCoords = unique(coords);
                uCoords = sort(uCoords, 'ascend');

                nUse = min(nLevels, numel(uCoords));
                for j = 1:nUse
                    cVal = uCoords(j);
                    idx  = (coords == cVal);
                    vals = T_FL.(isoField)(idx) / 1e6;
                    barData(fi,j) = mean(vals, 'omitnan');
                end
            end

            if all(isnan(barData(:)))
                continue;
            end

            localMax = max(barData(:), [], 'omitnan');
            localMax = ceil(localMax / stepComp) * stepComp;
            if localMax == 0
                localMax = stepComp;
            end
            localTicks = 0:stepComp:localMax;

            fig = figure('Visible','off','Position',[100 100 1600 600]);
            hold on;

            hBar = bar(barData, 'grouped');

            for j = 1:nLevels
                set(hBar(j), 'FaceColor', barColors(j,:), 'EdgeColor','k');
            end

            set(gca, 'XTick', 1:nFib, 'XTickLabel', fiberOrder_new, 'XTickLabelRotation', 45);
            ylabel('Area (mm^2)', 'FontSize', 20);
            xlabel('Fiber / probe', 'FontSize', 20);
            set(gca, 'FontSize', 18);
            grid on;

            ylim([0 localMax]);
            yticks(localTicks);

            allCoords = [];

            for fi2 = 1:nFib
                F_orig2 = fiberOrder_orig{fi2};
                T_FL2 = T_view(strcmp(T_view.Var2, F_orig2) & T_view.thisLambda == L, :);

                if isempty(T_FL2), continue; end

                switch viewName
                    case 'SIDE'
                        coords2 = T_FL2.Var4;
                    case 'BOTTOM'
                        coords2 = T_FL2.Var5;
                end

                allCoords = [allCoords; coords2];
            end

            uCoords = unique(allCoords);
            uCoords = sort(uCoords, 'ascend');
            uCoords = uCoords(1:nLevels);

            legLabels = cell(1,nLevels);
            for j = 1:nLevels
                if strcmp(viewName,'SIDE')
                    legLabels{j} = sprintf('depth = %g mm', uCoords(j));
                else
                    legLabels{j} = sprintf('height = %g mm', uCoords(j));
                end
            end

            %% ⭐ Legende buiten de figuur
            lg = legend(legLabels, 'Location','eastoutside');
            set(lg, 'FontSize', 18, 'Box','on');

            title(sprintf('%s — %dnm — %s contour', viewName, L, isoLabel), ...
                  'FontSize', 22, 'Interpreter','none');

            outName = sprintf('%s_%dnm_%s_bar.png', viewName, L, isoLabel);
            saveas(fig, fullfile(outHybrid, outName));
            close(fig);
        end
    end
end

disp('Hybrid bar comparison module voltooid.');
