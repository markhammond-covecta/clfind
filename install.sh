#!/bin/bash
set -e
mkdir -p ~/.local/bin
cp "$(dirname "$0")/clfind" ~/.local/bin/clfind
chmod +x ~/.local/bin/clfind

if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    SHELL_RC="$HOME/.zshrc"
    [ -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
    echo "Added ~/.local/bin to PATH in $(basename $SHELL_RC). Run: source $SHELL_RC"
fi

echo "Done! Run: clfind --help"
