module pixmap;

import std.utf;
import std.math;
import std.algorithm.comparison;
import bindbc.sdl;

import viewport;

/**
  index-based pixel map
*/
class Pixmap
{
  uint width; /// width of pixel map
  uint height; /// height of pixel map
  ubyte colorBits; /// bits per color
  ubyte fgColor = 1; /// index of foreground color
  ubyte bgColor = 0; /// index of background/transparent color
  ubyte[] pixels; /// all the pixels
  ubyte[] palette; /// the color palette
  uint duration = 100; /// number of milliseconds this pixmap is meant to be displayed
  CopyMode copymode = CopyMode.replace; /// the mode by which to copy other pixmaps onto this one
  CopyMode textCopymode = CopyMode.color; /// the mode by which to copy other pixmaps onto this one
  Viewport viewport; /// associated viewport

  /**
    create new pixmap
  */
  this(int width, int height, ubyte colorBits)
  {
    if (colorBits > 8)
      throw new Exception("Too many colorbits!");
    this.width = max(0, width);
    this.height = max(0, height);
    this.colorBits = colorBits;

    uint colors = 1;
    for (ubyte i = 0; i < colorBits; i++)
      colors *= 2;
    this.palette.length = colors * 3;
    this.pixelMask = cast(ubyte)(colors - 1);
    this.defaultPalette(colors);

    this.pixels.length = this.width * this.height;
    for (uint i = 0; i < this.pixels.length; i++)
      this.pixels[i] = 0;
  }

  /**
    initiate texture representation
  */
  void initTexture(SDL_Renderer* ren)
  {
    if (this.texture)
      return;
    this.texture = SDL_CreateTexture(ren, SDL_PIXELFORMAT_BGR888,
        SDL_TEXTUREACCESS_STREAMING, this.width, this.height);
    this.textureLocked = false;
  }

  /**
    refresh all pixels in texture to represent pixmap
  */
  void updateTexture()
  {
    // ubyte* texdata = null;
    int pitch;
    SDL_LockTexture(this.texture, null, cast(void**)&texdata, &pitch);
    this.textureLocked = true;
    uint src = 0;
    uint dest = 0;
    for (uint i = 0; i < this.pixels.length; i++)
    {
      src = this.pixels[i] * 3 % this.palette.length;
      texdata[dest++] = this.palette[src++];
      texdata[dest++] = this.palette[src++];
      texdata[dest++] = this.palette[src++];
      texdata[dest++] = 255;
    }
  }

  /**
    copy pixmap to an unlocked texture
  */
  void copyToTexture(Pixmap pix, bool ui, int px = 0, int py = 0, uint sx = 1, uint sy = 1)
  {
    if (!this.uicolors[0])
      this.findUIcolors();
    if (ui)
    {
      for (uint y = 0; y < pix.height * sy; y++)
        for (uint x = 0; x < pix.width * sx; x++)
          if (pix.pget(x / sx, y / sy))
            this.psetTexture(px + x, py + y, this.uicolors[pix.pget(x / sx,
                  y / sy) % this.uicolors.length]);
    }
    else
    {
      for (uint y = 0; y < pix.height * sy; y++)
        for (uint x = 0; x < pix.width * sx; x++)
          if (pix.pget(x / sx, y / sy) != pix.bgColor)
            this.psetTexture(px + x, py + y, pix.pget(x / sx, y / sy) % this.palette.length);
    }
  }

  /**
    get texture
  */
  SDL_Texture* getTexture()
  {
    if (this.textureLocked)
      SDL_UnlockTexture(this.texture);
    this.textureLocked = false;
    this.texdata = null;
    return this.texture;
  }

  /**
    destroy texture representation
  */
  void destroyTexture()
  {
    if (this.texture)
    {
      SDL_DestroyTexture(this.texture);
      this.texture = null;
      this.textureLocked = false;
      this.texdata = null;
    }
  }

  /**
    calculate memory usage of this pixmap
  */
  uint memoryUsed()
  {
    return (this.width * this.height * this.colorBits) / 8;
  }

