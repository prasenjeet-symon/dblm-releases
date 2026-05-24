#!/bin/sh
# dblm Installer for macOS and Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/prasenjeet-symon/dblm-releases/main/install.sh | sh

set -e

RELEASES_REPO="prasenjeet-symon/dblm-releases"
INSTALL_DIR="/usr/local/bin"

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
  linux*)  OS="linux" ;;
  darwin*) OS="darwin" ;;
  *)
    echo "Error: unsupported operating system: $OS"
    echo "Windows users: irm https://raw.githubusercontent.com/prasenjeet-symon/dblm-releases/main/install.ps1 | iex"
    exit 1
    ;;
esac

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64 | amd64) ARCH="x86_64" ;;
  arm64 | aarch64) ARCH="arm64" ;;
  *)
    echo "Error: unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# Fetch latest release tag
echo "Fetching latest release..."
TAG=$(curl -fsSL "https://api.github.com/repos/${RELEASES_REPO}/releases/latest" \
  | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

if [ -z "$TAG" ]; then
  echo "Error: could not determine latest release tag"
  exit 1
fi

VERSION_NO_V=$(echo "$TAG" | sed 's/^v//')
ASSET="dblm_${VERSION_NO_V}_${OS}_${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/${RELEASES_REPO}/releases/download/${TAG}/${ASSET}"

# Download
echo "Downloading dblm $TAG for $OS/$ARCH..."
TMP_DIR=$(mktemp -d)
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/dblm.tar.gz"

# Extract
tar -xzf "$TMP_DIR/dblm.tar.gz" -C "$TMP_DIR"
rm "$TMP_DIR/dblm.tar.gz"

# Install
if [ -w "$INSTALL_DIR" ]; then
  mv "$TMP_DIR/dblm" "$INSTALL_DIR/dblm"
else
  echo "Installing to $INSTALL_DIR (requires sudo)..."
  sudo mv "$TMP_DIR/dblm" "$INSTALL_DIR/dblm"
fi
chmod +x "$INSTALL_DIR/dblm"
rm -rf "$TMP_DIR"

# Verify
VERSION=$("$INSTALL_DIR/dblm" version 2>/dev/null || echo "unknown")
echo ""
echo "dblm $VERSION installed successfully!"
echo ""
echo "Next steps:"
echo "  dblm connect add     # add a database connection"
echo "  dblm index add <db>  # index the schema"
echo "  dblm query <db>      # ask questions in natural language"
