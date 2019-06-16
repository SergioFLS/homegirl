module soundchip;

import core.stdc.stdlib;
import std.math;
import std.string;
import bindbc.sdl;

import sample;

/**
  Sound chip simulator
*/
class SoundChip
{
  uint lastTick = 0; /// last time audio was updated
  Sample[4] src; /// sample for each channel
  double[4] head; /// playhead for each channel
  double[4] loopStart; /// loop start for each channel
  double[4] loopEnd; /// loop end for each channel
  double[4] rate; /// playback rate for each channel
  double[4] volume; /// volume for each channel

  /**
    create a SoundChip
  */
  this()
  {
    this.initDevice();
    this.clear();
  }

  /**
    main loop
  */
  void step(uint t)
  {
    t *= this.spec.freq / 1000;
    if (this.lastTick > t || this.lastTick == 0)
      this.lastTick = t;
    if (t - this.lastTick > this.buffer_len)
      this.resizeBuffer(t - this.lastTick);
    uint p = 0;
    while (this.lastTick < t)
    {
      for (uint i = 0; i < this.src.length; i++)
      {
        this.value[i] = 0;
        if (this.rate[i])
        {
          uint pos = cast(int) trunc(this.head[i]);
          if (this.src[i] && pos < this.src[i].data.length)
            this.value[i] = 1.0 * this.src[i].data[pos] / 128 * this.volume[i];
          else
            this.rate[i] = 0;
          this.head[i] += this.rate[i];
          if (this.rate[i] > 0 && this.head[i] >= this.loopEnd[i])
            this.head[i] -= this.loopEnd[i] - this.loopStart[i];
          if (this.rate[i] < 0 && this.head[i] < this.loopStart[i])
            this.head[i] += this.loopEnd[i] - this.loopStart[i];
        }
        else
          this.rate[i] = 0;
      }
      this.buffer[p++] = this.value[0] + this.value[1] - this.value[0] * this.value[1];
      this.buffer[p++] = this.value[2] + this.value[3] - this.value[2] * this.value[3];
      this.lastTick++;
    }
    SDL_QueueAudio(this.dev, this.buffer, cast(uint)(p * float.sizeof));
    SDL_PauseAudioDevice(this.dev, 0);
  }

  /**
    play sample
  */
  void play(uint channel, Sample sample)
  {
    channel = channel % this.src.length;
    this.src[channel] = sample;
    this.head[channel] = 0;
    this.setLoop(channel, this.src[channel].loopStart, this.src[channel].loopEnd);
    this.setFreq(channel, sample.freq);
    this.setVolume(channel, 63);
  }

  /**
    set samplerate on channel
  */
  void setFreq(uint channel, int freq)
  {
    channel = channel % this.src.length;
    while (freq > 28_867)
      freq /= 2;

    this.rate[channel] = 1.0 * freq / this.spec.freq;
  }

  /**
    set volume on channel
  */
  void setVolume(uint channel, ubyte vol)
  {
    channel = channel % this.src.length;
    if (vol > 63)
      vol = 63;
    this.volume[channel] = 1.0 * vol / 63;
  }

  /**
    set loop on channel
  */
  void setLoop(uint channel, uint start, uint end)
  {
    channel = channel % this.src.length;
    this.loopStart[channel] = start;
    this.loopEnd[channel] = end;
  }

  /**
    reset all channels
  */
  void clear()
  {
    for (uint i = 0; i < this.src.length; i++)
    {
      this.src[i] = null;
      this.head[i] = 0;
      this.loopStart[i] = 0;
      this.loopEnd[i] = 0;
      this.rate[i] = 0;
      this.volume[i] = 1;
    }
    this.sync();
  }

  /**
    reset audio buffer
  */
  void sync()
  {
    SDL_ClearQueuedAudio(this.dev);
    this.buffer_len = 0;
    this.lastTick = 0;
  }

  // --- _privates --- //
  private SDL_AudioSpec* spec = new SDL_AudioSpec();
  private SDL_AudioDeviceID dev;
  private float* buffer;
  private uint buffer_len;
  private float[4] value;

  private void initDevice()
  {
    this.spec.freq = 48_000;
    this.spec.format = AUDIO_F32SYS;
    this.spec.channels = 2;
    this.dev = SDL_OpenAudioDevice(null, 0, this.spec, null, 0);
  }

  private void resizeBuffer(uint samples)
  {
    free(this.buffer);
    this.buffer_len = samples;
    this.buffer = cast(float*) malloc(this.buffer_len * this.spec.channels * float.sizeof);
  }
}