  /**
    clear the pixmap with background color
  */
  void cls()
  {
    for (uint i = 0; i < this.pixels.length; i++)
      this.pixels[i] = this.bgColor & this.pixelMask;
    if (this.viewport)
      this.viewport.setDirty();
  }

  /**
    edit a color in the color palette
  */
  void setColor(uint index, ubyte red, ubyte green, ubyte blue)
  {
    uint i = (3 * index) % this.palette.length;
    this.palette[i++] = (red % 16) * 17;
    this.palette[i++] = (green % 16) * 17;
    this.palette[i++] = (blue % 16) * 17;
    this.uicolors[0] = 0;
    if (this.viewport)
      this.viewport.setDirty();
  }

  /**
    set the current foreground color
  */
  void setFGColor(ubyte index)
  {
    this.fgColor = index & this.pixelMask;
  }

  /**
    set the current background color
  */
  void setBGColor(ubyte index)
  {
    this.bgColor = index & this.pixelMask;
  }

  /**
    find color closest to given r, g, b values
  */
  ubyte nearestColor(ubyte red, ubyte green, ubyte blue)
  {
    uint l = cast(uint)(this.palette.length / 3);
    red = (red % 16) * 17;
    green = (green % 16) * 17;
    blue = (blue % 16) * 17;
    ubyte best = 3;
    real record = 1024;
    for (uint i = 0; i < l; i++)
    {
      ubyte _red = this.palette[i * 3 + 0];
      ubyte _green = this.palette[i * 3 + 1];
      ubyte _blue = this.palette[i * 3 + 2];
      const diff = sqrt(cast(real)(pow(red - _red, 2) + pow(green - _green, 2) + pow(blue - _blue,
          2)));
      if (diff == 0)
        return cast(ubyte) i;
      if (diff < record)
      {
        record = diff;
        best = cast(ubyte) i;
      }
    }
    return best;
  }

  /**
    get color of specific pixel
  */
  ubyte pget(uint x, uint y)
  {
    if (x >= this.width || y >= this.height)
      return this.bgColor;
    const i = y * this.width + x;
    return this.pixels[i];
  }

  /**
    set color of specific pixel
  */
  void pset(uint x, uint y, ubyte c)
  {
    if (x >= this.width || y >= this.height)
      return;
    uint i = y * this.width + x;
    this.pixels[i] = c & this.pixelMask;
    if (this.viewport)
      this.viewport.setDirty();
  }

  /**
    set specific pixel to foreground color
  */
  void plot(int x, int y)
  {
    this.pset(x, y, this.fgColor);
  }

  /**
    draw a filled rectange with foreground color
  */
  void bar(int x, int y, int width, int height)
  {
    if (width < 0)
    {
      x += width;
      width *= -1;
    }
    if (height < 0)
    {
      y += height;
      height *= -1;
    }
    if (x < 0)
    {
      width += x;
      x = 0;
    }
    if (y < 0)
    {
      height += y;
      y = 0;
    }
    if (width < 0)
      width = 0;
    if (height < 0)
      height = 0;
    if (width + x > this.width)
      width = this.width - x;
    if (height + y > this.height)
      height = this.height - y;
    if (x > this.width)
      width = 0;
    if (y > this.height)
      height = 0;
    for (uint _y = 0; _y < height; _y++)
    {
      for (uint _x = 0; _x < width; _x++)
      {
        plot(x + _x, y + _y);
      }
    }
  }

  /**
    draw a line with foreground color
  */
  void line(int x1, int y1, int x2, int y2)
  {
    this.plot(x1, y1);
    if (abs(x2 - x1) > abs(y2 - y1))
    {
      int d = x1 < x2 ? 1 : -1;
      for (double x = x1; x != x2; x += d)
        this.plot(cast(int) x, cast(int) round(this.interpolate(x1, x2, x, y1, y2)));
    }
    else
    {
      int d = y1 < y2 ? 1 : -1;
      for (double y = y1; y != y2; y += d)
        this.plot(cast(int) round(this.interpolate(y1, y2, y, x1, x2)), cast(int) y);
    }
    this.plot(x2, y2);
  }

