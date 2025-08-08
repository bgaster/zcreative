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
- [ ] PD patch parser library
  - [X] Lexer
  - [ ] Parser
     - [X] Parser failure handling
     - [X] Patch data-structure
     - [X] Basic parsing (support for canvas and subpatch)
     - [X] Obj (msg) and Generic (print, +, etc) support
     - [ ] UI objects (such floatatom, bng), which have additional UI fields
     - [ ] Mop up missing objects and so on
     - [ ] Externals
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

You can use the following to explore PD patches in JSON, but this is not used elsewhere.

```bash
./extras/pd2json.sh <path-2-file>/some-pd-file.pd
```

## GUI Experiments

To explore [SDL2](https://www.libsdl.org/)---should move to SDL3 at somepoint---intergration, along with [NANOVG,](https://github.com/memononen/nanovg) 
The GUI toolkit for what will be come our UX for Interactions<sup>n</sup>, at the moment it has 
moveable widgets, supports mouse and keyboard events, but needs extending to support the actual visual widgets for
**Interactions<sup>n</sup>**.

You can try this out with the following command in the root directory:

```bash
zig build run
```

## PD Parser

Currently I'm working on a simple parser for [Pure Data](https://puredata.info/) patches, which can be 
found in the directory ```pdparse```. It is actually designed as a library, but it can be tested with the command:

```bash
zig build run -- patches/t3.pd
```

At the moment I need to add lots of PD functions (e.g. ```loadbang```), but all these are just extra 
instances of ```obj``` node class, which is fully supported.

## Notes

I needed to have glad.[c/h] as source in here for nanovg-zig
to work. This was needed so nanovg can create a GL context and 
create a window. This had to be added to ```build.zig``` and so on.

## Playground

The folder *playground* is a dumping ground for exploring whatever. 

I'm developing all of this suff on MacOS with the plan to move it to rewritten in zig and run on a Linux server. This means it is
likely to not work on Windows!!

You need to have installed:

```c++
int main() {
  return 0;
}
```


```zig
fn foo() u32 {

}
```

```bash
python3
bun
```

In the directories

```bash
ws-server
app
```

Is a JS webserver that is looking at the notion of colabrative environment for distrabuted control interfaces 
and a centralised audio server. The *ws-server* is a Bun (Nodejs compatiable).

It turns out that js apps that use audioWorklets that are served from a 'remote' host must be via *https*, took me some messing to
discover why my original http server was not working. This additionally means that any websockets accessed by the server must also be 
secure. In the end it makes more sense to be doing it over https and so the main issue that is left is the certificate. To avoid having
to be connected to the internet and so on I've just created local certificate with the command:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout key.pem -out cert.pem
```

Once the system is ported to zig this will be moved to a trusted site to sign the certificate.

To start the *app* just change into *app* folder and run the command:

```bash
./runserver.sh
```

## License

Licensed under any of

    Apache License, Version 2.0 (LICENSE-APACHE or http://www.apache.org/licenses/LICENSE-2.0)
    MIT license (LICENSE-MIT or http://opensource.org/licenses/MIT)
    Mozilla Public License 2.0
