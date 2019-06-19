module lua_api.image;

import std.string;
import riverd.lua;
import riverd.lua.types;

import program;
import pixmap;

/**
  register image functions for a lua program
*/
void registerFunctions(Program program)
{
  auto lua = program.lua;
  luaL_dostring(lua, "image = {}");

  /// image.createimage(width, height, colorbits): id
  extern (C) int image_createimage(lua_State* L) @trusted
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

  lua_register(lua, "_", &image_createimage);
  luaL_dostring(lua, "image.createimage = _");

  /// image.loadimage(filename): id
  extern (C) int image_loadimage(lua_State* L) @trusted
  {
    auto filename = fromStringz(lua_tostring(L, -1));
    //Get the pointer
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    lua_pushinteger(L, prog.loadPixmap(cast(string) filename));
    return 1;
  }

  lua_register(lua, "_", &image_loadimage);
  luaL_dostring(lua, "image.loadimage = _");

  /// image.loadanimation(filename): id
  extern (C) int image_loadanimation(lua_State* L) @trusted
  {
    auto filename = fromStringz(lua_tostring(L, -1));
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    uint[] anim = prog.loadAnimation(cast(string) filename);
    lua_createtable(L, cast(uint) anim.length, 0);
    for (uint i = 0; i < anim.length; i++)
    {
      lua_pushinteger(L, anim[i]);
      lua_rawseti(L, -2, i + 1);
    }
    return 1;
  }

  lua_register(lua, "_", &image_loadanimation);
  luaL_dostring(lua, "image.loadanimation = _");

  /// image.imagewidth(imgID): width
  extern (C) int image_imagewidth(lua_State* L) @trusted
  {
    const imgId = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    lua_pushinteger(L, prog.pixmaps[cast(uint) imgId].width);
    return 1;
  }

  lua_register(lua, "_", &image_imagewidth);
  luaL_dostring(lua, "image.imagewidth = _");

  /// image.imageheight(imgID): height
  extern (C) int image_imageheight(lua_State* L) @trusted
  {
    const imgId = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    lua_pushinteger(L, prog.pixmaps[cast(uint) imgId].height);
    return 1;
  }

  lua_register(lua, "_", &image_imageheight);
  luaL_dostring(lua, "image.imageheight = _");

  /// image.imageduration(imgID): height
  extern (C) int image_imageduration(lua_State* L) @trusted
  {
    const imgId = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    lua_pushinteger(L, prog.pixmaps[cast(uint) imgId].duration);
    return 1;
  }

  lua_register(lua, "_", &image_imageduration);
  luaL_dostring(lua, "image.imageduration = _");

  /// image.copymode(mode)
  extern (C) int image_copymode(lua_State* L) @trusted
  {
    const mode = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    if (!prog.activeViewport)
    {
      lua_pushstring(L, "No active viewport!");
      lua_error(L);
      return 0;
    }
    prog.activeViewport.pixmap.copymode = cast(CopyMode) mode;
    return 0;
  }

  lua_register(lua, "_", &image_copymode);
  luaL_dostring(lua, "image.copymode = _");

  /// image.drawimage(imgID, x, y, imgx, imgy, width, height)
  extern (C) int image_drawimage(lua_State* L) @trusted
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
    if (imgID >= prog.pixmaps.length || !prog.pixmaps[cast(uint) imgID])
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

  lua_register(lua, "_", &image_drawimage);
  luaL_dostring(lua, "image.drawimage = _");

  /// image.copyimage(imgID, x, y, imgx, imgy, width, height)
  extern (C) int image_copyimage(lua_State* L) @trusted
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

  lua_register(lua, "_", &image_copyimage);
  luaL_dostring(lua, "image.copyimage = _");

  /// image.copypalette(imgID)
  extern (C) int image_copypalette(lua_State* L) @trusted
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

  lua_register(lua, "_", &image_copypalette);
  luaL_dostring(lua, "image.copypalette = _");

  /// image.usepalette(imgID)
  extern (C) int image_usepalette(lua_State* L) @trusted
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

  lua_register(lua, "_", &image_usepalette);
  luaL_dostring(lua, "image.usepalette = _");

  /// image.forgetimage(imgID)
  extern (C) int image_forgetimage(lua_State* L) @trusted
  {
    const imgId = lua_tointeger(L, -1);
    lua_getglobal(L, "__program");
    auto prog = cast(Program*) lua_touserdata(L, -1);
    prog.removePixmap(cast(uint) imgId);
    return 0;
  }

  lua_register(lua, "_", &image_forgetimage);
  luaL_dostring(lua, "image.forgetimage = _");
}
