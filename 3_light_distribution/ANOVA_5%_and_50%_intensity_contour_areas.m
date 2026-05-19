%% =========================================================
%% ANOVA LIGHT — Gecombineerd model per configuratie
%% Area_iso ~ Fiber + Depth/Height + Wavelength
%% =========================================================

clear; clc;

T = readtable('parameters_FINAL.csv');

outBase = 'ANOVA_Light_combined';
if ~exist(outBase,'dir'); mkdir(outBase); end

% Alleen 5% en 50%
isoNames  = {'area_50pct','area_5pct'};
isoLabels = {'50','5'};

% View-splitsing
T_side   = T(~isnan(T.depth50pct),:);
T_bottom = T(~isnan(T.height50pct),:);

views = {'SIDE','BOTTOM'};

%% Configuratie volgens afgesproken model
config = struct();

% SIDE – 5% iso
config.SIDE.iso5.depths = [0.5 1.0];
config.SIDE.iso5.heights = [];
config.SIDE.iso5.excludeFibers = {};

% SIDE – 50% iso
config.SIDE.iso50.depths = [0.5];
config.SIDE.iso50.heights = [];
config.SIDE.iso50.excludeFibers = {'50flexF'};

% BOTTOM – 5% iso
config.BOTTOM.iso5.depths = [];
config.BOTTOM.iso5.heights = [1.5];
config.BOTTOM.iso5.excludeFibers = {};

% BOTTOM – 50% iso
config.BOTTOM.iso50.depths = [];
config.BOTTOM.iso50.heights = [1.5];
config.BOTTOM.iso50.excludeFibers = {'50flexF'};

