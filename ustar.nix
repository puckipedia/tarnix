let
  inherit (import ./util.nix) uucharset uuencode chars;

  ustarHeaderSum = 1905;

  makeOctalArray = n:
    if n < 8 then [ (48 + n) ]
    else
      (makeOctalArray (n / 8)) ++ [ (48 + (builtins.bitAnd n 7)) ];

  makeUstarHeader = mode: size: type: let
    _modeOctal = (makeOctalArray mode) ++ [32 32 32 32 32 32 32 32];
    modeOctal = (builtins.genList (builtins.elemAt _modeOctal) 8);
    _sizeOctal = (makeOctalArray size) ++ [32 32 32 32 32 32 32 32 32 32 32 32];
    sizeOctal = (builtins.genList (builtins.elemAt _sizeOctal) 12);

    modeLine = uuencode modeOctal;
    sizeLine = uuencode sizeOctal;

    newChecksum = (makeOctalArray (ustarHeaderSum + (builtins.foldl' (a: b: a + b) type (modeOctal ++ sizeOctal)))) ++ [32 32 32 32 32 32 32 32];
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


in { inherit dir file symlink makeTar; }
