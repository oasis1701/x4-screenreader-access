# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec file for X4 NVDA Accessibility Server

import os
spec_dir = os.path.dirname(os.path.abspath(SPEC))

a = Analysis(
    [os.path.join(spec_dir, 'X4_Python_Pipe_Server', 'Main.py')],
    pathex=[spec_dir, os.path.join(spec_dir, 'X4_Python_Pipe_Server')],
    binaries=[],
    datas=[
        # Bundle the NVDA controller DLL
        (os.path.join(spec_dir, 'nvdaControllerClient64.dll'), '.'),
        # Bundle permissions.json
        (os.path.join(spec_dir, 'X4_Python_Pipe_Server', 'permissions.json'), '.'),
    ],
    hiddenimports=[
        'win32api',
        'win32file',
        'win32pipe',
        'win32security',
        'win32process',
        'win32con',
        'win32gui',
        'winerror',
        'ctypes',
        # For SirNukes' send_keys module
        'pynput',
        'pynput.keyboard',
        'pynput.mouse',
        # Local Classes package
        'Classes',
        'Classes.Server_Thread',
        'Classes.Pipe',
        'Classes.Misc',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='X4_NVDA_Server',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,  # Keep console visible
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='X4_NVDA_Server',
)
