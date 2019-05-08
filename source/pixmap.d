module pixmap;

import std.math;
import bindbc.sdl;

/**
  index-based pixel map
*/
class Pixmap
{
  uint width; /// width of pixel map
  uint height; /// height of pixel map
  ubyte colorBits; /// bits per color
  ubyte fgColor = 1; /// index of foreground color
  ubyte bgColor = 255; /// index of background/transparent color
  ubyte[] pixels; /// all the pixels
  ubyte[] palette; /// the color palette
  SDL_Texture* texture; /// texture representation of pixmap

  /**
    create new pixmap
  */
  this(uint width, uint height, ubyte colorBits)
  {
    this.width = width;
    this.height = height;
    this.colorBits = colorBits;

    uint colors = 1;
    for (ubyte i = 0; i < colorBits; i++)
      colors *= 2;
    this.palette.length = colors * 3;
    for (ubyte i = 0; i < colors; i++)
    {
      this.setColor(i, i, i, i);
    }

    this.pixels.length = this.width * this.height;
    for (uint i = 0; i < this.pixels.length; i++)
    {
      this.pixels[i] = 0;
    }
  }

  /**
    initiate texture representation
  */
  void initTexture(SDL_Renderer* ren)
  {
    this.texture = SDL_CreateTexture(ren, SDL_PIXELFORMAT_BGR888,
        SDL_TEXTUREACCESS_STREAMING, this.width, this.height);
  }

  /**
    refresh all pixels in texture to represent pixmap
  */
  void updateTexture()
  {
    ubyte* texdata = null;
    int pitch;
    SDL_LockTexture(this.texture, null, cast(void**)&texdata, &pitch);
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
    SDL_UnlockTexture(this.texture);
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
    }
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
    this.pixels[i] = c;
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
  void bar(int x, int y, uint width, uint height)
  {
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
    auto dx = x2 - x1;
    auto dy = y2 - y1;
    auto l = fmax(abs(dx), abs(dy));
    for (auto i = 0; i <= l; i++)
    {
      plot(cast(int) round(x1 + dx * (i / l)), cast(int) round(y1 + dy * (i / l)));
    }
  }

  /** 
    copy pixels from another pixmap
  */
  void copyFrom(Pixmap src, int sx, int sy, int dx, int dy, uint w, uint h)
  {
    for (uint y = 0; y < h; y++)
    {
      for (uint x = 0; x < w; x++)
      {
        const c = src.pget(sx + x, sy + y);
        if (c != src.bgColor)
          this.pset(dx + x, dy + y, c);
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
  }

}
