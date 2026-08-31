#!/bin/sh

# Sets up Claude Code: own config from this repo, everything third-party from source.
# Idempotent - safe to re-run after every change to the tracked files.

set -e

# fresh.sh runs this before the shell is reloaded, so the two bin dirs the
# installed tools live in are not on PATH yet.
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"

CLAUDE_SRC="$HOME/.dotfiles/claude"
CLAUDE_HOME="$HOME/.claude"

echo "Setting up Claude Code..."

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

if test ! -x "$HOME/.local/bin/claude"; then
  echo "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

echo "Installing ccs (Claude Code Switcher)"
pnpm add -g @kaitranntt/ccs

echo "Installing plannotator"
curl -fsSL https://plannotator.ai/install.sh | bash

echo "Installing codebase-memory-mcp"
curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash

# ---------------------------------------------------------------------------
# Own config
# ---------------------------------------------------------------------------

echo "Copying own config into $CLAUDE_HOME"
mkdir -p "$CLAUDE_HOME/hooks" "$CLAUDE_HOME/skills" "$CLAUDE_HOME/workflows"

cp "$CLAUDE_SRC/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md"
cp "$CLAUDE_SRC/settings.json" "$CLAUDE_HOME/settings.json"
cp "$CLAUDE_SRC"/hooks/* "$CLAUDE_HOME/hooks/"
cp -R "$CLAUDE_SRC"/skills/* "$CLAUDE_HOME/skills/"
cp "$CLAUDE_SRC"/workflows/* "$CLAUDE_HOME/workflows/"

chmod +x "$CLAUDE_HOME"/hooks/*

# ---------------------------------------------------------------------------
# Third-party skills - github.com/vercel-labs/skills
# ---------------------------------------------------------------------------

# Unset CLAUDE_CONFIG_DIR: inside a ccs session it points at ~/.ccs/instances/<name>,
# and the skills CLI would then copy skills there instead of linking them from ~/.agents.
echo "Installing third-party skills"
env -u CLAUDE_CONFIG_DIR pnpm dlx skills add vercel-labs/agent-browser --skill agent-browser -g -a claude-code -y
env -u CLAUDE_CONFIG_DIR pnpm dlx skills add blader/humanizer --skill humanizer -g -a claude-code -y
env -u CLAUDE_CONFIG_DIR pnpm dlx skills add wshobson/agents --skill code-review-excellence -g -a claude-code -y
env -u CLAUDE_CONFIG_DIR pnpm dlx skills add softaworks/agent-toolkit --skill writing-clearly-and-concisely -g -a claude-code -y
env -u CLAUDE_CONFIG_DIR pnpm dlx skills add kepano/obsidian-skills \
  --skill obsidian-cli --skill obsidian-markdown --skill obsidian-bases -g -a claude-code -y
# writing-great-skills is gone upstream - writing-for-agents is its successor
env -u CLAUDE_CONFIG_DIR pnpm dlx skills add mattpocock/skills \
  --skill grill-me --skill grill-with-docs --skill resolving-merge-conflicts --skill writing-for-agents \
  -g -a claude-code -y

echo "Downloading the browser used by agent-browser"
agent-browser install

# ---------------------------------------------------------------------------
# Output styles
# ---------------------------------------------------------------------------

echo "Installing the attention-kind output style"
mkdir -p "$CLAUDE_HOME/output-styles"
curl -fsSL -o "$CLAUDE_HOME/output-styles/attention-kind.md" \
  https://raw.githubusercontent.com/alexgreensh/attention-span/main/output-styles/attention-kind.md

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------

echo "Adding plugin marketplaces"
# Claude Code registers the official marketplace on its first interactive start,
# which has not happened yet when fresh.sh runs this.
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add backnotprop/plannotator
claude plugin marketplace add grixu/cc-toolkit
claude plugin marketplace add simple10/agents-observe
claude plugin marketplace add muratcankoylan/Agent-Skills-for-Context-Engineering
claude plugin marketplace add bartekpucek/miodkuj

echo "Installing plugins"
claude plugin install plannotator@plannotator -s user -y
claude plugin install skill-creator@claude-plugins-official -s user -y
claude plugin install typescript-lsp@claude-plugins-official -s user -y

# ---------------------------------------------------------------------------

echo ""
echo "Done. What is left to do by hand:"
echo "  claude                 # log in"
echo "  ccs setup && ccs auth add personal && ccs auth add work"
echo "  moshi-hook pair --token <pairing-token> && brew services start moshi-hook"
echo "  obsidian --version     # Obsidian must run once to expose its CLI"
echo ""
echo "Use ccsync to pull config changes from ~/.claude back into the dotfiles."
