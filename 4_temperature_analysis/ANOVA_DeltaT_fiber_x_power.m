%% ============================================================
%  new_anova_v8.m
%  ANOVA + Tukey pipeline
%  PulseSetting p-waarde + volledige Tukey-lijsten in tekstbestand
%  ============================================================

%% ============================
%  OUTPUTMAP AANMAKEN
%  ============================

outDir = 'ANOVA_Results';
if ~exist(outDir, 'dir')
    mkdir(outDir);
end


%% ============================
%  ROBUSTE CSV-INLAADMODULE
%  ============================

csvFile = 'master_temp_overview_windows_v7.csv';

opts = detectImportOptions(csvFile, ...
    'Delimiter', ',', ...
    'Encoding', 'UTF-8', ...
    'TextType', 'string');

opts.VariableNamesLine = 1;
opts.DataLine = 2;

data = readtable(csvFile, opts);

% Header fix indien nodig
if startsWith(data.Properties.VariableNames{1}, "Var")
    raw = readlines(csvFile);
    header = split(raw(1), ",");
    data.Properties.VariableNames = matlab.lang.makeValidName(header);
end

requiredCols = {'fiberID','power_mW','freq_Hz','pulse_ms','dutyCycle_pct','deltaT_window'};
missing = setdiff(requiredCols, data.Properties.VariableNames);

if ~isempty(missing)
    error('Kolommen ontbreken of verkeerd ingelezen: %s', strjoin(missing, ', '));
end


%% ============================
%  VARIABELEN OMZETTEN
%  ============================

data.Fiber = categorical(data.fiberID);
data.Power = categorical(data.power_mW);

data.PulseSetting = categorical( ...
    strcat( string(data.freq_Hz), "Hz_", ...
            string(data.pulse_ms), "ms_", ...
            string(data.dutyCycle_pct), "pct") );

data.TempRise = data.deltaT_window;


%% ============================
%  MODEL FITTEN
%  ============================

mdl = fitlm(data, 'TempRise ~ Fiber*Power + PulseSetting');

anova_table = anova(mdl);   % <-- volledige ANOVA mét PulseSetting p-waarde

anova_table.Term = anova_table.Properties.RowNames;
anova_table = movevars(anova_table, 'Term', 'Before', 1);

writetable(anova_table, fullfile(outDir, 'ANOVA_Global_FiberPowerPulse.csv'));


%% ============================================================
%  TUKEY POST-HOC: FIBER
%  ============================================================

[p_fiber, tbl_fiber, stats_fiber] = anova1(data.TempRise, data.Fiber, 'off');
results_fiber = multcompare(stats_fiber, 'CType', 'tukey-kramer');

fiber_names = stats_fiber.gnames;

T_fiber = table;
T_fiber.Fiber1 = fiber_names(results_fiber(:,1));
T_fiber.Fiber2 = fiber_names(results_fiber(:,2));
T_fiber.Diff = results_fiber(:,4);
T_fiber.pValue = results_fiber(:,6);

writetable(T_fiber, fullfile(outDir, 'Tukey_Fiber_withNames.csv'));


%% ============================================================
%  TUKEY POST-HOC: POWER
%  ============================================================

[p_power, tbl_power, stats_power] = anova1(data.TempRise, data.Power, 'off');
results_power = multcompare(stats_power, 'CType', 'tukey-kramer');

power_names = stats_power.gnames;

T_power = table;
T_power.Power1 = power_names(results_power(:,1));
T_power.Power2 = power_names(results_power(:,2));
T_power.Diff = results_power(:,4);
T_power.pValue = results_power(:,6);

writetable(T_power, fullfile(outDir, 'Tukey_Power_withNames.csv'));


%% ============================================================
%  TUKEY POST-HOC: FIBER × POWER
%  ============================================================

interaction_group = categorical(strcat(string(data.Fiber), "_", string(data.Power)));

[p_inter, tbl_inter, stats_inter] = anova1(data.TempRise, interaction_group, 'off');
results_inter = multcompare(stats_inter, 'CType', 'tukey-kramer');

inter_names = stats_inter.gnames;

T_inter = table;
T_inter.Combo1 = inter_names(results_inter(:,1));
T_inter.Combo2 = inter_names(results_inter(:,2));
T_inter.Diff = results_inter(:,4);
T_inter.pValue = results_inter(:,6);

writetable(T_inter, fullfile(outDir, 'Tukey_FiberPower_interaction_withNames.csv'));


%% ============================================================
%  TEKSTSAMENVATTING (volledige lijsten + markering)
%  ============================================================

summary_file = fopen(fullfile(outDir, 'ANOVA_Global_Summary.txt'),'w');

fprintf(summary_file, "=== Globale ANOVA: Fiber * Power + PulseSetting ===\n\n");

fprintf(summary_file, "Fiber-effect: p = %.3g\n", anova_table.pValue(strcmp(anova_table.Term,'Fiber')));
fprintf(summary_file, "Power-effect: p = %.3g\n", anova_table.pValue(strcmp(anova_table.Term,'Power')));
fprintf(summary_file, "Interactie Fiber×Power: p = %.3g\n", anova_table.pValue(strcmp(anova_table.Term,'Fiber:Power')));
fprintf(summary_file, "PulseSetting-effect: p = %.3g\n\n", anova_table.pValue(strcmp(anova_table.Term,'PulseSetting')));


%% --- Tukey Fiber ---
fprintf(summary_file, "=== Tukey post-hoc: Fiber (alle vergelijkingen) ===\n");
for i = 1:height(T_fiber)
    if T_fiber.pValue(i) < 0.05
        fprintf(summary_file, "%s vs %s: diff = %.3f, p = %.3g   <<< SIGNIFICANT\n", ...
            T_fiber.Fiber1{i}, T_fiber.Fiber2{i}, T_fiber.Diff(i), T_fiber.pValue(i));
    else
        fprintf(summary_file, "%s vs %s: diff = %.3f, p = %.3g\n", ...
            T_fiber.Fiber1{i}, T_fiber.Fiber2{i}, T_fiber.Diff(i), T_fiber.pValue(i));
    end
end
fprintf(summary_file, "\n");


%% --- Tukey Power ---
fprintf(summary_file, "=== Tukey post-hoc: Power (alle vergelijkingen) ===\n");
for i = 1:height(T_power)
    if T_power.pValue(i) < 0.05
        fprintf(summary_file, "%s mW vs %s mW: diff = %.3f, p = %.3g   <<< SIGNIFICANT\n", ...
            T_power.Power1{i}, T_power.Power2{i}, T_power.Diff(i), T_power.pValue(i));
    else
        fprintf(summary_file, "%s mW vs %s mW: diff = %.3f, p = %.3g\n", ...
            T_power.Power1{i}, T_power.Power2{i}, T_power.Diff(i), T_power.pValue(i));
    end
end
fprintf(summary_file, "\n");


%% --- Tukey Interactie ---
fprintf(summary_file, "=== Tukey post-hoc: Fiber × Power ===\n");
sig_inter = T_inter(T_inter.pValue < 0.05,:);
if isempty(sig_inter)
    fprintf(summary_file, "(geen significante vergelijkingen)\n");
else
    for i = 1:height(sig_inter)
        fprintf(summary_file, "%s vs %s: diff = %.3f, p = %.3g   <<< SIGNIFICANT\n", ...
            sig_inter.Combo1{i}, sig_inter.Combo2{i}, sig_inter.Diff(i), sig_inter.pValue(i));
    end
end

fclose(summary_file);