%% Loop over views
for v = 1:numel(views)

    viewName = views{v};

    switch viewName
        case 'SIDE'
            T_view   = T_side;
            coordVar = 'Var4';
            coordName = 'Depth';
        case 'BOTTOM'
            T_view   = T_bottom;
            coordVar = 'Var5';
            coordName = 'Height';
    end

    outView = fullfile(outBase, viewName);
    if ~exist(outView,'dir'); mkdir(outView); end

    %% Loop over iso (alleen 50 en 5)
    for iIso = 1:numel(isoNames)

        isoField = isoNames{iIso};
        isoLabel = isoLabels{iIso};

        % Kies config entry
        switch isoLabel
            case '5'
                cfg = config.(viewName).iso5;
            case '50'
                cfg = config.(viewName).iso50;
        end

        outIso = fullfile(outView, ['iso_' isoLabel]);
        if ~exist(outIso,'dir'); mkdir(outIso); end

        % Kies depths/heights
        if strcmp(viewName,'SIDE')
            levels = cfg.depths;
        else
            levels = cfg.heights;
        end

        if isempty(levels)
            fprintf('Geen levels gedefinieerd voor %s - iso %s\n', viewName, isoLabel);
            continue;
        end

        %% --- FILTERING PER DIEPTE (CRUCIAAL) ---
        rows = [];

        for lvl = levels
            idx = (T_view.(coordVar) == lvl);

            rows = [rows; T_view(idx, :)];
        end

        % Extract variabelen
        y      = rows.(isoField);
        fiber  = categorical(rows.Var2);
        coord  = rows.(coordVar);
        lambda = categorical(rows.thisLambda);

        % Verwijder NaN
        valid = ~isnan(y) & ~isnan(coord) & ~isnan(rows.thisLambda);
        y      = y(valid);
        fiber  = fiber(valid);
        coord  = coord(valid);
        lambda = lambda(valid);

        % Exclude fibers volgens config
        if ~isempty(cfg.excludeFibers)
            exMask = ismember(cellstr(fiber), cfg.excludeFibers);
            y(exMask)      = [];
            fiber(exMask)  = [];
            coord(exMask)  = [];
            lambda(exMask) = [];
        end

        % Exclude area = 0 (niet zichtbaar)
        zeroMask = (y == 0);
        y(zeroMask)      = [];
        fiber(zeroMask)  = [];
        coord(zeroMask)  = [];
        lambda(zeroMask) = [];

        %% --- Extra stap: hou alleen fibers met BEIDE wavelengths (405 én 488) ---
        fibersList = categories(fiber);
        keepMask = false(size(y));

        for f = 1:numel(fibersList)
            fName = fibersList{f};
            idxF  = (fiber == fName);

            wlHere = unique(lambda(idxF));

            % Alleen houden als zowel 405 als 488 aanwezig zijn
            if numel(wlHere) == 2
                keepMask = keepMask | idxF;
            end
        end

        y      = y(keepMask);
        fiber  = fiber(keepMask);
        coord  = coord(keepMask);
        lambda = lambda(keepMask);

        % Update lijst van overgebleven fibers
        fibersRemaining = categories(fiber);

        if numel(fibersRemaining) < 2
            fprintf('Te weinig fibers met beide wavelengths voor ANOVA (%s - iso %s)\n', viewName, isoLabel);
            continue;
        end

        %% --- ANOVA ---
        [p,tbl,stats] = anovan( ...
            y, {fiber, coord, lambda}, ...
            'model','linear', ... % Fiber + Coord + Wavelength
            'varnames',{'Fiber',coordName,'Wavelength'}, ...
            'display','off');

        tbl_ANOVA = cell2table(tbl(2:end,:),'VariableNames',tbl(1,:));
        writetable(tbl_ANOVA, fullfile(outIso, sprintf('ANOVA_%s_table.csv', lower(coordName))));

        %% --- Tukey Fiber ---
        c_fiber = multcompare(stats,'Dimension',1,'Display','off');

        fiberLevels = categories(fiber);
        fiberA = fiberLevels(c_fiber(:,1));
        fiberB = fiberLevels(c_fiber(:,2));

        T_fiber = table( ...
            fiberA, fiberB, ...
            c_fiber(:,3), c_fiber(:,4), c_fiber(:,5), c_fiber(:,6), ...
            'VariableNames', {'Group1','Group2','LowerCI','Estimate','UpperCI','pValue'} );

        writetable(T_fiber, fullfile(outIso,'Tukey_Fiber.csv'));

        %% --- Tukey Wavelength ---
        c_lambda = multcompare(stats,'Dimension',3,'Display','off');

        lambdaLevels = categories(lambda);
        lambdaA = lambdaLevels(c_lambda(:,1));
        lambdaB = lambdaLevels(c_lambda(:,2));

        T_lambda = table( ...
            lambdaA, lambdaB, ...
            c_lambda(:,3), c_lambda(:,4), c_lambda(:,5), c_lambda(:,6), ...
            'VariableNames', {'Group1','Group2','LowerCI','Estimate','UpperCI','pValue'} );

        writetable(T_lambda, fullfile(outIso,'Tukey_Wavelength.csv'));

        %% --- Summary ---
        summaryFile = fullfile(outIso,'Summary.txt');
        fid = fopen(summaryFile,'w');

        fprintf(fid,'ANOVA LIGHT — %s view — iso %s%%\n',viewName,isoLabel);
        fprintf(fid,'Model: %s ~ Fiber + %s + Wavelength\n\n', isoField, coordName);

        fprintf(fid,'Gekozen %s-levels: ', coordName);
        fprintf(fid,'%.3g ', levels);
        fprintf(fid,'\nOvergebleven fibers (met beide wavelengths): ');
        fprintf(fid,'%s ', fibersRemaining{:});
        fprintf(fid,'\n\n');

        fprintf(fid,'--- ANOVA-table ---\n');

        rawNames = tbl_ANOVA.Source;

        for r = 1:height(tbl_ANOVA)

            rn = rawNames{r};
            if iscell(rn)
                rn = rn{1};
            end
            rowName = string(rn);

            rawP = tbl_ANOVA.("Prob>F")(r);
            if iscell(rawP)
                pVal = rawP{1};
            else
                pVal = rawP;
            end

            if isnan(pVal)
                fprintf(fid,'%s: p = \n', rowName);
            else
                fprintf(fid,'%s: p = %.4g\n', rowName, pVal);
            end
        end

        %% --- Tukey Fiber in summary ---
        fprintf(fid,'\n--- Tukey Fiber (alle vergelijkingen) ---\n');

        for k = 1:height(T_fiber)

            g1 = T_fiber.Group1{k};
            g2 = T_fiber.Group2{k};
            diffVal = T_fiber.Estimate(k);
            pVal = T_fiber.pValue(k);

            if pVal < 0.05
                fprintf(fid,'%s vs %s: diff = %.1f, p = %.4g   <<< SIGNIFICANT\n', ...
                    g1, g2, diffVal, pVal);
            else
                fprintf(fid,'%s vs %s: diff = %.1f, p = %.4g\n', ...
                    g1, g2, diffVal, pVal);
            end
        end

        %% --- Tukey Wavelength in summary ---
        fprintf(fid,'\n--- Tukey Wavelength (alle vergelijkingen) ---\n');

        for k = 1:height(T_lambda)

            g1 = T_lambda.Group1{k};
            g2 = T_lambda.Group2{k};
            diffVal = T_lambda.Estimate(k);
            pVal = T_lambda.pValue(k);

            if pVal < 0.05
                fprintf(fid,'%s vs %s: diff = %.1f, p = %.4g   <<< SIGNIFICANT\n', ...
                    g1, g2, diffVal, pVal);
            else
                fprintf(fid,'%s vs %s: diff = %.1f, p = %.4g\n', ...
                    g1, g2, diffVal, pVal);
            end
        end

        fprintf(fid,'\nGeen Tukey voor %s of interacties in dit model.\n',coordName);

        fclose(fid);

        fprintf('Klaar: %s - iso %s%%\n',viewName,isoLabel);
    end
end

disp('ANOVA gecombineerd model volledig afgerond.');
