import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime
import math

# ===== SETTINGS =====
TEMP_FILE = r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\Experiments 16.04.26\Standard fiber 105µm 16.04.26\14mW\02_14mW_50%_5s_pulse\interrogator_F105_P0_0.1Hz_5000ms_14mW_2min_2026-04-16_15-17-58.csv"
OUTPUT_FOLDER = r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\Experiments 16.04.26\Standard fiber 105µm 16.04.26"

# Zoom interval (vergroot als loginterval groot is)
X_START = -0.1
X_END = 47.0

# Pulse instellingen
PULSE_FREQ = 0.1       # Hz
PULSE_WIDTH = 5    # s
PULSE_AMPLITUDE = 0.595 # V

# Y-as instellingen
Y_TICK_INTERVAL_TEMP = 0.02  # °C

def create_static_zoomed_plot(temp_file):
    # ===== CSV inlezen =====
    df = pd.read_csv(temp_file, sep=';', header=None, skiprows=1)
    if df.shape[1] < 2:
        print("Temp file heeft te weinig kolommen")
        return

    # ===== Tijd parsen =====
    time_raw = df.iloc[:,0]
    try:
        time_dt = pd.to_datetime(time_raw, format="%H:%M:%S.%f")
    except:
        time_dt = pd.to_datetime(time_raw)

    time_seconds = (time_dt - time_dt.iloc[0]).dt.total_seconds()

    # ===== Temperatuur =====
    temperature = df.iloc[:,1].astype(str).str.replace(',','.').astype(float)

    # ===== Filter zoom interval =====
    mask = (time_seconds >= X_START) & (time_seconds <= X_END)
    time_zoom = time_seconds[mask]
    temp_zoom = temperature[mask]

    if time_zoom.empty:
        print(f"No data found between {X_START} and {X_END} seconds.")
        return

    # ===== Blokgolf – fijne tijdvector =====
    t_fine = np.linspace(X_START, X_END, 1000)  # 1000 punten voor vloeiende blokgolf
    pulse = ((t_fine % (1/PULSE_FREQ)) < PULSE_WIDTH).astype(float) * PULSE_AMPLITUDE

    # ===== Y-as instellingen =====
    temp_min = temp_zoom.min()
    temp_max = temp_zoom.max()
    margin = 0.05 * (temp_max - temp_min)
    y_min = temp_min - margin
    y_max = temp_max + margin
    y_ticks_temp = np.round(np.arange(math.floor(y_min/Y_TICK_INTERVAL_TEMP)*Y_TICK_INTERVAL_TEMP,
                                      math.ceil(y_max/Y_TICK_INTERVAL_TEMP)*Y_TICK_INTERVAL_TEMP + Y_TICK_INTERVAL_TEMP,
                                      Y_TICK_INTERVAL_TEMP), 4)

    # ===== PLOT =====
    fig, ax1 = plt.subplots(figsize=(12,6))

    # Temperatuur
    ax1.plot(time_zoom, temp_zoom, color='red', label='Temperature (°C)', linewidth=1)
    ax1.set_xlabel("Time (s)")
    ax1.set_ylabel("Temperature (°C)", color='red')
    ax1.set_ylim(y_ticks_temp[0], y_ticks_temp[-1])
    ax1.set_yticks(y_ticks_temp)
    ax1.tick_params(axis='y', labelcolor='red')

    # Tweede Y-as voor blokgolf
    ax2 = ax1.twinx()
    ax2.plot(t_fine, pulse, color='blue', label='Pulse (V)', linewidth=1)
    ax2.set_ylabel("Pulse (V)", color='blue')
    ax2.set_ylim(0, PULSE_AMPLITUDE*1.2)
    ax2.tick_params(axis='y', labelcolor='blue')

    # Grid
    ax1.grid(True, alpha=0.3)

    # Titel
    ax1.set_title(f"Zoomed Temperature & Pulse from {X_START} to {X_END} s")

    # Legend
    lines_1, labels_1 = ax1.get_legend_handles_labels()
    lines_2, labels_2 = ax2.get_legend_handles_labels()
    ax1.legend(lines_1 + lines_2, labels_1 + labels_2, loc='upper right')

    # Opslaan als JPG
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    jpg_path = os.path.join(OUTPUT_FOLDER, f"zoomed_temp_pulse_{timestamp}.jpg")
    plt.tight_layout()
    plt.savefig(jpg_path, dpi=300)
    plt.close()

    print(f"Saved static plot: {jpg_path}")

if __name__ == "__main__":
    create_static_zoomed_plot(TEMP_FILE)
