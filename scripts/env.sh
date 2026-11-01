# Load the tools the installers add (nvm/Node, ~/.local/bin, bb CLI) into the current shell.
# Agents run each command in a fresh, non-interactive shell that skips ~/.zshrc / ~/.bashrc,
# so every script sources this file first:   . scripts/env.sh
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
  nvm use --silent default >/dev/null 2>&1 || true
fi
for d in "$HOME/.local/bin" "$HOME/.bb/bin" /opt/homebrew/bin /usr/local/bin; do
  case ":$PATH:" in *":$d:"*) ;; *) [ -d "$d" ] && PATH="$d:$PATH" ;; esac
done
export PATH