  /** 
    draw a filled triangle with foreground color
  */
  void triangle(double dx1, double dy1, double dx2, double dy2, double dx3, double dy3)
  {
    double swp;
    if (dy1 > dy2)
    {
      swp = dx1;
      dx1 = dx2;
      dx2 = swp;
      swp = dy1;
      dy1 = dy2;
      dy2 = swp;
    }
    if (dy1 > dy3)
    {
      swp = dx1;
      dx1 = dx3;
      dx3 = swp;
      swp = dy1;
      dy1 = dy3;
      dy3 = swp;
    }
    if (dy2 > dy3)
    {
      swp = dx2;
      dx2 = dx3;
      dx3 = swp;
      swp = dy2;
      dy2 = dy3;
      dy3 = swp;
    }
    for (double _dy = dy1; _dy < dy2; _dy++)
    {
      double _dx1 = round(this.interpolate(dy1, dy2, _dy, dx1, dx2));
      double _dx2 = round(this.interpolate(dy1, dy3, _dy, dx1, dx3));
      if (_dx1 > _dx2)
      {
        swp = _dx1;
        _dx1 = _dx2;
        _dx2 = swp;
      }
      for (double _dx = _dx1; _dx <= _dx2; _dx++)
      {
        this.plot(cast(uint) _dx, cast(uint) _dy);
      }
    }
    for (double _dy = dy2; _dy <= dy3; _dy++)
    {
      double _dx1 = round(this.interpolate(dy2, dy3, _dy, dx2, dx3));
      double _dx2 = round(this.interpolate(dy1, dy3, _dy, dx1, dx3));
      if (_dx1 > _dx2)
      {
        swp = _dx1;
        _dx1 = _dx2;
        _dx2 = swp;
      }
      for (double _dx = _dx1; _dx <= _dx2; _dx++)
      {
        this.plot(cast(uint) _dx, cast(uint) _dy);
      }
    }
  }

  /** 
    copy pixels from another pixmap
  */
  void copyPixFrom(Pixmap src, uint sx, uint sy, uint dx, uint dy)
  {
    if (dx >= this.width || dy >= this.height)
      return;
    sx %= src.width;
    sy %= src.height;

    const c = src.pget(sx, sy);
    switch (this.copymode)
    {
    case CopyMode.replace:
      this.pset(dx, dy, c);
      break;
    case CopyMode.matte:
      if (c != src.bgColor)
        this.pset(dx, dy, c);
      break;
    case CopyMode.color:
      if (c != src.bgColor)
        this.pset(dx, dy, this.fgColor);
      break;
    case CopyMode.xor:
      this.pset(dx, dy, this.pget(dx, dy) ^ c);
      break;
    case CopyMode.min:
      this.pset(dx, dy, min(this.pget(dx, dy), c));
      break;
    case CopyMode.max:
      this.pset(dx, dy, max(this.pget(dx, dy), c));
      break;
    case CopyMode.add:
      this.pset(dx, dy, cast(ubyte)(this.pget(dx, dy) + c));
      break;
    case CopyMode.matchReplace:
      this.pset(dx, dy,
          this.nearestColor(src.palette[c * 3 + 0], src.palette[c * 3 + 1], src.palette[c * 3 + 2]));
      break;
    case CopyMode.matchMatte:
      if (c != src.bgColor)
        this.pset(dx, dy,
            this.nearestColor(src.palette[c * 3 + 0], src.palette[c * 3 + 1], src.palette[c * 3 + 2]));
      break;
    case CopyMode.averageColor:
      const _c = this.pget(dx, dy);
      this.pset(dx, dy, this.nearestColor((this.palette[_c * 3 + 0] + src.palette[c * 3 + 0]) / 32,
          (this.palette[_c * 3 + 1] + src.palette[c * 3 + 1]) / 32,
          (this.palette[_c * 3 + 2] + src.palette[c * 3 + 2]) / 32));
      break;
    case CopyMode.darkerColor:
      const _c = this.pget(dx, dy);
      this.pset(dx, dy, this.nearestColor(min(this.palette[_c * 3 + 0],
          src.palette[c * 3 + 0]), min(this.palette[_c * 3 + 1],
          src.palette[c * 3 + 1]), min(this.palette[_c * 3 + 2], src.palette[c * 3 + 2])));
      break;
    case CopyMode.lighterColor:
      const _c = this.pget(dx, dy);
      this.pset(dx, dy, this.nearestColor(max(this.palette[_c * 3 + 0],
          src.palette[c * 3 + 0]), max(this.palette[_c * 3 + 1],
          src.palette[c * 3 + 1]), max(this.palette[_c * 3 + 2], src.palette[c * 3 + 2])));
      break;
    default:
    }
  }

