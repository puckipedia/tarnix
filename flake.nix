{
  description = "Generate tarballs directly from Nix.";

  outputs = { self }: rec {
    lib = let ustar = import ./ustar.nix; v7 = import ./v7.nix; unpack = import ./unpack.nix; in { inherit ustar v7; } // ustar // unpack;
    checks.x86_64-linux.unpack-tar = derivation {
      name = "test";
      system = "builtin";
      builder = "builtin:unpack-channel";
      src = ''${builtins.toFile "test" (lib.makeTar [(lib.dir "meow") (lib.file "meow/uwu" false "hi!\n")])}'';
      channelName = "meow";
    };
  };
}
