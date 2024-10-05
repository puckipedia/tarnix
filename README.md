Ever wish your life was more full of tarballs? *Especially* in your Nix
store? We have the solution for you! Introducing, tarnix!

Tarnix is the only solution to the problem, and works on the most
modern versions of both Lix *and* Nix! No more fussing about with
input-addressed `builtin:fetchurl` being patched, this solution _will_
stand the test of time.

..Okay, but like. This exists because of a lack of a primitive in Nix,
and this is a terrifying workaround for it:

Text paths that reference non-text paths.

```
nix-repl> builtins.toFile "test" "hi ${pkgs.hello}"
error:
       … while calling the 'toFile' builtin
         at «string»:1:1:
            1| builtins.toFile "test" "hi ${pkgs.hello}"
             | ^

       error: files created by builtins.toFile may not reference derivations, but test references !out!af3rc6phyv80h7aq4y3d08awnq2ja8fp-hello-2.12.1.drv
```

To fix this, nixpkgs has `writeTextFile`. But this is a massive hammer,
and I don't want to use nixpkgs when not necessary. So, instead, I
decided to grab that massive hammer and point it directly at Nix
itself.

After a while, we figured out a solution that was reasonable, but had
its limits: Generating a NAR file, and then using an input-addressed
`builtin:fetchurl` derivation. However, this was broken unceremoniously
by CppNix, due to an apparent "vulnerability", which was actually a bug
in the Nix sandbox on macOS, which (at the time of writing) still has
not been fixed, after the Nix team was made aware of it in _February_.

In my search for a modern alternative, I found out about
`builtin:unpack-channel`. It uses libarchive to unpack archives at
build time, which means it can reference the outputs of derivations!

So, what one can do, is ....

```
nix-repl> :b let tar = builtins.toFile "a" (lib.makeTar [(lib.dir "meow") (lib.file "meow/uwu" false "hi!\n")]);
          in derivation { name = "a"; system = "a"; builder = "builtin:unpack-channel"; src = "${tar}"; channelName = "meow"; }

This derivation produced the following outputs:
  out -> /nix/store/vpx98lid40kd4k18ksrpzcqsvdblhdhk-a

puckipedia@marisa ~/tarnix> cat /nix/store/vpx98lid40kd4k18ksrpzcqsvdblhdhk-a/meow/uwu
hi!
```

..now, this isn't the full extent of our crimes (a good ~~magician~~
witch keeps some spare tricks up her sleeves~), but they're out there :3
