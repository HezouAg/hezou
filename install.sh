#!/usr/bin/env bash
set -euo pipefail

SITE="${HEZOU_SITE:-https://hezou.app}"
SITE="${SITE%/}"
API="${HEZOU_API:-$SITE/api}"
API="${API%/}"
TARGET="${1:-${HEZOU_TARGET:-claude}}"
LAYERS="background character neck mouth eyes headwear item"

case "$TARGET" in
  claude)
    SKILL_DIR="$HOME/.claude/skills/hezou"
    AGENT_DIR="$HOME/.claude/agents"
    SKILL_REF="~/.claude/skills/hezou"
    CLIENT="Claude Code"
    SAY="/hezou"
    ;;
  codex)
    SKILL_DIR="$HOME/.agents/skills/hezou"
    AGENT_DIR="${CODEX_HOME:-$HOME/.codex}/agents"
    SKILL_REF="~/.agents/skills/hezou"
    CLIENT="Codex"
    SAY='$hezou'
    ;;
  *)
    echo "Unknown target \"$TARGET\": use claude or codex" >&2
    exit 1
    ;;
esac

command -v curl >/dev/null 2>&1 || { echo "HEZOU needs curl" >&2; exit 1; }

fetch() {
  curl -fsSL --retry 2 "$SITE/skill/$1" -o "$2"
  [ -s "$2" ] || { echo "Download of $1 came back empty" >&2; exit 1; }
}

for_target() {
  if [ "$TARGET" = codex ]; then
    sed -e 's|~/.claude/skills/hezou|~/.agents/skills/hezou|g' -e '/^allowed-tools:/d'
  else
    cat
  fi
}

md_to_toml() {
  local name desc body
  name=$(sed -n 's/^name: //p' "$1" | head -1)
  desc=$(sed -n 's/^description: //p' "$1" | head -1 | sed 's/"/\\"/g')
  body=$(awk '/^---$/ { n++; next } n >= 2' "$1")
  printf 'name = "%s"\ndescription = "%s"\nmodel_reasoning_effort = "low"\ndeveloper_instructions = %s\n%s\n%s\n' "$name" "$desc" "'''" "$body" "'''"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/skill/scripts" "$TMP/agents"

fetch "hezou/SKILL.md" "$TMP/SKILL.src.md"
for_target < "$TMP/SKILL.src.md" > "$TMP/skill/SKILL.md"
grep -q '^name: hezou$' "$TMP/skill/SKILL.md" || { echo "SKILL.md looks wrong, nothing installed" >&2; exit 1; }
fetch "hezou/scripts/hezou" "$TMP/skill/scripts/hezou"
bash -n "$TMP/skill/scripts/hezou" || { echo "The hezou command does not parse, nothing installed" >&2; exit 1; }
chmod +x "$TMP/skill/scripts/hezou"
VERSION=$(bash "$TMP/skill/scripts/hezou" version)
for layer in $LAYERS; do
  fetch "agents/hezou-$layer.md" "$TMP/hezou-$layer.src.md"
  grep -q "^name: hezou-$layer$" "$TMP/hezou-$layer.src.md" || { echo "hezou-$layer.md looks wrong, nothing installed" >&2; exit 1; }
  for_target < "$TMP/hezou-$layer.src.md" > "$TMP/hezou-$layer.md"
  if [ "$TARGET" = codex ]; then
    md_to_toml "$TMP/hezou-$layer.md" > "$TMP/agents/hezou-$layer.toml"
  else
    cp "$TMP/hezou-$layer.md" "$TMP/agents/hezou-$layer.md"
  fi
done
echo "$VERSION" > "$TMP/skill/VERSION"

mkdir -p "$(dirname "$SKILL_DIR")" "$AGENT_DIR" "$HOME/.hezou"
chmod 700 "$HOME/.hezou"
rm -rf "$SKILL_DIR.new"
cp -R "$TMP/skill" "$SKILL_DIR.new"
rm -rf "$SKILL_DIR.old"
[ -d "$SKILL_DIR" ] && mv "$SKILL_DIR" "$SKILL_DIR.old"
mv "$SKILL_DIR.new" "$SKILL_DIR"
rm -rf "$SKILL_DIR.old"
for f in "$TMP"/agents/*; do
  cp "$f" "$AGENT_DIR/.$(basename "$f").new"
  mv "$AGENT_DIR/.$(basename "$f").new" "$AGENT_DIR/$(basename "$f")"
done

CONFIG="$HOME/.hezou/config"
(
  umask 077
  { [ -f "$CONFIG" ] && grep -v -e '^api=' -e '^site=' "$CONFIG" || true; printf 'api=%s\nsite=%s\n' "$API" "$SITE"; } > "$CONFIG.tmp"
  mv "$CONFIG.tmp" "$CONFIG"
)

CLI="$SKILL_REF/scripts/hezou"
echo "HEZOU $VERSION installed for $CLIENT:"
echo "  conductor skill  $SKILL_REF/SKILL.md"
if [ "$TARGET" = codex ]; then
  echo "  7 layer agents   ${AGENT_DIR/#$HOME/~}/hezou-*.toml"
else
  echo "  7 layer agents   ${AGENT_DIR/#$HOME/~}/hezou-*.md"
fi
echo "  command          $CLI   (bash and curl only)"
echo
if "$SKILL_DIR/scripts/hezou" doctor; then READY=1; else READY=0; fi
STAGE=$(curl -fsS --max-time 10 "$API/stats" 2>/dev/null | grep -o '"stage":"[a-z_]*"' | head -1 | cut -d'"' -f4 || true)
echo
if [ "$READY" != 1 ]; then
  echo "Installed, but the checks above need attention. Fix the FAIL lines, then run: $CLI doctor"
  exit 0
fi
case "$STAGE" in
  open) NEXT="Minting is open: do what the user asked, or ask what the crew should hunt." ;;
  paused) NEXT="Minting is paused: explain the game, or say when it resumes if the user asks." ;;
  sold_out) NEXT="The collection is sold out: explain the game if the user asks." ;;
  *) NEXT="Minting is not open yet: explain the game or check the crew is ready (\"prepare\"); nothing is hunted before the opening." ;;
esac
echo "For the AI agent that ran this installer: read $SKILL_REF/SKILL.md now and follow it in this same chat, no restart needed. $NEXT"
echo "For you: in later chats say \"$SAY\" and what you want, for example: $SAY hunt me something rare"
if [ "$TARGET" = codex ]; then
  echo "Codex runs commands in a sandbox without network by default: allow network access for $CLI when Codex asks."
fi
