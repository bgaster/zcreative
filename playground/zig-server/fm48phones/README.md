# FM for 8 Phones

This is part of a performance piece called FM for 8 Phones, which is an audio compostion desiged for a 16 channel multi-channel 
speaker system. It is designed for 8 listeners who are perceived as also as entangled performers. Each listener is invited
to connect to a shared network of control for the performance, where they control the gain, frequency cutoff and Q for a low pass resonance
filter for 2 randomly allocated speakers in the array. During the performance actors are free to wonder around the space 
interact with other actors, play with their controls, or simply listen and watch the space.

The music itself is based on John Chowning's composition Stria, using 16 instances of a simple FM synth running concurrently and outputing
to the one of the 16 speakers in the array. Rather than related and overlapping partials merging in the digital domain, mixing the poly 
instrument into a stereo mix, each sound is output into the physical relm and mixed in the space itself. Like the orignal piece 
frequency ratios and spectral structures are at the core of the composition and, like Chowning's original, the Maxmsp patch uses 
the golden ratio to modulate the carrier.

Technically, other than the maxmsp patch, the system is an example of our vision of a networked control system, descibed in our work 
anywhere and here, it uses a centralized server, which supports *webosc*, built using [zcreative*](https://zcreative.org), a 
[Zig](https://ziglang.org/) based toolkit for centralized networked music colaboration. Each actor (listener) connects 
to a shared network and opens the FM for 8 phones webapp that provides 
real time control of the 6 parameters they will control, mapped over two speakers within the performance.

## LICENSE

Licensed under any of

    Apache License, Version 2.0 (LICENSE-APACHE or http://www.apache.org/licenses/LICENSE-2.0)
    MIT license (LICENSE-MIT or http://opensource.org/licenses/MIT)
    Mozilla Public License 2.0

at your option.

Dual MIT/Apache2 is strictly more permissive.

