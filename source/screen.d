module screen;

import viewport;
import pixmap;

/**
  Class representing a screen
*/
class Screen : Viewport
{
  ubyte pixelWidth; /// width of each pixel (1 or 2)
  ubyte pixelHeight; /// height of each pixel (1 or 2)

  /**
    create a new screen
  */
  this(ubyte mode, ubyte colorBits)
  {
    if (mode > 3)
      throw new Exception("Unsupported screen mode!");
    this.pixelWidth = cast(ubyte)(2 - (mode & 1));
    this.pixelHeight = cast(ubyte)(2 - (mode & 2) / 2);
    super(null, 0, 0, 640 / this.pixelWidth, 360 / this.pixelHeight, colorBits);
  }

}
