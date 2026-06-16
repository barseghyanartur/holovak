Holovak
=======

.. image:: https://github.com/barseghyanartur/holovak/actions/workflows/test.yml/badge.svg?branch=main
   :target: https://github.com/barseghyanartur/holovak/actions
.. image:: https://img.shields.io/badge/license-MIT-blue.svg
   :target: https://github.com/barseghyanartur/holovak/#licence

A minimal macOS app for trimming video files by specifying keep-segments.
Drop a file, define your time ranges, export. Powered by ``ffmpeg``.

Compatibility
-------------

- macOS Sequoia (15.x)
- macOS Sonoma (14.x)
- macOS Ventura (13.x)

Requirements
------------

``ffmpeg`` must be installed separately::

    brew install ffmpeg

Installation
------------

Build from source
~~~~~~~~~~~~~~~~~

::

    git clone https://github.com/barseghyanartur/holovak.git
    cd holovak
    make build
    make open   # open in Xcode, then ⌘R to run

Release (DMG)
~~~~~~~~~~~~~

Go to `Releases <https://github.com/barseghyanartur/holovak/releases/>`_ and
download the latest ``Holovak.dmg``. Open it and drag ``Holovak`` into
``Applications``.

Usage
-----

1. Drop a video file onto the window (or click **Or click to browse…**).
2. Enter keep-segments as ``HH:MM:SS`` or ``MM:SS`` timecodes.
3. Add more segments with **+ Add segment** as needed.
4. Press **Export** (or **⌘↩**).
5. The output file is saved alongside the original as ``<name>-edited.<ext>``.

License
-------

MIT

Author
------

Artur Barseghyan <artur.barseghyan@gmail.com>
