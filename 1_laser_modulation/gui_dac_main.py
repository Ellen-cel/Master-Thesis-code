# gui_dac_main.py (MAIN) 

 

import tkinter as tk 

from tkinter import messagebox 

 

import serial 

import threading 

import time 

import queue 

import os 

from datetime import datetime

 

# NEW: import the interrogator module (TEMP) 

import interrogator_module  

 

BAUDRATE = 115200 

READTIMEOUT = 0.1 

WRITETIMEOUT = 0.5 

SENDTIMEOUT = 2.0 

QUEUEMAXSIZE = 8 

 

serialhandle = None 

readerthread = None 

readerstop = None 

readerlines = [] 

 

senderthread = None 

senderstop = None 

sendqueue = queue.Queue(maxsize=QUEUEMAXSIZE) 

 

# Logger globals 

logthread = None 

logstop_event = None 

logfile_handle = None 

logfile_path = None 

 

LOG_INTERVAL = 0.5  # seconds 

DOWNLOADS_FOLDER = r"G:\Mijn Drive\UGent\Master 2\Jaarvak\Thesis\Code\Code temp setup 16.02.26\Files\Experiments 24.04.26" # target folder for logs 

 

# NEW: interrogator control globals 

interrogator_thread = None 

interrogator_stop_event = None 

 

 

def open_serial_port(port): 

    global serialhandle, readerthread, readerstop, senderthread, senderstop, sendqueue 

    try: 

        ser = serial.Serial(port, BAUDRATE, timeout=READTIMEOUT, write_timeout=WRITETIMEOUT) 

    except Exception as e: 

        return False, f"Open error: {e}" 

 

    try: 

        ser.dtr = False 

        ser.rts = False 

    except Exception: 

        pass 

 

    time.sleep(0.15) 

 

    try: 

        ser.reset_input_buffer() 

        ser.reset_output_buffer() 

    except Exception: 

        pass 

 

    time.sleep(0.6) 

 

    serialhandle = ser 

 

    readerstop = threading.Event() 

    readerthread = threading.Thread( 

        target=serial_reader, 

        args=(serialhandle, readerlines, readerstop), 

        daemon=True, 

    ) 

    readerthread.start() 

 

    sendqueue = queue.Queue(maxsize=QUEUEMAXSIZE) 

    senderstop = threading.Event() 

    senderthread = threading.Thread( 

        target=serial_sender, 

        args=(serialhandle, sendqueue, senderstop), 

        daemon=True, 

    ) 

    senderthread.start() 

 

    return True, "Connected" 

 

 

def close_serial_port(): 

    global serialhandle, readerstop, senderstop 

    try: 

        if senderstop: 

            senderstop.set() 

    except Exception: 

        pass 

 

    try: 

        if readerstop: 

            readerstop.set() 

    except Exception: 

        pass 

 

    time.sleep(0.05) 

 

    if serialhandle: 

        try: 

            serialhandle.close() 

        except Exception: 

            pass 

    serialhandle = None 

 

 

def serial_reader(ser, outlines, stopevent): 

    while not stopevent.is_set(): 

        try: 

            line = ser.readline().decode(errors="ignore").rstrip() 

            if line: 

                outlines.append(line) 

            else: 

                time.sleep(0.01) 

        except Exception as e: 

            outlines.append(f"Serial read error: {e}") 

            time.sleep(0.2) 

 

 

def serial_sender(ser, q, stopevent): 

    while not stopevent.is_set(): 

        try: 

            item = q.get(timeout=0.1) 

        except queue.Empty: 

            continue 

 

        if item is None: 

            q.task_done() 

            continue 

 

        cmd, itemid, resultcontainer = item 

 

        if ser is None or not ser.is_open: 

            resultcontainer["status"] = "serialclosed" 

            q.task_done() 

            continue 

 

        if not cmd.endswith("\n"): 

            cmdtosend = cmd + "\n" 

        else: 

            cmdtosend = cmd 

 

        t0 = time.time() 

        wrote = False 

        lastexc = None 

 

        while time.time() - t0 < SENDTIMEOUT and not stopevent.is_set(): 

            try: 

                ser.write(cmdtosend.encode()) 

                ser.flush() 

                wrote = True 

                break 

            except serial.SerialTimeoutException as te: 

                lastexc = te 

                break 

            except Exception as e: 

                lastexc = e 

                time.sleep(0.05) 

 

        if wrote: 

            resultcontainer["status"] = "sent" 

        else: 

            if isinstance(lastexc, serial.SerialTimeoutException): 

                resultcontainer["status"] = "writetimeout" 

            else: 

                resultcontainer["status"] = "failed" 

            resultcontainer["error"] = str(lastexc) if lastexc is not None else "unknown" 

 

        q.task_done() 

 

 

