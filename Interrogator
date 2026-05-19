# interrogator_module.py 

# -*- coding: utf-8 -*- 

"""
Refactored interrogator code to be started from another Python program.
""" 

import sys 
import argparse 
import logging 
import math 
import time 
from typing import Optional 

from sentea.interrogator import CaptureContent, Client, FiberSelection 
from datetime import datetime 


def peak_to_temp(peak: float) -> float: 
    """Convert peak wavelength to temperature in degrees.""" 
    return (peak - 1550.095)/0.01122 + 22 + 0.557122828 # 10–12 pm/°C, dus 0.01–0.012 nm/°C


def monitoring_loop(device_name: str, 
                    sample_rate: float, 
                    stop_event=None, 
                    status_callback=None,
                    logfile_path: Optional[str] = None): 

    logger = logging.getLogger(__name__) 

    logfile_handle = None
    if logfile_path:
        logfile_handle = open(logfile_path, "w", encoding="utf-8")
        # ✅ AANPASSING 1: header met 3 kolommen + juiste separator
        logfile_handle.write("Tijd;Temperatuur_C;Piek\n")

    if status_callback is not None: 
        status_callback(f"Connecting to interrogator {device_name}...") 

    with Client("192.168.1.10") as client: 

        client.capture.sample_rate = sample_rate 
        client.capture.content = CaptureContent.PEAKS 
        client.capture.fiber_selection = FiberSelection.FIBER1 
        client.capture.start() 

        prev_temp = -math.inf 
        log_interval = 0.1 
        last_log_time = 0.0 

        if status_callback is not None: 
            status_callback("Interrogator capture started (Fiber 1, PEAKS).") 

        while True: 

            if stop_event is not None and stop_event.is_set(): 
                if status_callback is not None: 
                    status_callback("Interrogator loop stopped by user.") 
                if logfile_handle:
                    logfile_handle.close()
                client.capture.stop()
                break 

            samples = client.capture.get_samples() 

            for _, sample in samples.iterrows(): 

                # ✅ AANPASSING 2: peak apart nemen
                peak = sample.peak1
                current_temp = peak_to_temp(peak)

                now = time.time() 

                if now - last_log_time >= log_interval: 

                    now_dt = datetime.fromtimestamp(now)
                    timestamp_str = now_dt.strftime("%H:%M:%S.%f")[:-3]

                    msg = f"{timestamp_str} - Fiber 1 temperature: {current_temp:.5f} °C."
                    logger.info(msg)

                    if logfile_handle:
                        # ✅ AANPASSING 3: Excel fix + extra kolom
                        temp_str = f"{current_temp:.5f}".replace(".", ",")
                        peak_str = f"{peak:.5f}".replace(".", ",")

                        logfile_handle.write(f"{timestamp_str};{temp_str};{peak_str}\n")
                        logfile_handle.flush()

                    if status_callback is not None: 
                        status_callback(msg) 

                    last_log_time = now 
                    prev_temp = current_temp 

            time.sleep(0.001) 


def setup_interrogator_logging(logfile_path: Optional[str] = None) -> None: 

    logging.basicConfig( 
        format=" %(message)s", 
        level=logging.INFO, 
    ) 

    if logfile_path: 
        file_handler = logging.FileHandler(logfile_path, mode="w", encoding="utf-8") 
        file_handler.setFormatter(logging.Formatter("[%(asctime)s] %(message)s")) 
        file_handler.setLevel(logging.INFO) 
        logging.getLogger().addHandler(file_handler) 


def main(): 

    if len(sys.argv) == 1: 
        sys.argv = [ 
            "Python_to_interrogator_script.py", 
            "--device-name", 
            "SENTEA421", 
            "--sample-rate", 
            "400", 
        ] 

    arg_parser = argparse.ArgumentParser( 
        prog="Fiber 1 monitoring script", 
        formatter_class=argparse.ArgumentDefaultsHelpFormatter, 
    ) 

    arg_parser.add_argument( 
        "--device-name", 
        help="Interrogator device name.", 
        type=str, 
        required=True, 
    ) 

    arg_parser.add_argument( 
        "--sample-rate", 
        help="Sample rate per fiber.", 
        type=float, 
        default=1000, 
    ) 

    args = arg_parser.parse_args() 

    logfile = r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\Experiments 10.04.26"
    setup_interrogator_logging(logfile) 

    logfile_path = r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\interrogator_log.csv"
    monitoring_loop(args.device_name, args.sample_rate, logfile_path=logfile_path)


if __name__ == "__main__": 
    main()
