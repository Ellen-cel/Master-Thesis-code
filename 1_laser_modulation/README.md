Custom Python GUI for laser modulation control. Illumination parameters 
(pulse amplitude, frequency, pulse duration, total duration) are defined via 
the interface and transmitted to an Arduino MEGA, which controls a DAC 
module (DFR0971) whose output passes through a low-pass filter 
(Velleman SD35N) to the analog modulation input of the laser driver.
