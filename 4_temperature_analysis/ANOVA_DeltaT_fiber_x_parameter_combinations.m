%% ============================================================
%  new_anova_parameters_v1.m
%  ANOVA: Fiber * PulseSetting + Power (controlevariabele)
%  ============================================================

%% ============================
%  OUTPUTMAP AANMAKEN
%  ============================

outDir = 'ANOVA_ParameterCombinations';
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

mdl = fitlm(data, 'TempRise ~ Fiber * PulseSetting + Power');

anova_table = anova(mdl);

anova_table.Term = anova_table.Properties.RowNames;
anova_table = movevars(anova_table, 'Term', 'Before', 1);

writetable(anova_table, fullfile(outDir, 'ANOVA_Fiber_PulseSetting.csv'));


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
%  TUKEY POST-HOC: PULSESETTING
%  ============================================================

[p_ps, tbl_ps, stats_ps] = anova1(data.TempRise, data.PulseSetting, 'off');
results_ps = multcompare(stats_ps, 'CType', 'tukey-kramer');

ps_names = stats_ps.gnames;

T_ps = table;
T_ps.PS1 = ps_names(results_ps(:,1));
T_ps.PS2 = ps_names(results_ps(:,2));
T_ps.Diff = results_ps(:,4);
T_ps.pValue = results_ps(:,6);

writetable(T_ps, fullfile(outDir, 'Tukey_PulseSetting_withNames.csv'));


%% ============================================================
%  TUKEY POST-HOC: FIBER × PULSESETTING
%  ============================================================

interaction_group = categorical(strcat(string(data.Fiber), "_", string(data.PulseSetting)));

[p_inter, tbl_inter, stats_inter] = anova1(data.TempRise, interaction_group, 'off');
results_inter = multcompare(stats_inter, 'CType', 'tukey-kramer');

inter_names = stats_inter.gnames;

T_inter = table;
T_inter.Combo1 = inter_names(results_inter(:,1));
T_inter.Combo2 = inter_names(results_inter(:,2));
T_inter.Diff = results_inter(:,4);
T_inter.pValue = results_inter(:,6);

writetable(T_inter, fullfile(outDir, 'Tukey_FiberPulse_interaction_withNames.csv'));


%% ============================================================
%  TEKSTSAMENVATTING
%  ============================================================

summary_file = fopen(fullfile(outDir, 'ANOVA_Fiber_PulseSetting_Summary.txt'),'w');

fprintf(summary_file, "=== ANOVA: Fiber * PulseSetting + Power (controle) ===\n\n");

fprintf(summary_file, "Fiber-effect: p = %.3g\n", anova_table.pValue(strcmp(anova_table.Term,'Fiber')));
fprintf(summary_file, "PulseSetting-effect: p = %.3g\n", anova_table.pValue(strcmp(anova_table.Term,'PulseSetting')));
fprintf(summary_file, "Interactie Fiber×PulseSetting: p = %.3g\n", anova_table.pValue(strcmp(anova_table.Term,'Fiber:PulseSetting')));
fprintf(summary_file, "Power (controlevariabele): p = %.3g\n\n", anova_table.pValue(strcmp(anova_table.Term,'Power')));


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


%% --- Tukey PulseSetting ---
fprintf(summary_file, "=== Tukey post-hoc: PulseSetting (alle vergelijkingen) ===\n");
for i = 1:height(T_ps)
    if T_ps.pValue(i) < 0.05
        fprintf(summary_file, "%s vs %s: diff = %.3f, p = %.3g   <<< SIGNIFICANT\n", ...
            T_ps.PS1{i}, T_ps.PS2{i}, T_ps.Diff(i), T_ps.pValue(i));
    else
        fprintf(summary_file, "%s vs %s: diff = %.3f, p = %.3g\n", ...
            T_ps.PS1{i}, T_ps.PS2{i}, T_ps.Diff(i), T_ps.pValue(i));
    end
end
fprintf(summary_file, "\n");


%% --- Tukey Interactie ---
fprintf(summary_file, "=== Tukey post-hoc: Fiber × PulseSetting ===\n");
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

