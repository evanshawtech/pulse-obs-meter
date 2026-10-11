"""Run local Lua mock tests without installing anything or launching OBS.

Uses LUA_LIBRARY when explicitly set, otherwise an already-installed lua/luajit
CLI or liblua 5.4/5.3. Lua 5.1/LuaJIT libraries are supported without installing
anything. These remain mock tests, NOT an OBS API test.

On Windows, pass --library with an existing absolute lua51.dll path.
The legacy LUA_LIBRARY option remains supported but is not required. Only that DLL's parent directory is temporarily
used for dependency loading; the system PATH is unchanged.
"""
import argparse
import ctypes
import ctypes.util
import os
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
os.chdir(root)
test_file = "tests/obs-controls-tests.lua"
parser = argparse.ArgumentParser(description="Run local Lua mock tests; no OBS process is started.")
parser.add_argument("--library", help="Existing Lua shared library path; avoids changing environment variables")
args = parser.parse_args()
configured_library = args.library if args.library is not None else os.environ.get("LUA_LIBRARY")
if configured_library is None:
    for binary in ("luajit", "lua", "lua5.4", "lua5.3"):
        executable = shutil.which(binary)
        if executable:
            print(f"Using installed interpreter: {binary}; mock tests only", flush=True)
            sys.exit(subprocess.call([executable, test_file]))

library = configured_library
if library is None:
    library = next((path for name in ("lua5.4", "lua5.3") if (path := ctypes.util.find_library(name))), None)
if not library:
    if configured_library is not None:
        sys.exit("FAILED: LUA_LIBRARY is empty; specify an existing Lua shared library.")
    sys.exit("SKIPPED: no installed Lua CLI or liblua 5.4/5.3. No software was installed.")
dll_directory = None
if configured_library is not None:
    library_path = Path(library).resolve()
    if not library_path.is_file():
        sys.exit(f"FAILED: LUA_LIBRARY file does not exist: {library_path}")
    library = str(library_path)
    if os.name == "nt":
        try:
            dll_directory = os.add_dll_directory(str(library_path.parent))
        except OSError as error:
            sys.exit(f"FAILED: cannot use LUA_LIBRARY dependency directory: {error}")
try:
    lua = ctypes.CDLL(library)
except OSError as error:
    if dll_directory:
        dll_directory.close()
    sys.exit(f"FAILED: cannot load Lua shared library {library}: {error}")
required_exports = ("luaL_newstate", "luaL_openlibs", "luaL_loadstring", "lua_tolstring", "lua_close")
missing_exports = [name for name in required_exports if not hasattr(lua, name)]
if not (hasattr(lua, "lua_pcall") or hasattr(lua, "lua_pcallk")):
    missing_exports.append("lua_pcall or lua_pcallk")
if missing_exports:
    if dll_directory:
        dll_directory.close()
    sys.exit(f"FAILED: Lua shared library lacks required exports: {', '.join(missing_exports)}")
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_newstate.argtypes = []
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_openlibs.restype = None
lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
lua.luaL_loadstring.restype = ctypes.c_int
if hasattr(lua, "lua_pcall"):
    lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    lua.lua_pcall.restype = ctypes.c_int
    protected_call = lambda state: lua.lua_pcall(state, 0, 0, 0)
else:
    lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ssize_t, ctypes.c_void_p]
    lua.lua_pcallk.restype = ctypes.c_int
    protected_call = lambda state: lua.lua_pcallk(state, 0, 0, 0, 0, None)
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
lua.lua_close.restype = None
state = lua.luaL_newstate()
if not state:
    if dll_directory:
        dll_directory.close()
    sys.exit("FAILED: Lua state allocation failed")
try:
    print(f"Using installed shared library: {library}; mock tests only", flush=True)
    lua.luaL_openlibs(state)
    runtime_report = b"print('Lua runtime: ' .. _VERSION .. (jit and (' / ' .. jit.version) or '') .. '; mock tests only; real OBS APIs are not exercised')\n"
    result = lua.luaL_loadstring(state, runtime_report + Path(test_file).read_bytes())
    if not result:
        result = protected_call(state)
    if result:
        message = lua.lua_tolstring(state, -1, None)
        sys.exit(message.decode("utf-8", errors="replace") if message else "Unknown Lua error")
finally:
    lua.lua_close(state)
    if dll_directory:
        dll_directory.close()
