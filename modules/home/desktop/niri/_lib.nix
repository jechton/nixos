{ lib }:
rec {
  # niri's official home-manager module renders `settings` as raw KDL: repeated
  # sibling nodes (multiple `window-rule { ... }` blocks, `match` lines, etc.)
  # have to go through a `_children` list since a Nix attrset can't hold the
  # same key twice, and node properties go through `_props`. These helpers
  # keep that plumbing out of the files that actually declare config.

  # Wrap a list of `{ <key> = ...; }` node values as KDL children.
  mkNodes = key: items: map (item: { ${key} = item; }) items;

  # `matches = [ { app-id = "..."; } ... ];` -> repeated `match` child nodes.
  mkMatches =
    matchKey: matches:
    lib.optionalAttrs (matches != [ ]) {
      _children = map (m: { ${matchKey}._props = m; }) matches;
    };

  # A window-rule/layer-rule: pulls `matches` out into `match` child nodes and
  # keeps the rest of the attrs (properties) as-is.
  mkRule =
    {
      matches ? [ ],
      ...
    }@rule:
    (mkMatches "match" matches) // (removeAttrs rule [ "matches" ]);

  # Bind helpers: compose a bind's action with optional overlay title/props
  # without spelling out `_props` at every call site.
  mergeProps = bindAttrs: props: bindAttrs // { _props = (bindAttrs._props or { }) // props; };
  withTitle = title: bindAttrs: mergeProps bindAttrs { hotkey-overlay-title = title; };
  hiddenBind = bindAttrs: mergeProps bindAttrs { hotkey-overlay-title = null; };
  withProps = mergeProps;
  noArg = action: { ${action} = { }; };
  withArg = action: value: { ${action} = value; };
  spawn = command: { spawn = command; };
}
