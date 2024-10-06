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

  charmap = import ./charmap.nix;
  chars = builtins.listToAttrs (builtins.genList (a: { name = builtins.substring a 1 charmap; value = a + 1; }) 255);

in { inherit uucharset uuencode chars; }
