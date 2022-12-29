Galaksija FPGA for ZXUno
------------------------

This together with the galaksija branch of ctrl-module (git@github.com:ZXMicroJack/ctrl-module.git), is the source
repo for the ZXUNO release of FPGA.  This is based upon http://galaksija.petnica.rs/, but with some significant improvements,
and reversions back to the original design.

- the original frequency of 3.072MHz.
- the raster chasing composite scan at 50Hz - the Petnica version uses whole frame buffering.  This core delivers the composite
  scan as the old hardware.
- A scan doubler for VGA at 50Hz.
- Tape in / out for loading and saving
- A genlocked menu running as sidecar to the main core - not interrupting its execution offering:
    = selection of memory options (6k, 38k, 54k (minus 16 bytes!))
    = realtime selection of char rom
    = hypertape allowing the reading and writing of GTP tape images to from a Fat16 or Fat32 formatted SDcard
    = load and save to / from SDcard

Standard disclaimer
-------------------

Naturally I can take no responsibility to any existing data that may be trashed on the SDcard so please be warned.  Although
all care has been taken to test this functionality, there may exist a possibility that malfunction takes place corrupting
the data.

License
-------

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


