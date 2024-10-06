let
  inherit (import ./util.nix) chars;
  inherit (import ./placeholder-length.nix) getPlaceholderLength;

  filepath = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
  # 255 bytes!
  padding = "                                                                                                                                                                                                                                                               ";

  # 517 bytes!
  padding517 = "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     ";

  sumBytes = buf:
    builtins.foldl' (a: b: a + chars.${b}) 0 (builtins.filter (a: builtins.isString a && a != "") (builtins.split "" buf));

  makeOctal = n:
    if n < 8 then (builtins.substring n 1 "01234567")
    else
      (makeOctal (n / 8)) + (builtins.substring (builtins.bitAnd n 7) 1 "01234567");

  padToLength = buf: val:
    (builtins.substring 0 ((builtins.stringLength buf) - (builtins.stringLength val)) buf) + val;

  makePaxExtendedHeader = name: value: let
    kvLength = (builtins.stringLength name) + (getPlaceholderLength value) + 3;
    lengthLength = (builtins.stringLength (builtins.toString kvLength));
    properLength = if lengthLength == (builtins.stringLength (builtins.toString (lengthLength + kvLength))) then (kvLength + lengthLength) else (kvLength + lengthLength + 1);
    in "${builtins.toString properLength} ${name}=${value}\n";

  makeHeader = { size, mode ? 438, ftype ? "0" }: let
    path = filepath;
    filemode = padToLength "00000000" (makeOctal mode);
    owner_uid = "00000000";
    owner_gid = "00000000";
    filesize = padToLength "000000000000" (makeOctal size);
    mtime = "000000000000";
    filetype = ftype;
    linkpath = filepath;
    _padding = padding; # checksum: 8160

    _checksum = 8160 + 256 + (sumBytes (path + filemode + owner_uid + owner_gid + filesize + mtime + filetype + linkpath));
    checksum = padToLength "00000000" (makeOctal _checksum);

  in path + filemode + owner_uid + owner_gid + filesize + mtime + checksum + filetype + linkpath + padding;

  writev7PaxHeader = contents: let
    actualLength = (getPlaceholderLength contents);
    _paddingSize = 512 - (builtins.bitAnd 511 actualLength);
    paddingSize = if _paddingSize == 512 then 0 else (if _paddingSize < 5 then (512 + _paddingSize) else _paddingSize);
    paddingPrefix = "${builtins.toString paddingSize} a=";
    padding = (builtins.substring 0 (paddingSize - (builtins.stringLength paddingPrefix) - 1) padding517) + "\n";
  in (makeHeader { size = actualLength + paddingSize; mode = 0; ftype = "x"; }) + contents + (if paddingSize == 0 then "" else (paddingPrefix + padding));

  dir = name: let
    paxHeader = writev7PaxHeader (makePaxExtendedHeader "path" name);
    header = makeHeader { size = 0; mode = 511; ftype = "5"; };
  in paxHeader + header;

  file = name: exec: contents: let
    paxHeader = writev7PaxHeader (makePaxExtendedHeader "path" name);
    len = getPlaceholderLength contents;
    header = makeHeader { size = len; mode = if exec then 511 else 438; ftype = "0"; };

    paddingLen = 512 - (builtins.bitAnd 511 len);
    paddingBytes = if paddingLen == 0 then "" else builtins.substring 0 paddingLen padding517;
  in paxHeader + header + contents + paddingBytes;

  symlink = name: target: let
    paxHeader = writev7PaxHeader ((makePaxExtendedHeader "path" name) + (makePaxExtendedHeader "linkpath" target));
    header = makeHeader { size = 0; mode = 511; ftype = "2"; };
  in paxHeader + header;

  makeTar = builtins.concatStringsSep "";
in { inherit dir file symlink makeTar; }
