import os
import pandas as pd
import numpy as np
import plotly.express as px
from datetime import datetime
import math
import matplotlib.pyplot as plt

# ===== SETTINGS =====
TEMP_FILE = r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\Experiments 24.04.26\interrogator_2nd_F50µm_P0_10Hz_20ms_5mW_2min_2026-04-24_19-33-20.csv"
PARAM_FILE = r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\Experiments 24.04.26\test_2nd_F50µm_P0_10Hz_20ms_5mW_2min_2026-04-24_19-33-20.txt"
OUTPUT_FOLDER = r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\Experiments 24.04.26"
# ===== MANUELE LASER TIMING =====
LASER_START = 0      # seconden
LASER_STOP = 120     # seconden

X_TICK_INTERVAL = 20
Y_TICK_INTERVAL = 0.04

# ===== EXTRACT FILE NAME =====
def extract_experiment_name(temp_file):
    filename = os.path.basename(temp_file)
    try:
        part = filename.split("interrogator_")[1]
        part = "_".join(part.split("_")[:-2])
    except:
        part = "experiment"
    return part

# ===== PARAM PARSER =====
def parse_param_file(param_file):
    params = {}
    timestamps = []

    with open(param_file, 'r') as f:
        for line in f:
            line = line.strip()

            if "Amplitude (V):" in line:
                params["Amplitude"] = line.split(":")[1].strip()

            if "Frequency (Hz):" in line:
                params["Frequency"] = line.split(":")[1].strip()

            if "Pulse duration (ms):" in line:
                params["Pulse duration"] = line.split(":")[1].strip()

            if "Duty cycle:" in line:
                params["Duty cycle"] = line.split(":")[1].strip()

            if "system running" in line or "stopped" in line:
                try:
                    ts = line.split(" - ")[0]
                    timestamps.append(pd.to_datetime(ts))
                except:
                    pass

    start_time = timestamps[0] if timestamps else None
    stop_time = timestamps[-1] if timestamps else None

    return params, start_time, stop_time

# ===== MAIN =====
def create_temp_plots(temp_file, param_file):

    # ===== CSV inlezen =====
    df = pd.read_csv(temp_file, sep=';', header=None, skiprows=1)

    if df.shape[1] < 2:
        print("Temp file heeft te weinig kolommen")
        return

    # ===== Tijd parsing =====
    time_raw = df.iloc[:, 0]

    try:
        time_dt = pd.to_datetime(time_raw, format="%H:%M:%S.%f")
    except:
        time_dt = pd.to_datetime(time_raw)

    time_seconds = (time_dt - time_dt.iloc[0]).dt.total_seconds()

    # ===== Temperatuur =====
    temperature = df.iloc[:, 1].astype(str).str.replace(',', '.').astype(float)

    # ===== PARAM DATA =====
    experiment_name = extract_experiment_name(temp_file)
    params, start_time, stop_time = parse_param_file(param_file)

    start_sec = max(0, LASER_START)
    stop_sec = min(time_seconds.max(), LASER_STOP)

    # ===== Y-as =====
    temp_min = temperature.min()
    temp_max = temperature.max()

    margin = 0.05 * (temp_max - temp_min)
    y_min = temp_min - margin
    y_max = temp_max + margin

    y_tick_start = math.floor(y_min / Y_TICK_INTERVAL) * Y_TICK_INTERVAL
    y_tick_end = math.ceil(y_max / Y_TICK_INTERVAL) * Y_TICK_INTERVAL

    y_ticks = np.arange(
        y_tick_start,
        y_tick_end + Y_TICK_INTERVAL,
        Y_TICK_INTERVAL
    )
    y_ticks = np.round(y_ticks, 4)

    # ===== PARAM TEXT =====
    param_text = (
        f"Amplitude: {params.get('Amplitude','')} V<br>"
        f"Frequency: {params.get('Frequency','')} Hz<br>"
        f"Pulse: {params.get('Pulse duration','')} ms<br>"
        f"Duty: {params.get('Duty cycle','')}"
    )

    # ===== PLOTLY =====
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

    fig.update_yaxes(
        range=[y_tick_start, y_tick_end],
        tickvals=y_ticks
    )
    fig.update_xaxes(dtick=X_TICK_INTERVAL)
    fig.update_layout(
        hovermode="x unified",
        width=1200,
        height=600
    )

    # ===== START/STOP labels Plotly horizontaal naast lijn =====
    if start_sec is not None:
        fig.add_vline(x=start_sec, line=dict(color='green', dash='dash'))
        fig.add_vline(x=stop_sec, line=dict(color='red', dash='dash'))

        y_offset = 0.02 * (y_max - y_min)  # kleine verticale offset
        fig.add_annotation(x=start_sec, y=max(temperature) + y_offset,
                           text="START",
                           showarrow=False,
                           xanchor='left',
                           font=dict(color='green', size=12, family="Arial"))
        fig.add_annotation(x=stop_sec, y=max(temperature) + y_offset,
                           text="STOP",
                           showarrow=False,
                           xanchor='left',
                           font=dict(color='red', size=12, family="Arial"))

    # box
    fig.add_annotation(
        x=1,
        y=1,
        xref="paper",
        yref="paper",
        text=param_text,
        showarrow=False,
        align="right",
        bordercolor="black",
        borderwidth=1
    )

    # ===== OPSLAAN =====
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

    html_path = os.path.join(
        OUTPUT_FOLDER,
        f"{experiment_name}_{timestamp}.html"
    )
    fig.write_html(html_path)
    print(f"Saved interactive plot: {html_path}")

    # ===== MATPLOTLIB =====
    plt.figure(figsize=(14, 6))
    plt.plot(time_seconds, temperature, linewidth=1)
    plt.xlabel("Time (s)")
    plt.ylabel("Temperature (°C)")
    plt.title("Temperature vs Time")

    plt.ylim(y_tick_start, y_tick_end)
    plt.yticks(y_ticks)
    plt.xticks(np.arange(
        time_seconds.min(),
        time_seconds.max() + X_TICK_INTERVAL,
        X_TICK_INTERVAL
    ))
    plt.grid(True, alpha=0.3)

    # START/STOP labels Matplotlib horizontaal naast lijn
    if start_sec is not None:
        plt.axvline(start_sec, color='green', linestyle='--')
        plt.axvline(stop_sec, color='red', linestyle='--')

        y_offset = 0.01 * (y_max - y_min)
        plt.text(start_sec + 0.5, max(temperature) + y_offset, "START",
                 ha='left', va='bottom', fontsize=10, color='green', fontweight='bold')
        plt.text(stop_sec + 0.5, max(temperature) + y_offset, "STOP",
                 ha='left', va='bottom', fontsize=10, color='red', fontweight='bold')

    # box
    plt.text(
        0.99, 0.99,
        f"Amplitude: {params.get('Amplitude','')} V\n"
        f"Frequency: {params.get('Frequency','')} Hz\n"
        f"Pulse: {params.get('Pulse duration','')} ms\n"
        f"Duty: {params.get('Duty cycle','')}",
        transform=plt.gca().transAxes,
        fontsize=9,
        verticalalignment='top',
        horizontalalignment='right',
        bbox=dict()
    )

    jpg_path = os.path.join(
        OUTPUT_FOLDER,
        f"{experiment_name}_{timestamp}.jpg"
    )

    plt.tight_layout()
    plt.savefig(jpg_path, dpi=150)
    plt.close()
    print(f"Saved static plot: {jpg_path}")

# ===== RUN =====
if __name__ == "__main__":
    create_temp_plots(TEMP_FILE, PARAM_FILE)