def enqueue_command(cmd, wait_for_send=False, timeout=3.0): 

    if serialhandle is None or not serialhandle.is_open: 

        return {"status": "serialclosed"} 

 

    try: 

        resultcontainer = {} 

        itemid = time.time() 

        sendqueue.put((cmd, itemid, resultcontainer), block=False) 

    except queue.Full: 

        return {"status": "queuefull"} 

    except Exception as e: 

        return {"status": "enqueuefailed", "error": str(e)} 

 

    if not wait_for_send: 

        return {"status": "queued"} 

 

    t0 = time.time() 

    while time.time() - t0 < timeout: 

        if "status" in resultcontainer: 

            return resultcontainer 

        time.sleep(0.02) 

 

    return {"status": "timeoutwait"} 

 

 

def _ensure_downloads_folder(): 

    try: 

        os.makedirs(DOWNLOADS_FOLDER, exist_ok=True) 

    except Exception: 

        pass 

 

 

def _safe_script_name(): 

    try: 

        return os.path.basename(__file__) 

    except Exception: 

        return "unknown_script" 

 

 

def _start_logger_file(amp, freq, offset, duty, timespan_ms): 

    """ 

    Create a new logfile and write header. Returns file path and open file handle. 

    """ 

    _ensure_downloads_folder() 

 

    start_dt = datetime.now() 

    timestamp_str = start_dt.strftime("%Y-%m-%d_%H-%M-%S") 

    fname = f"test_{timestamp_str}.txt" 

    path = os.path.join(DOWNLOADS_FOLDER, fname) 

 

    try: 

        f = open(path, "w", encoding="utf-8") 

    except Exception: 

        return None, None 

 

    # Header 

    header_lines = [] 

    header_lines.append(f"Parameter file: {_safe_script_name()}") 

    header_lines.append(f"Log start date: {start_dt.strftime('%Y-%m-%d %H:%M:%S')}") 

    header_lines.append(f"Amplitude (V): {amp}") 

    header_lines.append(f"Frequency (Hz): {freq}") 

    header_lines.append(f"Offset (V): {offset}") 

    pulse_ms = (duty / freq) * 1000 if freq > 0 else 0

    header_lines.append(f"Pulse duration (ms): {pulse_ms:.5f}")

    header_lines.append(f"Duty cycle: {duty:.5f}") 

    header_lines.append(f"Time span (ms): {timespan_ms}") 

    header_lines.append("-" * 60) 

 

    f.write("\n".join(header_lines) + "\n") 

    f.flush() 

 

    return path, f 

 

 

def _logger_thread_func(fhandle, stop_event, start_time, timespan_ms): 

    """ 

    Writes timestamp + status 'system running' every 500ms until stop_event or timespan elapsed. 

    When exiting, write a final stopped line and close file handle. 

    """ 

    try: 

        elapsed_ms = 0 

 

        # initial entry 

        fhandle.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]} - system running\n") 

        fhandle.flush() 

 

        while not stop_event.is_set(): 

            time.sleep(LOG_INTERVAL) 

            elapsed_ms = (time.time() - start_time) * 1000.0 

 

            if timespan_ms is not None and elapsed_ms >= timespan_ms: 

                # finish due to timespan 

                fhandle.write( 

                    f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]} - stopped (timespan finished)\n" 

                ) 

                fhandle.flush() 

                break 

 

            # regular running log 

            fhandle.write( 

                f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]} - system running\n" 

            ) 

            fhandle.flush() 

        else: 

            # stop_event set -> stopping by user 

            fhandle.write( 

                f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]} - stopped (stop requested)\n" 

            ) 

            fhandle.flush() 

 

    except Exception as e: 

        try: 

            fhandle.write( 

                f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]} - logger error: {e}\n" 

            ) 

            fhandle.flush() 

        except Exception: 

            pass 

    finally: 

        try: 

            fhandle.close() 

        except Exception: 

            pass 

 

 

