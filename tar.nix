let
  uucharset = "`!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_";

  _uuencode = bytes: offset: l: let
    lengthBytes = builtins.substring l 1 uucharset;
    chunks = builtins.genList (i: let
      chunk = builtins.genList (j: if (i * 3 + j) < l then (builtins.elemAt bytes (offset + i * 3 + j)) else 0) 3;
      rechunked = 
          (builtins.substring ((builtins.elemAt chunk 0) / 4) 1 uucharset)
        + (builtins.substring (((builtins.bitAnd (builtins.elemAt chunk 0) 3) * 16) + (builtins.elemAt chunk 1) / 16) 1 uucharset)
        + (builtins.substring (((builtins.bitAnd (builtins.elemAt chunk 1) 15) * 4) + (builtins.elemAt chunk 2) / 64) 1 uucharset)
        + (builtins.substring (builtins.bitAnd (builtins.elemAt chunk 2) 63) 1 uucharset);
      in rechunked) ((l + 2) / 3);
    in lengthBytes + (builtins.concatStringsSep "" chunks) + "\n";

  uuencode = bytes: let
   _tick = offset: if (offset + 45) < (builtins.length bytes) then
     (_uuencode bytes offset 45) + _tick (offset + 45)
     else _uuencode bytes offset ((builtins.length bytes) - offset);
  in _tick 0;

  ustarHeaderSum = 1905;

  makeOctal = n:
    if n < 8 then [ (48 + n) ]
    else
      (makeOctal (n / 8)) ++ [ (48 + (builtins.bitAnd n 7)) ];

  makeUstarHeader = mode: size: type: let
    _modeOctal = (makeOctal mode) ++ [32 32 32 32 32 32 32 32];
    modeOctal = (builtins.genList (builtins.elemAt _modeOctal) 8);
    _sizeOctal = (makeOctal size) ++ [32 32 32 32 32 32 32 32 32 32 32 32];
    sizeOctal = (builtins.genList (builtins.elemAt _sizeOctal) 12);

    modeLine = uuencode modeOctal;
    sizeLine = uuencode sizeOctal;

    newChecksum = (makeOctal (ustarHeaderSum + (builtins.foldl' (a: b: a + b) type (modeOctal ++ sizeOctal)))) ++ [32 32 32 32 32 32 32 32];
    newChecksumLine = uuencode ((builtins.genList (builtins.elemAt newChecksum) 8) ++ [ type ]);
  in builtins.concatStringsSep "" [
    "M80``````````````````````````````````````````````````````````\n"
    "M````````````````````````````````````````````````````````````\n"
    "*````````````````\n" #
    modeLine
    "0`\"`@(\"`@(\"``(\"`@(\"`@(```\n"
    sizeLine
    ", \"`@(\"`@(\"`@(\"`@\n"
    newChecksumLine
    "M80``````````````````````````````````````````````````````````\n"
    "M````````````````````````````````````````````````````````````\n"
    "M`````````````'5S=&%R`#`P````````````````````````````````````\n"
    "M````````````````````````````````````````````````````````````\n"
    "M````````````````````````````````````````````````````````````\n"
    "M````````````````````````````````````````````````````````````\n"
    "M````````````````````````````````````````````````````````````\n"
    "H````````````````````````````````````````````````````````\n"
  ];

  makePaxExtendedHeader = name: value: let
    kvLength = (builtins.stringLength name) + (builtins.stringLength value) + 3;
    lengthLength = (builtins.stringLength (builtins.toString kvLength));
    properLength = if lengthLength == (builtins.stringLength (builtins.toString (lengthLength + kvLength))) then (kvLength + lengthLength) else (kvLength + lengthLength + 1);
    in "${builtins.toString properLength} ${name}=${value}\n";

  pad = count:
    if count > 45 then "M````````````````````````````````````````````````````````````\n" + (pad (count - 45))
    else (builtins.substring count 1 uucharset) + (builtins.substring 0 (((count + 2) / 3) * 4) "````````````````````````````````````````````````````````````") + "\n";

  fileWithContents = mode: type: str: let
    ctx = if builtins.isString str then (builtins.substring 0 0 str) else "";
    size = if builtins.isString str then (builtins.stringLength str) else (builtins.length str);
    header = makeUstarHeader mode size type;
    contents = if builtins.isString str then (builtins.genList (a: chars.${builtins.substring a 1 str}) size) else str;
    padCount = 512 - (builtins.bitAnd size 511);
    padding = if padCount == 512 then "" else pad padCount;
  in ctx + header + uuencode contents + padding;

  /** Create a tar entry for a directory. */
  dir = name:
    (fileWithContents 0 120 (makePaxExtendedHeader "path" name)) +
    (makeUstarHeader 511 0 53);

  /** Create a tar entry for a file. Contents may be either string or an array of bytes. */
  file = name: exec: contents:
    (fileWithContents 0 120 (makePaxExtendedHeader "path" name)) +
    (fileWithContents (if exec then 511 else 438) 48 contents);

  /** Create a tar entry for a symlink. */
  symlink = name: target:
    (fileWithContents 0 120 ((makePaxExtendedHeader "path" name) + (makePaxExtendedHeader "linkpath" target))) +
    (makeUstarHeader 511 0 50);

  /** Create a tarball from a list of entries and return its string contents. */
  makeTar = contents: "begin 666 -\n" + (builtins.concatStringsSep "" contents) + "`\nend\n";

  charmap = import ./charmap.nix;
  chars = builtins.listToAttrs (builtins.genList (a: { name = builtins.substring a 1 charmap; value = a + 1; }) 255);

in { inherit dir file symlink makeTar; }
