# zcreative - toys for creating stuff in zig with visuals and audio

## TODOs

- [X] Get nanovg up a running within zig
- [ ] Work how sub libraries work in zig
- [ ] Add basic audio support

## Notes

I needed to have glad.[c/h] as source in here for nanovg-zig
to work. This was needed so nanovg can create a GL context and 
create a window. This had to be added to ```build.zig``` and so on.

## License

Licensed under any of

    Apache License, Version 2.0 (LICENSE-APACHE or http://www.apache.org/licenses/LICENSE-2.0)
    MIT license (LICENSE-MIT or http://opensource.org/licenses/MIT)
    Mozilla Public License 2.0
