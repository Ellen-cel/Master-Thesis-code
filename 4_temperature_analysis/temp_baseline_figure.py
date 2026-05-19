import os
import pandas as pd
import numpy as np
import plotly.express as px
from datetime import datetime
import math
import matplotlib.pyplot as plt

# ===== SETTINGS =====
TEMP_FILE = r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\Experiments 24.04.26\interrogator_baseline_before_2nd_F50µm_P0_10Hz_20ms_5mW_2min_2026-04-24_19-31-04.csv"
OUTPUT_FOLDER = r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\Experiments 24.04.26"

X_TICK_INTERVAL = 20   # seconden
Y_TICK_INTERVAL = 0.01 # °C

def create_temp_plots(temp_file):
    # ===== CSV inlezen =====
    df = pd.read_csv(temp_file, sep=';', header=None, skiprows=1)

    if df.shape[1] < 2:
        print("Temp file heeft te weinig kolommen")
        return

    # ===== Tijd correct parsen =====
    time_raw = df.iloc[:, 0]
    try:
        time_dt = pd.to_datetime(time_raw, format="%H:%M:%S.%f")
    except:
        time_dt = pd.to_datetime(time_raw)

    # Tijd in seconden vanaf start
    time_seconds = (time_dt - time_dt.iloc[0]).dt.total_seconds()

    # ===== Temperatuur =====
    temperature = df.iloc[:, 1].astype(str).str.replace(',', '.').astype(float)

    # ===== Y-as instellingen (FIXED STEP 0.01) =====
    temp_min = temperature.min()
    temp_max = temperature.max()
    margin = 0.05 * (temp_max - temp_min)
    y_min = temp_min - margin
    y_max = temp_max + margin

    # Afronden naar 0.01 grid
    y_tick_start = math.floor(y_min / Y_TICK_INTERVAL) * Y_TICK_INTERVAL
    y_tick_end = math.ceil(y_max / Y_TICK_INTERVAL) * Y_TICK_INTERVAL
    y_ticks = np.arange(y_tick_start, y_tick_end + Y_TICK_INTERVAL, Y_TICK_INTERVAL)
    y_ticks = np.round(y_ticks, 4)

    # ===== Plotly (INTERACTIEF) =====
    fig = px.line(
        x=time_seconds,
        y=temperature,
        labels={'x': 'Time (s)', 'y': 'Temperature (°C)'},
        title="Temperature vs Time"
    )

    fig.update_traces(
        mode='lines',
        hovertemplate='Time: %{x:.2f} s<br>Temp: %{y:.4f} °C'
    )

    # Y-as (0.01 stappen)
    fig.update_yaxes(range=[y_tick_start, y_tick_end], tickvals=y_ticks)
    # X-as (20 seconden)
    fig.update_xaxes(dtick=X_TICK_INTERVAL)
    fig.update_layout(hovermode="x unified", width=1200, height=600)

    # ===== Opslaan HTML =====
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    html_path = os.path.join(OUTPUT_FOLDER, f"temperature_plot_{timestamp}.html")
    fig.write_html(html_path)
    print(f"Saved interactive plot: {html_path}")

    # ===== Matplotlib (STATIC) =====
    plt.figure(figsize=(14, 6))
    plt.plot(time_seconds, temperature, linewidth=1)
    plt.xlabel("Time (s)")
    plt.ylabel("Temperature (°C)")
    plt.title("Temperature vs Time")
    plt.ylim(y_tick_start, y_tick_end)
    plt.yticks(y_ticks)

    # X-as ticks (20 sec)
    plt.xticks(np.arange(time_seconds.min(), time_seconds.max() + X_TICK_INTERVAL, X_TICK_INTERVAL))
    plt.grid(True, alpha=0.3)

    jpg_path = os.path.join(OUTPUT_FOLDER, f"temperature_plot_{timestamp}.jpg")
    plt.tight_layout()
    plt.savefig(jpg_path, dpi=150)
    plt.close()
    print(f"Saved static plot: {jpg_path}")

# ===== RUN =====
if __name__ == "__main__":
    create_temp_plots(TEMP_FILE)