def run_gui(): 

    global logthread, logstop_event, logfile_handle, logfile_path 

    global interrogator_thread, interrogator_stop_event 

 

    root = tk.Tk() 

    root.title("DAC Controller - Manual Port") 

    root.geometry("900x650")  # slightly taller to fit new label 

 

    font_large = ("TkDefaultFont", 11) 

 

    portvar = tk.StringVar(value="COM3") 

    ampvar = tk.DoubleVar(value=0.0) 

    freqvar = tk.DoubleVar(value=10) 

    offsetvar = tk.DoubleVar(value=0.0) 

    pulsevar = tk.DoubleVar(value=1.0) # pulse duration in ms

    durvar = tk.IntVar(value=120000)  # total duration in ms 

 

    logtext = tk.StringVar(value="") 

 

    # NEW: interrogator status text variable 

    interrogator_status = tk.StringVar(value="Interrogator: idle") 

 

    def append_log(text): 

        cur = logtext.get() 

        if len(cur) > 30000: 

            cur = cur[-20000:] 

        cur += text + "\n" 

        logtext.set(cur) 

        loglabel.config(text=logtext.get()) 

 

    # NEW: status callback passed into interrogator loop 

    def interrogator_status_callback(msg: str): 

        # Called from the interrogator thread -> use thread-safe update via 'after' 

        def _update(): 

            interrogator_status.set(f"Interrogator: {msg}") 

            append_log(f"[Interrogator] {msg}") 

 

        root.after(0, _update) 

 

    def connect(): 

        port = portvar.get() 

        if not port: 

            messagebox.showerror("Error", "Enter a port first.") 

            return 

 

        ok, msg = open_serial_port(port) 

        if ok: 

            statuslabel.config(text=f"Connected to {port}", fg="green") 

            append_log(f"Connected to {port}") 

            connectbutton.config(state="disabled") 

            disconnectbutton.config(state="normal") 

            enqueue_command("R") 

        else: 

            statuslabel.config(text=f"Connect failed: {msg}", fg="red") 

            append_log(f"Connect failed: {msg}") 

 

    def disconnect(): 

        close_serial_port() 

        statuslabel.config(text="Disconnected", fg="red") 

        append_log("Disconnected") 

        connectbutton.config(state="normal") 

        disconnectbutton.config(state="disabled") 

 

    def poll_reader(): 

        while readerlines: 

            line = readerlines.pop(0) 

            append_log(line) 

        root.after(100, poll_reader) 

 

    def clear_log(): 

        logtext.set("") 

        loglabel.config(text="") 

 

    def stop_output(): 

        global logthread, logstop_event, logfile_handle, logfile_path 

        global interrogator_thread, interrogator_stop_event 

 

        # Stop interrogator if running 

        try: 

            if interrogator_stop_event: 

                interrogator_stop_event.set() 

            if interrogator_thread and interrogator_thread.is_alive(): 

                interrogator_thread.join(timeout=1.0) 

        except Exception: 

            pass 

        interrogator_status.set("Interrogator: stopped") 

 

        # Signal logger to stop if running 

        try: 

            if logstop_event: 

                logstop_event.set() 

        except Exception: 

            pass 

 

        # Optionally wait briefly for logger to wrap up 

        try: 

            if logthread and logthread.is_alive(): 

                logthread.join(timeout=0.5) 

        except Exception: 

            pass 

 

        # send stop command to device (existing behavior) 

        if serialhandle is None or not serialhandle.is_open: 

            # still write stop entry to logfile if present 

            if logfile_handle: 

                try: 

                    logfile_handle.write( 

                        f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]} - stopped (stop requested)\n" 

                    ) 

                    logfile_handle.flush() 

                    logfile_handle.close() 

                except Exception: 

                    pass 

            logfile_handle = None 

            logfile_path = None 

            messagebox.showerror("Error", "Not connected.") 

            return 

 

        cmd = "A0.0 F1 O0.0 DC0.5" 

        append_log(cmd) 

        res = enqueue_command(cmd, wait_for_send=True, timeout=2.0) 

        append_log(f"Stop command status: {res['status']}") 

 

    def send_pulse(): 

        """ 

        Start DAC pulse (existing behaviour) AND start interrogator loop 

        at the same moment to share a time reference. 

        """ 

        global logthread, logstop_event, logfile_handle, logfile_path 

        global interrogator_thread, interrogator_stop_event 

 

        # existing behavior: send command to device 

        if serialhandle is None or not serialhandle.is_open: 

            messagebox.showerror("Error", "Not connected.") 

            return 

 

        amp = ampvar.get() 

        freq = freqvar.get() 

        offset = offsetvar.get() 

        pulse_ms = pulsevar.get() 

        # convert pulse duration (ms) to duty cycle
        if freq <= 0:
            messagebox.showerror(
                "Error",
                "Frequency must be greater than 0"
            )
            return
        
        duty = (pulse_ms / 1000.0)*freq

        if duty > 1:
            messagebox.showerror(
                "Error",
                "Pulse duration too large for this frequency (duty cycle > 1)"
            )
            return

        dur = max(100, min(300000, durvar.get()))  # clamp 100--300000 ms 

        durvar.set(dur) 

 

        cmd = f"A{amp:.4f} F{freq:.3f} O{offset:.2f} DC{duty:.6f} T{dur}" 

        append_log(cmd) 

        res = enqueue_command(cmd, wait_for_send=True, timeout=2.0) 

        append_log(f"Send status: {res['status']}") 

 

        # --- NEW: start file logging (existing from your code) --- 

        try: 

            if logstop_event: 

                logstop_event.set() 

            if logthread and logthread.is_alive(): 

                logthread.join(timeout=0.5) 

        except Exception: 

            pass 

 

        logfile_path, logfile_handle = _start_logger_file( 

            amp=amp, freq=freq, offset=offset, duty=duty, timespan_ms=dur 

        ) 

        if logfile_handle is None: 

            append_log("Failed to create logfile.") 

            logfile_path = None 

            logfile_handle = None 

            return 

 

        logstop_event = threading.Event() 

        start_time = time.time() 

        logthread = threading.Thread( 

            target=_logger_thread_func, 

            args=(logfile_handle, logstop_event, start_time, dur), 

            daemon=True, 

        ) 

        logthread.start() 

        append_log(f"Logging to: {logfile_path}") 

        # --- END logging section --- 

 

        # --- NEW: start interrogator in background thread --- 

        # Stop existing interrogator if already running 

        try: 

            if interrogator_stop_event: 

                interrogator_stop_event.set() 

            if interrogator_thread and interrogator_thread.is_alive(): 

                interrogator_thread.join(timeout=0.5) 

        except Exception: 

            pass 

 

        # --- Nieuw: genereer logfile voor interrogator (apart van laser) ---
        folder = DOWNLOADS_FOLDER  # zelfde map als laser
        os.makedirs(folder, exist_ok=True)

        timestamp_str_file = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        interrogator_logfile = os.path.join(folder, f"interrogator_{timestamp_str_file}.csv")
        append_log(f"Interrogator logging to: {interrogator_logfile}")

        # --- start de thread en geef logfile pad mee ---
        interrogator_stop_event = threading.Event()
        interrogator_status.set("Interrogator: starting...")
        append_log("Starting interrogator monitoring loop...")

        interrogator_module.setup_interrogator_logging()  # console logging
        interrogator_thread = threading.Thread(
            target=interrogator_module.monitoring_loop,
            args=("SENTEA421", 400.0, interrogator_stop_event, interrogator_status_callback, interrogator_logfile),
            daemon=True,
        )
        interrogator_thread.start()

 

    # UI layout 

    tk.Label(root, text="Port (e.g., COM3)", font=font_large).grid( 

        row=0, column=0, padx=6, pady=6, sticky="e" 

    ) 

    portentry = tk.Entry(root, textvariable=portvar, width=12) 

    portentry.grid(row=0, column=1, padx=6, pady=6, sticky="w") 

 

    connectbutton = tk.Button(root, text="Connect", command=connect, bg="green", fg="white") 

    connectbutton.grid(row=0, column=2, padx=6, pady=6) 

 

    disconnectbutton = tk.Button( 

        root, 

        text="Disconnect", 

        command=disconnect, 

        bg="red", 

        fg="white", 

        state="disabled", 

    ) 

    disconnectbutton.grid(row=0, column=3, padx=6, pady=6) 

 

    statuslabel = tk.Label(root, text="Disconnected", fg="red") 

    statuslabel.grid(row=0, column=4, padx=6, pady=6, sticky="w") 

 

    # NEW: interrogator status label 

    interrogator_status_label = tk.Label(root, textvariable=interrogator_status, fg="blue") 

    interrogator_status_label.grid(row=0, column=5, padx=6, pady=6, sticky="w") 

 

    # Amplitude 

    tk.Label(root, text="Amplitude (V)", font=font_large).grid( 

        row=1, column=0, pady=8, sticky="e" 

    ) 

    ampslider = tk.Scale( 

        root, 

        variable=ampvar, 

        from_=0, 

        to=10, 

        orient="horizontal", 

        length=400, 

        resolution = 0.0001 

    ) 

    ampslider.grid(row=1, column=1, columnspan=3, pady=8, sticky="w") 

    ampentry = tk.Entry(root, textvariable=ampvar, width=8) 

    ampentry.grid(row=1, column=4, pady=8, sticky="w") 

 

    # Frequency 

    tk.Label(root, text="Frequency (Hz)", font=font_large).grid( 

        row=2, column=0, pady=8, sticky="e" 

    ) 

    freqslider = tk.Scale( 

        root, 

        variable=freqvar, 

        from_=0.1, 

        to=2000, 

        orient="horizontal", 

        length=400, 

        resolution = 0.1 

    ) 

    freqslider.grid(row=2, column=1, columnspan=3, pady=8, sticky="w") 

    freqentry = tk.Entry(root, textvariable=freqvar, width=8) 

    freqentry.grid(row=2, column=4, pady=8, sticky="w") 

 

    # Offset 

    tk.Label(root, text="Offset (V)", font=font_large).grid( 

        row=3, column=0, pady=8, sticky="e" 

    ) 

    offsetslider = tk.Scale( 

        root, 

        variable=offsetvar, 

        from_=0, 

        to=10, 

        orient="horizontal", 

        length=400, 

    ) 

    offsetslider.grid(row=3, column=1, columnspan=3, pady=8, sticky="w") 

    offsetentry = tk.Entry(root, textvariable=offsetvar, width=8) 

    offsetentry.grid(row=3, column=4, pady=8, sticky="w") 

 

    # Pulse duration 

    tk.Label(root, text="Pulse duration (ms)", font=font_large).grid( 

        row=4, column=0, pady=8, sticky="e" 

    ) 

    pulseslider = tk.Scale( 

        root, 

        variable=pulsevar, 

        from_=0.1, 

        to=5000, 

        orient="horizontal", 

        length=400, 

        resolution=0.1, 

    ) 

    pulseslider.grid(row=4, column=1, columnspan=3, pady=8, sticky="w") 

    pulseentry = tk.Entry(root, textvariable=pulsevar, width=8) 

    pulseentry.grid(row=4, column=4, pady=8, sticky="w") 

 

    # Total duration 

    tk.Label(root, text="Total duration (ms)", font=font_large).grid( 

        row=5, column=0, pady=8, sticky="e" 

    ) 

    durslider = tk.Scale( 

        root, 

        variable=durvar, 

        from_=100, 

        to=300000, 

        orient="horizontal", 

        length=400, 

    ) 

    durslider.grid(row=5, column=1, columnspan=3, pady=8, sticky="w") 

    durentry = tk.Entry(root, textvariable=durvar, width=8) 

    durentry.grid(row=5, column=4, pady=8, sticky="w") 

 

    # Buttons 

    tk.Button( 

        root, 

        text="Start pulse", 

        command=send_pulse, 

        bg="blue", 

        fg="white", 

    ).grid(row=6, column=1, pady=10) 

 

    tk.Button( 

        root, 

        text="Stop Output", 

        command=stop_output, 

        bg="red", 

        fg="white", 

    ).grid(row=6, column=2, pady=10) 

 

    tk.Button(root, text="Clear Log", command=clear_log).grid(row=6, column=3, pady=10) 

 

    # Log 

    tk.Label(root, text="Log", font=font_large).grid(row=7, column=0, pady=6, sticky="w") 

    loglabel = tk.Label( 

        root, 

        textvariable=logtext, 

        anchor="nw", 

        justify="left", 

        bg="white", 

        relief="sunken", 

        height=20, 

        width=120, 

    ) 

    loglabel.grid(row=8, column=0, columnspan=6, padx=6, pady=6) 

 

    root.after(100, poll_reader) 

    root.mainloop() 

 

 

if __name__ == "__main__": 

    run_gui() 
