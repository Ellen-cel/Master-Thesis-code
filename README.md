# Master Thesis Code
## Comparison of Standard and Novel Implantable Optical Waveguides: Illumination Profiles and Photothermal Effects Validated in Liquid Brain Phantoms
Ellen Vanhulle & Gianni Brulez — Ghent University, 2025-2026

This repository contains all custom code used for data acquisition, 
processing, and statistical analysis in the master's thesis.

## Repository structure

### 1_laser_modulation
Python and Arduino code for laser modulation control.
- gui_dac_main.py: Python GUI for parameter input and serial communication
- Arduino_laser_control.ino: Arduino MEGA code for DAC control and pulse generation

### 2_FBG_interrogator
Python scripts for FBG sensor data acquisition for temperature measurements.
- interrogator_synced.py: data acquisition synchronized with laser modulation
- interrogator_baseline.py: standalone baseline acquisition without laser activation

### 3_light_distribution
MATLAB scripts for image processing and statistical analysis of light distribution profiles.
- Absolute_intensity_and_intensity_contour_profiles.m
- ANOVA_5%_and_50%_intensity_contour_areas.m
- Graphs_and_barplots_intensity_contour_area.m

### 4_temperature_analysis
MATLAB and Python scripts for temperature data analysis and figure generation.
- ANOVA_DeltaT_fiber_x_power.m
- ANOVA_DeltaT_fiber_x_parameter_combinations.m
- ANOVA_heating_rate_fiber_x_power.m
- ANOVA_heating_rate_fiber_x_parameter_combinations.m
- Graphs_and_barplots_for_DeltaT_and_heating_rate.m
- Graph_overlay_heavysmoothing.m
- temp_figures.py
- temp_baseline_figure.py
- pulse_temp_figure.py

## Requirements
- Python 3.x: tkinter, pyserial
- Arduino IDE
- MATLAB