  /** 
    copy pixels from another pixmap
  */
  void copyRectFrom(Pixmap src, int sx, int sy, int dx, int dy, uint w, uint h,
      float scalex = 1, float scaley = 1)
  {
    if (dx < 0)
    {
      sx = cast(int)(sx - dx * scalex);
      dx *= -1;
      if (w > dx)
        w -= dx;
      else
        w = 0;
      dx = 0;
    }
    if (dy < 0)
    {
      sy = cast(int)(sy - dy * scaley);
      dy *= -1;
      if (h > dy)
        h -= dy;
      else
        h = 0;
      dy = 0;
    }
    if (dx + w > this.width)
    {
      if (dx < this.width)
        w = this.width - dx;
      else
        w = 0;
    }
    if (dy + h > this.height)
    {
      if (dy < this.height)
        h = this.height - dy;
      else
        h = 0;
    }
    for (uint y = 0; y < h; y++)
    {
      for (uint x = 0; x < w; x++)
      {
        this.copyPixFrom(src, cast(uint)(sx + x * scalex), cast(uint)(sy + y * scaley),
            dx + x, dy + y);
      }
    }
  }

  /** 
    copy a triangle of pixels from another pixmap
  */
  void copyTriFrom(Pixmap src, double sx1, double sy1, double sx2, double sy2,
      double sx3, double sy3, double dx1, double dy1, double dx2, double dy2, double dx3, double dy3)
  {
    double swp;
    if (dy1 > dy2)
    {
      swp = dx1;
      dx1 = dx2;
      dx2 = swp;
      swp = dy1;
      dy1 = dy2;
      dy2 = swp;
      swp = sx1;
      sx1 = sx2;
      sx2 = swp;
      swp = sy1;
      sy1 = sy2;
      sy2 = swp;
    }
    if (dy1 > dy3)
    {
      swp = dx1;
      dx1 = dx3;
      dx3 = swp;
      swp = dy1;
      dy1 = dy3;
      dy3 = swp;
      swp = sx1;
      sx1 = sx3;
      sx3 = swp;
      swp = sy1;
      sy1 = sy3;
      sy3 = swp;
    }
    if (dy2 > dy3)
    {
      swp = dx2;
      dx2 = dx3;
      dx3 = swp;
      swp = dy2;
      dy2 = dy3;
      dy3 = swp;
      swp = sx2;
      sx2 = sx3;
      sx3 = swp;
      swp = sy2;
      sy2 = sy3;
      sy3 = swp;
    }
    for (double _dy = dy1; _dy < dy2; _dy++)
    {
      double _dx1 = round(this.interpolate(dy1, dy2, _dy, dx1, dx2));
      double _sx1 = round(this.interpolate(dy1, dy2, _dy, sx1, sx2));
      double _sy1 = round(this.interpolate(dy1, dy2, _dy, sy1, sy2));
      double _dx2 = round(this.interpolate(dy1, dy3, _dy, dx1, dx3));
      double _sx2 = round(this.interpolate(dy1, dy3, _dy, sx1, sx3));
      double _sy2 = round(this.interpolate(dy1, dy3, _dy, sy1, sy3));
      if (_dx1 > _dx2)
      {
        swp = _dx1;
        _dx1 = _dx2;
        _dx2 = swp;
        swp = _sx1;
        _sx1 = _sx2;
        _sx2 = swp;
        swp = _sy1;
        _sy1 = _sy2;
        _sy2 = swp;
      }
      for (double _dx = _dx1; _dx <= _dx2; _dx++)
      {
        double _sx = round(this.interpolate(_dx1, _dx2, _dx, _sx1, _sx2));
        double _sy = round(this.interpolate(_dx1, _dx2, _dx, _sy1, _sy2));
        this.copyPixFrom(src, cast(uint)(_sx), cast(uint)(_sy), cast(uint) _dx, cast(uint) _dy);
      }
    }
    for (double _dy = dy2; _dy <= dy3; _dy++)
    {
      double _dx1 = round(this.interpolate(dy2, dy3, _dy, dx2, dx3));
      double _sx1 = round(this.interpolate(dy2, dy3, _dy, sx2, sx3));
      double _sy1 = round(this.interpolate(dy2, dy3, _dy, sy2, sy3));
      double _dx2 = round(this.interpolate(dy1, dy3, _dy, dx1, dx3));
      double _sx2 = round(this.interpolate(dy1, dy3, _dy, sx1, sx3));
      double _sy2 = round(this.interpolate(dy1, dy3, _dy, sy1, sy3));
      if (_dx1 > _dx2)
      {
        swp = _dx1;
        _dx1 = _dx2;
        _dx2 = swp;
        swp = _sx1;
        _sx1 = _sx2;
        _sx2 = swp;
        swp = _sy1;
        _sy1 = _sy2;
        _sy2 = swp;
      }
      for (double _dx = _dx1; _dx <= _dx2; _dx++)
      {
        double _sx = round(this.interpolate(_dx1, _dx2, _dx, _sx1, _sx2));
        double _sy = round(this.interpolate(_dx1, _dx2, _dx, _sy1, _sy2));
        this.copyPixFrom(src, cast(uint)(_sx), cast(uint)(_sy), cast(uint) _dx, cast(uint) _dy);
      }
    }
  }

