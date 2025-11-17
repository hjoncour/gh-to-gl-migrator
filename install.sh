#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="${GH_MIRROR_REPO_OWNER:-Santeau}"
REPO_NAME="${GH_MIRROR_REPO_NAME:-gh-to-gl-migrator}"
REPO_REF="${GH_MIRROR_REPO_REF:-main}"
REPO_URL="${GH_MIRROR_REPO:-https://github.com/${REPO_OWNER}/${REPO_NAME}}"
TARBALL_URL="${GH_MIRROR_TARBALL:-${REPO_URL}/archive/refs/heads/${REPO_REF}.tar.gz}"
INSTALL_ROOT="${GH_MIRROR_HOME:-$HOME/.gh-mirror}"
BIN_DIR="${GH_MIRROR_BIN:-$HOME/.local/bin}"

echo "gh-mirror installer"
echo "Source repository : $REPO_URL (@ $REPO_REF)"
echo "Install location  : $INSTALL_ROOT"
echo "Binary directory  : $BIN_DIR"

mkdir -p "$INSTALL_ROOT"
mkdir -p "$BIN_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading latest sources..."
curl -fsSL "$TARBALL_URL" | tar -xz -C "$TMP_DIR"

SRC_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -n1)"
if [[ -z "$SRC_DIR" ]]; then
  echo "Error: failed to locate extracted repository contents." >&2
  exit 1
fi

echo "Installing helper scripts into $INSTALL_ROOT..."
rm -rf "$INSTALL_ROOT"
mkdir -p "$INSTALL_ROOT"
cp -R "$SRC_DIR/scripts" "$INSTALL_ROOT/"
cp -R "$SRC_DIR/bin" "$INSTALL_ROOT/"

# Ensure helper scripts are executable.
find "$INSTALL_ROOT" -type f -name "*.sh" -exec chmod +x {} \;

echo "Publishing gh-mirror command to $BIN_DIR..."
install -m 0755 "$INSTALL_ROOT/bin/gh-mirror" "$BIN_DIR/gh-mirror"

echo
echo "gh-mirror installed successfully."
echo "Ensure $BIN_DIR is on your PATH. Example:"
echo "  export PATH=\"$BIN_DIR:\$PATH\""
echo
echo "Usage:"
echo "  gh-mirror           # run full setup (secrets + workflow) in the current repo"
echo "  gh-mirror configure # only configure GitHub secrets/variables"
echo "  gh-mirror workflow  # only scaffold/update the workflow file"

