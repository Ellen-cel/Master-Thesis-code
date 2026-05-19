MATLAB scripts for temperature data analysis and figure generation.
ΔT = mean temperature during final 40 s of illumination minus mean 
baseline temperature. Heating rate = mean ΔT during first 20 s of 
illumination (°C/s). Statistical comparisons used two-way ANOVA with 
Tukey post-hoc correction (α = 0.05).

Files:
- ANOVA_DeltaT_fiber_x_power.m: three-way ANOVA for ΔT with 
  fiber/probe x power interaction
- ANOVA_DeltaT_fiber_x_parameter_combinations.m: three-way ANOVA 
  for ΔT with fiber/probe x parameter combination interaction
- ANOVA_heating_rate_fiber_x_power.m: three-way ANOVA for heating 
  rate with fiber/probe x power interaction
- ANOVA_heating_rate_fiber_x_parameter_combinations.m: three-way 
  ANOVA for heating rate with fiber/probe x parameter combination 
  interaction
- Graphs_and_barplots_for_DeltaT_and_heating_rate.m: bar plots of 
  ΔT and heating rate per fiber and probe type
- Graph_overlay_heavysmoothing.m: temperature response figure showing 
  pulse heating and cooling cycles