  /**
    copy palette from another pixmap 
  */
  void copyPaletteFrom(Pixmap src)
  {
    uint c = cast(uint) src.palette.length / 3;
    while (c--)
      this.setColor(c, src.palette[c * 3 + 0], src.palette[c * 3 + 1], src.palette[c * 3 + 2]);
    this.setBGColor(src.bgColor);
    this.setFGColor(src.fgColor);
  }

  /**
    draw text on the pixmap
  */
  uint[2] text(string _text, Pixmap[] font, int x, int y)
  {
    if (font.length == 0)
      return [0, 0];
    CopyMode oldmode = this.copymode;
    this.copymode = this.textCopymode;
    dstring text = toUTF32(_text);
    int margin = x;
    int width = 0;
    int height = font[0].height;
    uint code;
    Pixmap glyph;
    for (uint i = 0; i < text.length; i++)
    {
      code = cast(uint) text[i];
      if (code == 9)
      {
        x -= margin;
        x = x / 64 * 64 + 64;
        x += margin;
      }
      else if (code == 10)
      {
        x = margin;
        y += font[0].height;
        height += font[0].height;
      }
      else if (code >= 32)
      {
        if ((code - 32) < font.length)
          glyph = font[code - 32];
        else
          code = 128;
        if (glyph && glyph.duration < 10)
          code = 128;
        if ((code - 32) < font.length)
          glyph = font[code - 32];
        else
          glyph = font[font.length - 1];
        this.copyRectFrom(glyph, 0, 0, x, y, glyph.width, glyph.height);
        x += glyph.duration / 10;
      }
      if ((x - margin) > width)
        width = x - margin;
    }
    this.copymode = oldmode;
    return [width, height];
  }

