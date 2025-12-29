#!/usr/bin/env python3
"""
X4 Foundations NVDA Bridge - SirNukes Pipe Server Module

This module integrates with SirNukes' pipe server (X4_Python_Pipe_Server) to receive
messages from X4 and forward them to NVDA for text-to-speech output.

The module is loaded by the pipe server when X4 registers it via MD script.
"""

import sys
import os
import ctypes
from pathlib import Path

# Check platform
if sys.platform != 'win32':
    print("Error: NVDA bridge only works on Windows")
    sys.exit(1)

# Add the pipe server to path so we can import from it
script_dir = Path(__file__).parent.resolve()
pipe_server_dir = script_dir / 'X4_Python_Pipe_Server'
if str(pipe_server_dir) not in sys.path:
    sys.path.insert(0, str(pipe_server_dir))

# Import SirNukes pipe classes
from X4_Python_Pipe_Server.Classes import Pipe_Server

# Name of our pipe - X4 Lua will connect to this
PIPE_NAME = 'x4_nvda'


class NVDAController:
    """Interface to NVDA's controller client DLL."""

    def __init__(self):
        self.dll = None
        self._load_nvda_client()

    def _load_nvda_client(self):
        """Load the NVDA controller client DLL."""
        script_dir = Path(__file__).parent.resolve()

        possible_paths = [
            script_dir / 'nvdaControllerClient64.dll',
            script_dir / 'nvdaControllerClient32.dll',
            Path(os.environ.get('PROGRAMFILES', 'C:\\Program Files')) / 'NVDA' / 'nvdaControllerClient64.dll',
            Path(os.environ.get('PROGRAMFILES(X86)', 'C:\\Program Files (x86)')) / 'NVDA' / 'nvdaControllerClient32.dll',
        ]

        for dll_path in possible_paths:
            if dll_path.exists():
                try:
                    self.dll = ctypes.windll.LoadLibrary(str(dll_path))
                    print(f"[NVDA] Loaded controller from: {dll_path}")
                    return
                except OSError as e:
                    print(f"[NVDA] Failed to load {dll_path}: {e}")
                    continue

        print("[NVDA] Warning: Could not load NVDA controller client DLL")
        print("[NVDA] Speech will be printed to console instead.")

    def test_if_running(self):
        """Check if NVDA is running."""
        if not self.dll:
            return False
        try:
            result = self.dll.nvdaController_testIfRunning()
            return result == 0
        except Exception:
            return False

    def speak(self, text):
        """Speak text through NVDA."""
        if not text:
            return False

        if self.dll:
            try:
                result = self.dll.nvdaController_speakText(text)
                if result == 0:
                    return True
                else:
                    print(f"[NVDA] Speak failed with code: {result}")
            except Exception as e:
                print(f"[NVDA] Speak error: {e}")

        # Fallback: print to console
        print(f"[NVDA SPEAK] {text}")
        return False

    def cancel_speech(self):
        """Cancel any current speech."""
        if self.dll:
            try:
                self.dll.nvdaController_cancelSpeech()
                return True
            except Exception as e:
                print(f"[NVDA] Cancel error: {e}")
        return False


def process_message(nvda, message):
    """Process a message from X4."""
    if not message:
        return

    message = message.strip()
    if not message:
        return

    print(f"[NVDA] Received: {message}")

    # Handle pipe protocol: SPEAK|text or STOP or STOP|SPEAK|text
    parts = message.split('|')

    i = 0
    while i < len(parts):
        cmd = parts[i].upper()

        if cmd == 'STOP':
            nvda.cancel_speech()
            i += 1

        elif cmd == 'SPEAK':
            if i + 1 < len(parts):
                text = parts[i + 1]
                nvda.speak(text)
                i += 2
            else:
                i += 1

        elif cmd == 'CONTEXT':
            # Context info for verbosity control
            if i + 1 < len(parts):
                i += 2
            else:
                i += 1

        else:
            # Unknown command - treat as text to speak
            if cmd:
                nvda.speak(cmd)
            i += 1


def main(args):
    """
    Main entry point - called by the pipe server.

    Args is a dict with:
        'test': bool - True if in test mode
    """
    print("=" * 50)
    print("[NVDA] X4 Foundations NVDA Bridge Starting")
    print("=" * 50)

    # Initialize NVDA controller
    nvda = NVDAController()

    if nvda.test_if_running():
        print("[NVDA] NVDA is running")
        nvda.speak("X4 NVDA Bridge connected")
    else:
        print("[NVDA] Warning: NVDA does not appear to be running")
        print("[NVDA] Messages will be printed to console")

    # Create our pipe server
    pipe = Pipe_Server(PIPE_NAME)

    # Wait for X4 Lua to connect
    pipe.Connect()
    print(f"[NVDA] X4 connected to pipe: {PIPE_NAME}")

    # Announce connection
    nvda.speak("X4 accessibility ready")

    # Message loop
    try:
        while True:
            message = pipe.Read()
            if message is None:
                print("[NVDA] Pipe disconnected")
                break

            process_message(nvda, message)

            # Send acknowledgment
            pipe.Write("OK")

    except Exception as e:
        print(f"[NVDA] Error: {e}")

    finally:
        pipe.Close()
        nvda.speak("X4 NVDA Bridge disconnected")

    print("[NVDA] Bridge stopped")


if __name__ == '__main__':
    # For direct testing
    main({'test': True})
