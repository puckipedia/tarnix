let
  createUpstreamPlaceholder = import ./ca-placeholder.nix;

  derivationOutputs =
    ctx: builtins.listToAttrs
           (builtins.concatLists
             (map
               (a: map (createUpstreamPlaceholder a) ctx.${a}.outputs)
               (builtins.filter (a: ctx.${a} ? outputs) (builtins.attrNames ctx))));

  getPlaceholderLength = txt: let
    ctx = builtins.getContext txt;
    outputs = derivationOutputs ctx;
    regex = "(" + (builtins.concatStringsSep "|" (builtins.attrNames outputs)) + ")";
    splot = builtins.split regex txt;
  in if regex == "()" then builtins.stringLength txt else (builtins.foldl' (a: b: a + (if builtins.isList b then outputs.${builtins.head b} else builtins.stringLength b)) 0 splot);
in
  { inherit getPlaceholderLength; }
