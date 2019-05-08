module lua_api;

import std.stdio;
import std.string;
import riverd.lua;
import riverd.lua.types;

import program;

/**
  register some functions for a lua program
*/
void registerFunctions(Program program)
{
  auto lua = program.lua;

  //Setup the userdata
  auto prog = cast(Program*) lua_newuserdata(lua, Program.sizeof);
  *prog = program;
  lua_setglobal(lua, "__program");

  extern (C) int panic(lua_State* L) @trusted
  {
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    prog.shutdown();
    writeln("Shit hit the fan!");
    return 0;
  }

  lua_atpanic(lua, &panic);

  /// print(message)
  extern (C) int print(lua_State* L) @trusted
  {
    const msg = lua_tostring(L, -1);
    writeln("Program says: " ~ fromStringz(msg));
    return 0;
  }

  lua_register(lua, "print", &print);

  /// int createscreen(mode, colorbits)
  extern (C) int createscreen(lua_State* L) @trusted
  {
    const mode = lua_tointeger(L, -2);
    const colorBits = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    lua_pushinteger(L, prog.createScreen(cast(ubyte) mode, cast(ubyte) colorBits));
    return 1;
  }

  lua_register(lua, "createscreen", &createscreen);

  /// int createviewport(parent, left, top, width, height)
  extern (C) int createviewport(lua_State* L) @trusted
  {
    const parentId = lua_tointeger(L, -5);
    const left = lua_tonumber(L, -4);
    const top = lua_tonumber(L, -3);
    const width = lua_tonumber(L, -2);
    const height = lua_tonumber(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    lua_pushinteger(L, prog.createViewport(cast(uint) parentId, cast(int) left,
        cast(int) top, cast(uint) width, cast(uint) height));
    return 1;
  }

  lua_register(lua, "createviewport", &createviewport);

  /// removeviewport(vpID)
  extern (C) int removeviewport(lua_State* L) @trusted
  {
    const vpId = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    prog.removeViewport(cast(uint) vpId);
    return 0;
  }

  lua_register(lua, "removeviewport", &removeviewport);

  /// int createimage(width, height, colorbits)
  extern (C) int createimage(lua_State* L) @trusted
  {
    const width = lua_tonumber(L, -3);
    const height = lua_tonumber(L, -2);
    const colorBits = lua_tointeger(L, -1);
    //Get the pointer
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    lua_pushinteger(L, prog.createPixmap(cast(uint) width, cast(uint) height, cast(ubyte) colorBits));
    return 1;
  }

  lua_register(lua, "createimage", &createimage);

  /// int loadimage(filename)
  extern (C) int loadimage(lua_State* L) @trusted
  {
    auto filename = fromStringz(lua_tostring(L, -1));
    //Get the pointer
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    lua_pushinteger(L, prog.loadPixmap(cast(string) filename));
    return 1;
  }

  lua_register(lua, "loadimage", &loadimage);

  /// int imagewidth(imgID)
  extern (C) int imagewidth(lua_State* L) @trusted
  {
    const imgId = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    lua_pushinteger(L, prog.pixmaps[cast(uint) imgId].width);
    return 1;
  }

  lua_register(lua, "imagewidth", &imagewidth);

  /// int imageheight(imgID)
  extern (C) int imageheight(lua_State* L) @trusted
  {
    const imgId = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    lua_pushinteger(L, prog.pixmaps[cast(uint) imgId].height);
    return 1;
  }

  lua_register(lua, "imageheight", &imageheight);

  /// forgetimage(imgID)
  extern (C) int forgetimage(lua_State* L) @trusted
  {
    const imgId = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    prog.removePixmap(cast(uint) imgId);
    return 0;
  }

  lua_register(lua, "forgetimage", &forgetimage);

  /// copyimage(imgID, x, y, imgx, imgy, width, height)
  extern (C) int copyimage(lua_State* L) @trusted
  {
    const imgID = lua_tonumber(L, -7);
    const x = lua_tonumber(L, -6);
    const y = lua_tonumber(L, -5);
    const imgx = lua_tonumber(L, -4);
    const imgy = lua_tonumber(L, -3);
    const width = lua_tonumber(L, -2);
    const height = lua_tonumber(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    if (!prog.activeViewport)
    {
      lua_pushstring(L, "No active viewport!");
      lua_error(L);
      return 0;
    }
    if (!prog.pixmaps[cast(uint) imgID])
    {
      lua_pushstring(L, "Invalid image!");
      lua_error(L);
      return 0;
    }
    prog.pixmaps[cast(uint) imgID].copyFrom(prog.activeViewport.pixmap,
        cast(int) x, cast(int) y, cast(int) imgx, cast(int) imgy,
        cast(uint) width, cast(uint) height);
    return 0;
  }

  lua_register(lua, "copyimage", &copyimage);

  /// drawimage(imgID, x, y, imgx, imgy, width, height)
  extern (C) int drawimage(lua_State* L) @trusted
  {
    const imgID = lua_tointeger(L, -7);
    const x = lua_tonumber(L, -6);
    const y = lua_tonumber(L, -5);
    const imgx = lua_tonumber(L, -4);
    const imgy = lua_tonumber(L, -3);
    const width = lua_tonumber(L, -2);
    const height = lua_tonumber(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    if (!prog.activeViewport)
    {
      lua_pushstring(L, "No active viewport!");
      lua_error(L);
      return 0;
    }
    if (!prog.pixmaps[cast(uint) imgID])
    {
      lua_pushstring(L, "Invalid image!");
      lua_error(L);
      return 0;
    }
    prog.activeViewport.pixmap.copyFrom(prog.pixmaps[cast(uint) imgID],
        cast(int) imgx, cast(int) imgy, cast(int) x, cast(int) y,
        cast(uint) width, cast(uint) height);
    return 0;
  }

  lua_register(lua, "drawimage", &drawimage);

  /// copypalette(imgID)
  extern (C) int copypalette(lua_State* L) @trusted
  {
    const imgID = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    if (!prog.activeViewport)
    {
      lua_pushstring(L, "No active viewport!");
      lua_error(L);
      return 0;
    }
    if (!prog.pixmaps[cast(uint) imgID])
    {
      lua_pushstring(L, "Invalid image!");
      lua_error(L);
      return 0;
    }
    prog.pixmaps[cast(uint) imgID].copyPaletteFrom(prog.activeViewport.pixmap);
    return 0;
  }

  lua_register(lua, "copypalette", &copypalette);

  /// usepalette(imgID)
  extern (C) int usepalette(lua_State* L) @trusted
  {
    const imgID = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    if (!prog.activeViewport)
    {
      lua_pushstring(L, "No active viewport!");
      lua_error(L);
      return 0;
    }
    if (!prog.pixmaps[cast(uint) imgID])
    {
      lua_pushstring(L, "Invalid image!");
      lua_error(L);
      return 0;
    }
    prog.activeViewport.pixmap.copyPaletteFrom(prog.pixmaps[cast(uint) imgID]);
    return 0;
  }

  lua_register(lua, "usepalette", &usepalette);

  /// setfgcolor(index)
  extern (C) int setfgcolor(lua_State* L) @trusted
  {
    const cindex = lua_tonumber(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    if (prog.activeViewport)
    {
      prog.activeViewport.pixmap.fgColor = cast(ubyte) cindex;
    }
    else
    {
      lua_pushstring(L, "No active viewport!");
      lua_error(L);
    }
    return 0;
  }

  lua_register(lua, "setfgcolor", &setfgcolor);

  /// setbgcolor(index)
  extern (C) int setbgcolor(lua_State* L) @trusted
  {
    const cindex = lua_tonumber(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    if (prog.activeViewport)
    {
      prog.activeViewport.pixmap.bgColor = cast(ubyte) cindex;
    }
    else
    {
      lua_pushstring(L, "No active viewport!");
      lua_error(L);
    }
    return 0;
  }

  lua_register(lua, "setbgcolor", &setbgcolor);

  /// plot(x, y)
  extern (C) int plot(lua_State* L) @trusted
  {
    const x = lua_tonumber(L, -2);
    const y = lua_tonumber(L, -1);
    //Get the pointer
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    if (prog.activeViewport)
    {
      prog.activeViewport.pixmap.plot(cast(uint) x, cast(uint) y);
    }
    else
    {
      lua_pushstring(L, "No active viewport!");
      lua_error(L);
    }
    return 0;
  }

  lua_register(lua, "plot", &plot);
}
