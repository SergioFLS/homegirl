module lua_api.sys;

import std.string;
import riverd.lua;
import riverd.lua.types;

import program;

/**
  register system functions for a lua program
*/
void registerFunctions(Program program)
{
  auto lua = program.lua;
  luaL_dostring(lua, "sys = {}");

  /// sys.exit([code])
  extern (C) int sys_exit(lua_State* L) @trusted
  {
    const code = lua_tointeger(L, 1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    prog.shutdown(cast(int) code);
    return 0;
  }

  lua_register(lua, "_", &sys_exit);
  luaL_dostring(lua, "sys.exit = _");

  /// sys.exec(filename[, args[][, cwd]])
  extern (C) int sys_exec(lua_State* L) @trusted
  {
    const filename = fromStringz(lua_tostring(L, 1));
    const args_len = lua_rawlen(L, 2);
    const cwd = fromStringz(lua_tostring(L, 3));
    string[] args;
    lua_pushnil(L);
    for (uint i = 0; i < args_len; i++)
    {
      lua_next(L, 2);
      args ~= cast(string) fromStringz(lua_tostring(L, -1));
    }
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    try
    {
      prog.machine.startProgram(prog.resolve(cast(string) filename), args, cast(string) cwd);
      return 0;
    }
    catch (Exception err)
    {
      lua_pushstring(L, toStringz(err.msg));
      lua_error(L);
      return 0;
    }
  }

  lua_register(lua, "_", &sys_exec);
  luaL_dostring(lua, "sys.exec = _");

  /// sys.startchild(filename[, args[]]): child
  extern (C) int sys_startchild(lua_State* L) @trusted
  {
    const filename = fromStringz(lua_tostring(L, 1));
    const args_len = lua_rawlen(L, 2);
    string[] args;
    lua_pushnil(L);
    for (uint i = 0; i < args_len; i++)
    {
      lua_next(L, 2);
      args ~= cast(string) fromStringz(lua_tostring(L, -1));
    }
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    try
    {
      prog.startChild(prog.resolve(cast(string) filename), args);
      return 1;
    }
    catch (Exception err)
    {
      lua_pushstring(L, toStringz(err.msg));
      lua_error(L);
      return 0;
    }
  }

  lua_register(lua, "_", &sys_startchild);
  luaL_dostring(lua, "sys.startchild = _");

  /// sys.childrunning(child): bool
  extern (C) int sys_childrunning(lua_State* L) @trusted
  {
    const child = lua_tointeger(L, 1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    try
    {
      if (child >= prog.children.length || !prog.children[cast(uint) child])
        throw new Throwable("Invalid child!");
      lua_pushboolean(L, prog.children[cast(uint) child].running);
      return 1;
    }
    catch (Exception err)
    {
      lua_pushstring(L, toStringz(err.msg));
      lua_error(L);
      return 0;
    }
  }

  lua_register(lua, "_", &sys_childrunning);
  luaL_dostring(lua, "sys.childrunning = _");

  /// sys.childexitcode(child): int
  extern (C) int sys_childexitcode(lua_State* L) @trusted
  {
    const child = lua_tointeger(L, 1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    try
    {
      if (child >= prog.children.length || !prog.children[cast(uint) child])
        throw new Throwable("Invalid child!");
      lua_pushinteger(L, prog.children[cast(uint) child].exitcode);
      return 1;
    }
    catch (Exception err)
    {
      lua_pushstring(L, toStringz(err.msg));
      lua_error(L);
      return 0;
    }
  }

  /// sys.writetochild(child, str)
  extern (C) int sys_writetochild(lua_State* L) @trusted
  {
    const child = lua_tointeger(L, 1);
    const str = fromStringz(lua_tostring(L, 2));
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    try
    {
      if (child >= prog.children.length || !prog.children[cast(uint) child])
        throw new Throwable("Invalid child!");
      prog.children[cast(uint) child].write(0, cast(string) str);
      return 0;
    }
    catch (Exception err)
    {
      lua_pushstring(L, toStringz(err.msg));
      lua_error(L);
      return 0;
    }
  }

  lua_register(lua, "_", &sys_writetochild);
  luaL_dostring(lua, "sys.writetochild = _");

  /// sys.readfromchild(child): str
  extern (C) int sys_readfromchild(lua_State* L) @trusted
  {
    const child = lua_tointeger(L, 1);
    const str = fromStringz(lua_tostring(L, 2));
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    try
    {
      if (child >= prog.children.length || !prog.children[cast(uint) child])
        throw new Throwable("Invalid child!");
      lua_pushstring(L, toStringz(prog.children[cast(uint) child].read(1)));
      return 1;
    }
    catch (Exception err)
    {
      lua_pushstring(L, toStringz(err.msg));
      lua_error(L);
      return 0;
    }
  }

  lua_register(lua, "_", &sys_readfromchild);
  luaL_dostring(lua, "sys.readfromchild = _");

  /// sys.errorfromchild(child): str
  extern (C) int sys_errorfromchild(lua_State* L) @trusted
  {
    const child = lua_tointeger(L, 1);
    const str = fromStringz(lua_tostring(L, 2));
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    try
    {
      if (child >= prog.children.length || !prog.children[cast(uint) child])
        throw new Throwable("Invalid child!");
      lua_pushstring(L, toStringz(prog.children[cast(uint) child].read(2)));
      return 1;
    }
    catch (Exception err)
    {
      lua_pushstring(L, toStringz(err.msg));
      lua_error(L);
      return 0;
    }
  }

  lua_register(lua, "_", &sys_errorfromchild);
  luaL_dostring(lua, "sys.errorfromchild = _");

  /// sys.killchild(child)
  extern (C) int sys_killchild(lua_State* L) @trusted
  {
    const child = lua_tointeger(L, 1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    try
    {
      if (child >= prog.children.length || !prog.children[cast(uint) child])
        throw new Throwable("Invalid child!");
      prog.removeChild(cast(uint) child);
      return 0;
    }
    catch (Exception err)
    {
      lua_pushstring(L, toStringz(err.msg));
      lua_error(L);
      return 0;
    }
  }

  lua_register(lua, "_", &sys_killchild);
  luaL_dostring(lua, "sys.killchild = _");
}
