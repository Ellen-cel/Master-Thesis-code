MATLAB and Python scripts for temperature data analysis and figure generation.
ΔT = mean temperature during final 40 s of illumination minus mean baseline 
temperature. Heating rate = mean ΔT during first 20 s of illumination (°C/s). 
Statistical comparisons used ANOVA with Tukey post-hoc correction (α = 0.05).

MATLAB scripts (statistical analysis):
- ANOVA_DeltaT_fiber_x_power.m
- ANOVA_DeltaT_fiber_x_parameter_combinations.m
- ANOVA_heating_rate_fiber_x_power.m
- ANOVA_heating_rate_fiber_x_parameter_combinations.m
- Graphs_and_barplots_for_DeltaT_and_heating_rate.m
- Graph_overlay_heavysmoothing.m

Python scripts (figure generation):
- temp_figures.py: temperature visualization during illumination
- temp_baseline_figure.py: baseline temperature visualization
- pulse_temp_figure.py: pulse-response figure showing heating and cooling cycles
