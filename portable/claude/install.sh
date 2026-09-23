#!/usr/bin/env bash
# Installs the Claude Code config from modules/home/dev/claude into ~/.claude
# on a machine without Nix (e.g. a Raspberry Pi 5 on Raspberry Pi OS).
# settings.json here mirrors the settings in claude.nix, with Nix store paths
# replaced by commands on PATH. CLAUDE.md, skills, and the statusline are
# copied from the Nix module so there is one source for them.
# Re-run after pulling to update. An existing, different settings.json is
# backed up to settings.json.bak first.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src="$here/../../modules/home/dev/claude"
dest="$HOME/.claude"

mkdir -p "$dest/skills"

if [ -f "$dest/settings.json" ] && ! cmp -s "$here/settings.json" "$dest/settings.json"; then
  cp "$dest/settings.json" "$dest/settings.json.bak"
  echo "Backed up existing settings.json to $dest/settings.json.bak"
fi
cp "$here/settings.json" "$dest/settings.json"

cp "$src/context.md" "$dest/CLAUDE.md"

for skill in "$src"/skills/*.md; do
  name=$(basename "$skill" .md)
  mkdir -p "$dest/skills/$name"
  cp "$skill" "$dest/skills/$name/SKILL.md"
done

# writeShellApplication adds the shebang and strict mode in the Nix build.
{
  printf '#!/usr/bin/env bash\nset -euo pipefail\n'
  cat "$src/statusline.sh"
} >"$dest/claude-statusline"
chmod +x "$dest/claude-statusline"

echo "Installed config to $dest"

# Tools the config calls. Missing ones only disable their feature.
declare -A hints=(
  [claude]="curl -fsSL https://claude.ai/install.sh | bash"
  [git]="sudo apt install git"
  [rtk]="curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh"
  [rg]="sudo apt install ripgrep"
  [pyright-langserver]="npm install -g pyright"
  [typescript-language-server]="npm install -g typescript-language-server typescript"
  [ast-grep]="npm install -g @ast-grep/cli"
  [fastmod]="cargo install fastmod"
  [semgrep]="pipx install semgrep"
)
missing=0
for cmd in claude git rtk rg pyright-langserver typescript-language-server ast-grep fastmod semgrep; do
  if ! command -v "$cmd" >/dev/null; then
    [ "$missing" -eq 0 ] && echo "Missing tools:"
    printf '  %-28s %s\n' "$cmd" "${hints[$cmd]}"
    missing=1
  fi
done
