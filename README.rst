=======
Holovak
=======

.. image:: https://github.com/barseghyanartur/holovak/actions/workflows/test.yml/badge.svg?branch=main
   :target: https://github.com/barseghyanartur/holovak/actions
   :alt: Build Status

.. image:: https://img.shields.io/badge/license-MIT-blue.svg
   :target: https://github.com/barseghyanartur/holovak/#License
   :alt: MIT

A minimal macOS desktop application for trimming and joining video files.

Compatibility
=============
- macOS Sequoia (15.x)
- macOS Sonoma (14.x)
- macOS Ventura (13.x)

Requirements
============
``ffmpeg`` must be installed separately::

    brew install ffmpeg

Installation
============
Install using ``brew``
----------------------
*Recommended*

.. code-block:: sh

    brew tap barseghyanartur/holovak-tap
    brew install --cask holovak

Install manually
----------------
Go to `Releases <https://github.com/barseghyanartur/holovak/releases/>`_ and
download the latest ``Holovak.dmg``. Open it and drag ``Holovak`` into
``Applications``.

Build from source
-----------------

::

    git clone https://github.com/barseghyanartur/holovak.git
    cd holovak
    make build
    make open   # open in Xcode, then ⌘R to run

Usage
=====
1. Drop a video file onto the window (or click **Or click to browse…**).
2. Enter keep-segments as ``HH:MM:SS`` or ``MM:SS`` timecodes.
3. Add more segments with **+ Add segment** as needed.
4. Press **Export** (or **⌘↩**).
5. The output file is saved alongside the original as ``<name>-edited.<ext>``.

License
=======
MIT

Support
=======
For security issues contact me at the e-mail given in the `Author`_ section.

For overall issues, go to `GitHub <https://github.com/barseghyanartur/holovak/issues>`_.

Author
======
Artur Barseghyan <artur.barseghyan@gmail.com>
