# interrogator_module.py
# -*- coding: utf-8 -*-

import argparse
import logging
import time
import os
import threading
from datetime import datetime
from typing import Optional

from sentea.interrogator import CaptureContent, Client, FiberSelection


# -----------------------------
# Temperature conversion
# -----------------------------
def peak_to_temp(peak: float) -> float:
    return (peak - 1550.095)/0.01122 + 22 + 0.557122828 # 10–12 pm/°C, dus 0.01–0.012 nm/°C

# -----------------------------
# Monitoring loop
# -----------------------------
def monitoring_loop(device_name: str,
                    sample_rate: float,
                    duration: Optional[float] = None,
                    stop_event=None,
                    logfile_path: Optional[str] = None):

    logger = logging.getLogger(__name__)

    logfile_handle = None
    start_time = time.time()

    try:
        if logfile_path:
            logfile_handle = open(logfile_path, "w", encoding="utf-8")
            # 🔥 3 kolommen
            logfile_handle.write("Tijd;Temperatuur_C;Piek\n")

        print(f"Connecting to interrogator at {device_name}...")

        with Client(device_name) as client:

            client.capture.sample_rate = sample_rate
            client.capture.content = CaptureContent.PEAKS
            client.capture.fiber_selection = FiberSelection.FIBER1

            client.capture.start()
            print("Capture started.")

            log_interval = 0.1
            last_log_time = 0.0

            while True:

                now_total = time.time()

                if duration is not None:
                    if now_total - start_time >= duration:
                        print("Measurement finished (duration reached).")
                        break

                if stop_event and stop_event.is_set():
                    print("Stopping measurement...")
                    break

                samples = client.capture.get_samples()

                for _, sample in samples.iterrows():

                    peak = sample.peak1                      # ✅ echte peak
                    current_temp = peak_to_temp(peak)

                    now = time.time()

                    if now - last_log_time >= log_interval:

                        now_dt = datetime.fromtimestamp(now)
                        timestamp_str = now_dt.strftime("%H:%M:%S.%f")[:-3]

                        msg = f"{timestamp_str} - {current_temp:.6f} °C (peak: {peak:.6f})"
                        print(msg)
                        logger.info(msg)

                        if logfile_handle:
                            # 🔥 Excel fix: punt → komma
                            temp_str = f"{current_temp:.6f}".replace(".", ",")
                            peak_str = f"{peak:.6f}".replace(".", ",")

                            logfile_handle.write(
                                f"{timestamp_str};{temp_str};{peak_str}\n"
                            )
                            logfile_handle.flush()

                        last_log_time = now

                time.sleep(0.001)

            client.capture.stop()

    finally:
        if logfile_handle:
            logfile_handle.close()
        print("Logfile closed.")


# -----------------------------
# Logging setup
# -----------------------------
def setup_logging():
    logging.basicConfig(
        format="%(message)s",
        level=logging.INFO,
    )


# -----------------------------
# MAIN
# -----------------------------
def main():

    parser = argparse.ArgumentParser(
        description="Standalone Fiber Bragg Grating temperature monitoring"
    )

    parser.add_argument(
        "--device-name",
        type=str,
        default="192.168.1.10",
        help="Interrogator IP or hostname",
    )

    parser.add_argument(
        "--sample-rate",
        type=float,
        default=400,
        help="Sample rate (Hz)",
    )

    parser.add_argument(
        "--duration",
        type=float,
        default=120,
        help="Measurement duration in seconds (None = infinite)",
    )

    parser.add_argument(
        "--folder",
        type=str,
        default=r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\Experiments 24.04.26",
        help="Folder to store log files",
    )

    args = parser.parse_args()

    setup_logging()

    os.makedirs(args.folder, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    logfile_path = os.path.join(args.folder, f"interrogator_{timestamp}.csv")

    print(f"Logging to: {logfile_path}")

    stop_event = threading.Event()

    try:
        monitoring_loop(
            args.device_name,
            args.sample_rate,
            duration=args.duration,
            stop_event=stop_event,
            logfile_path=logfile_path,
        )

    except KeyboardInterrupt:
        print("\nCtrl+C detected. Stopping...")
        stop_event.set()


# -----------------------------
if __name__ == "__main__":
    main()
