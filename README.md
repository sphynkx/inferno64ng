# Inferno64NG

Inferno64NG is a modernized hosted Inferno build based on the 64-bit Inferno port
([original repository](https://github.com/caerwynj/inferno64), `MinGW` branch).
This fork is adapted for the MSYS2/MinGW environment and also supports modern
Linux builds.

The current focus is the hosted `emu` runtime on `amd64` for:

- Windows via MSYS2/MinGW;
- Linux on `amd64`.


## Main changes and improvements

This build includes a number of system-level fixes and extensions compared to the original 64-bit port:

- Fixed several 64-bit arithmetic and runtime correctness issues.
- Improved hosted console support for both Windows/MSYS2 and Linux.
- Added ANSI/VT-style terminal control support for console applications.
- Added terminal capability reporting through `/dev/consinfo`, including geometry,
  color, truecolor, UTF-8 and backend/source information where available.
- Added enhanced console input devices:
  - `/dev/ekeyboard` for Unicode-aware keyboard input and special key handling;
  - `/dev/emouse` for console mouse input.
- Added unified console input dispatching for keyboard and mouse events, with
  platform-specific backends for Windows/MSYS2 and Linux.
- Improved raw console input lifecycle handling, including clean shutdown of
  blocked keyboard and mouse readers.
- Added support for building console TUI applications through the
  [`icurses`](https://github.com/sphynkx/icurses) framework.
- Added an extended shell, `esh`.
- Implemented `icurses` - ncurses like TUI framework.
- Implemented `ic` - icurses based file manager inspired by Midnight Commander.
- Implemented `awk` (True AWK, 1988).
- Implemented archivers: `bzip2`, `cpio`.
- Misc useful utilities and scripts: zcat, bzcat..
- Default screen size for GUI expanded to 1024x768.
- Added various build, packaging and usability improvements, including optional binary size reduction/compression work.


## icurses TUI framework

The `icurses` framework provides a higher-level API for building terminal UI
applications on top of the enhanced console support. It includes:

- terminal capability detection via `/dev/consinfo`;
- keyboard input handling through `/dev/ekeyboard`;
- mouse input handling through `/dev/emouse`;
- ANSI/VT terminal rendering helpers;
- canvas-based drawing;
- windows, frames, shadows and labels;
- buttons, lists, forms, sliders, progress bars, spinners and task dialogs;
- focus handling, key bindings and command/message dispatch;
- example applications, including a Matrix-style terminal animation demo.

The framework is intended to make it practical to write real console applications for Inferno while keeping them portable between the supported Windows/MSYS2 and Linux hosted environments.


## Install and run

### Windows 

Install [MSYS2](https://www.msys2.org/), run its shell and:
```bash
pacman -S mingw-w64-x86_64-gcc
pacman -S upx
pacman -S git
cd /opt
git clone https://github.com/sphynkx/inferno64ng
cd inferno64ng
export MKSH=`which bash`.exe
export ROOT=$(pwd)
export PATH=$PATH:$ROOT/MinGW/amd64/bin/
./makemk.sh
mk mkdirs
mk install
```
Run:
```bash
emu.exe -r. -g1200x600
```


### Linux

```bash
dnf install upx libX11-devel libXext-devel pulseaudio-libs-devel
cd /opt
git clone https://github.com/sphynkx/inferno64ng
cd inferno64ng
```
Modify `mkconfig`: set `SYSHOST` and `SYSTARG` to "Linux". Next:
```bash
export ROOT=$(pwd)
export PATH=$PATH:$ROOT/Linux/amd64/bin/
./makemk.sh
mk mkdirs
mk install
```
Run:
```bash
emu -r. -g1200x600
```


## Bugs
Present.


## TODO
Much of..