  /**
    create a clone of this pixmap
  */
  Pixmap clone()
  {
    Pixmap pixmap = new Pixmap(this.width, this.height, this.colorBits);
    pixmap.fgColor = this.bgColor;
    pixmap.bar(0, 0, pixmap.width, pixmap.height);
    pixmap.copyPaletteFrom(this);
    pixmap.copyRectFrom(this, 0, 0, 0, 0, pixmap.width, pixmap.height);
    pixmap.fgColor = this.fgColor;
    pixmap.bgColor = this.bgColor;
    pixmap.duration = this.duration;
    return pixmap;
  }

  // --- _privates --- //
  private SDL_Texture* texture;
  private ubyte* texdata;
  private bool textureLocked;
  private ubyte pixelMask;
  private ubyte[4] uicolors;

  private double interpolate(double a1, double a2, double n, double b1, double b2)
  {
    double da = a2 - a1;
    double db = b2 - b1;
    double np = (n - a1) / (da == 0 ? 1 : da);
    return b1 + np * db;
  }

  private void psetTexture(uint x, uint y, ubyte c)
  {
    if (x >= this.width || y >= this.height)
      return;
    const i = y * this.width + x;
    uint dest = i * 4;
    uint src = c * 3 % this.palette.length;
    texdata[dest++] = this.palette[src++];
    texdata[dest++] = this.palette[src++];
    texdata[dest++] = this.palette[src++];
    texdata[dest++] = 255;
  }

  private void findUIcolors()
  {
    int darkest = 1024;
    int lightest = -1;
    int satest = -1;
    uint i = 0;
    for (uint c = 0; c < this.palette.length / 3; c++)
    {
      ubyte r = this.palette[i++];
      ubyte g = this.palette[i++];
      ubyte b = this.palette[i++];
      if (r + g + b < darkest)
      {
        this.uicolors[1] = cast(ubyte) c;
        darkest = r + g + b;
      }
      if (r + g + b > lightest)
      {
        this.uicolors[2] = cast(ubyte) c;
        lightest = r + g + b;
      }
      if (max(r, g, b) - min(r, g, b) > satest)
      {
        this.uicolors[3] = cast(ubyte) c;
        satest = max(r, g, b) - min(r, g, b);
      }
    }
    if (satest == 0)
    {
      int grayest = 1024;
      int gray = (darkest + lightest) / 2;
      i = 0;
      for (uint c = 0; c < this.palette.length / 3; c++)
      {
        ubyte r = this.palette[i++];
        ubyte g = this.palette[i++];
        ubyte b = this.palette[i++];
        if (abs(r + g + b - gray) < grayest)
        {
          this.uicolors[3] = cast(ubyte) c;
          grayest = abs(r + g + b - gray);
        }
      }
    }
    this.uicolors[0] = 1;
  }

  private void defaultPalette(uint colors)
  {
    uint d = 6;
    while ((d * d * d) > colors)
      d--;
    d--;
    if (d == 0)
    {
      this.setColor(3, 10, 10, 10);
      this.setColor(2, 5, 5, 5);
      this.setColor(1, 15, 15, 15);
      this.setColor(0, 0, 0, 0);
    }
    else
    {
      uint i = 0;
      for (uint r = 0; r <= d; r++)
      {
        for (uint g = 0; g <= d; g++)
        {
          for (uint b = 0; b <= d; b++)
          {
            this.setColor(i++, cast(ubyte)(r * 15 / d), cast(ubyte)(g * 15 / d),
                cast(ubyte)(b * 15 / d));
          }
        }
      }
      while (i < colors)
      {
        this.setColor(i, cast(ubyte) i, cast(ubyte) i, cast(ubyte) i);
        i++;
      }
    }
  }
}

/**
  copy modes for the .copyFrom method
*/
enum CopyMode
{
  replace,
  matte,
  color,
  xor,
  min,
  max,
  add,
  matchReplace,
  matchMatte,
  averageColor,
  darkerColor,
  lighterColor,
}
