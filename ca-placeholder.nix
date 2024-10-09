with builtins; let
  nibbles = "0123456789abcdef";
  nibbleMap = builtins.listToAttrs (builtins.genList (a: { name = builtins.substring a 1 nibbles; value = a; }) 16);
  hexToDecimal = hex: assert ((stringLength hex) / 2) * 2 == (stringLength hex);
    let
      byte = w: nibbleMap.${substring 0 1 w} * 16 + nibbleMap.${substring 1 1 w};
    in
      genList (a: byte (substring (a * 2) 2 hex)) ((stringLength hex) / 2);

  shiftLeft = i: value: if i == 0 then value else (shiftLeft (i - 1) (value * 2));
  shiftRight = i: value: if i == 0 then value else (shiftRight (i - 1) (value / 2));

  decimalToBase32 = val: let
    decimalToBase32Byte = i: let
      offsetBits = i * 5;
      byteIndex = (offsetBits / 8);
      offset = offsetBits - (byteIndex * 8);
      firstByte = shiftRight offset (elemAt val byteIndex);
      secondByte = shiftLeft (8 - offset)
        (if byteIndex >= (length val) - 1 then 0 else (elemAt val (byteIndex + 1)));
      value = bitAnd 31 (bitOr firstByte secondByte);
    in substring value 1 "0123456789abcdfghijklmnpqrsvwxyz";
    len = ((length val) * 8 - 1) / 5 + 1;
    chars = genList (a: decimalToBase32Byte (len - 1 - a)) len;
  in concatStringsSep "" chars;
in
  drvPath: outputName:
    let
      drvPathHash = builtins.substring ((builtins.stringLength builtins.storeDir) + 1) 32 drvPath;
      drvPathName = builtins.substring ((builtins.stringLength builtins.storeDir) + 34) ((builtins.stringLength drvPath) - (builtins.stringLength builtins.storeDir) - 34 - 4) drvPath;
      outputBit = if outputName == "out" then "" else "-${outputName}";
      hash = builtins.hashString "sha256" "nix-upstream-output:${drvPathHash}:${drvPathName}${outputBit}";
      base32 = decimalToBase32 (hexToDecimal hash);
    in
      { name = "/${base32}"; value = (builtins.stringLength drvPath) - 4 + (builtins.stringLength outputBit); }
