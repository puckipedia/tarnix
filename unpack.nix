let
  /** Unpack a tarball. Returns a derivation containing one file, "-", being the top level file in the tarball. */
  unpackTarball = { name, src, __contentAddressed ? false }: derivation {
    inherit name __contentAddressed;
    src = ".attr-1s42g1c76fxb77skzq0b4wdhcrg8jmzb54czmxvh1qm7psgsbcni";
    system = "builtin";
    builder = "builtin:unpack-channel";
    channelName = "-";

    contents = src;
    passAsFile = "contents";
  };
in { inherit unpackTarball; }
