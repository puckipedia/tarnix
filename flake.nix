{
  description = "Generate tarballs directly from Nix.";

  outputs = { self }: rec {
    lib = import ./tar.nix;
    checks.x86_64-linux.unpack-tar = derivation {
      name = "test";
      system = "builtin";
      builder = "builtin:unpack-channel";
      src = ''${builtins.toFile "test" (lib.makeTar [(lib.dir "meow") (lib.file "meow/uwu" false "hi!\n")])}'';
      channelName = "meow";
    };
  };
}
