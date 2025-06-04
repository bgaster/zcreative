# zcreative - toys for creating stuff in zig with visuals and audio

This repo is a playground for me to learn zig.

## TODOs

- [X] Get nanovg up a running within zig
- [X] SDL OpenGL support
  - [X] Abstract so SDL Backend can be replaced
- [X] Add window struct, that manages window
- [ ] Support for selecting multiple objects
- [ ] Dragging selected objects
- [ ] Extend canvas to virtual size, with scroll bars
- [X] PD to JSON command line tool
- [ ] PD JSON to Ziggy tool
- [ ] Load Ziggy PD patches
- [ ] Toolbar support for loading files, burger menu, tools for switching between edit and run modes
- [ ] Compile Visual editor patches to execution graph
- [X] Add application struct, manages whole application
- [ ] Work how sub libraries work in zig
- [ ] Add basic audio support

## Setup

The following need to be installed and on your terminal's path.

- Zig compiler installed
- SDL2 libraries installed
- node installed
- jq installed

In ```extras``` run:

```bash
npm install
```

## PD patches 2 JSON 2 Ziggy

```bash
./extras/pd2json.sh <path-2-file>/some-pd-file.pd
```

## Notes

I needed to have glad.[c/h] as source in here for nanovg-zig
to work. This was needed so nanovg can create a GL context and 
create a window. This had to be added to ```build.zig``` and so on.

## License

Licensed under any of

    Apache License, Version 2.0 (LICENSE-APACHE or http://www.apache.org/licenses/LICENSE-2.0)
    MIT license (LICENSE-MIT or http://opensource.org/licenses/MIT)
    Mozilla Public License 2.0
