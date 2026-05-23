#!/usr/bin/env sh
# install.sh — install the latest dblm binary.
# Hosted at: https://raw.githubusercontent.com/prasenjeet-symon/dblm-releases/main/install.sh
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/prasenjeet-symon/dblm-releases/main/install.sh | sh
#
set -e

RELEASES_REPO="prasenjeet-symon/dblm-releases"
INSTALL_DIR="/usr/local/bin"
BINARY="dblm"

# Detect OS
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
  darwin) OS="darwin" ;;
  linux)  OS="linux" ;;
  *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest version tag
echo "Fetching latest dblm release..."
VERSION="$(curl -sSf "https://api.github.com/repos/$RELEASES_REPO/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"

if [ -z "$VERSION" ]; then
  echo "error: could not fetch latest release version"
  exit 1
fi

FILENAME="dblm-${OS}-${ARCH}"
URL="https://github.com/${RELEASES_REPO}/releases/download/${VERSION}/${FILENAME}"

echo "Installing dblm $VERSION ($OS/$ARCH)..."
curl -sSfL "$URL" -o "/tmp/$FILENAME"
chmod +x "/tmp/$FILENAME"

# Install — try without sudo first, fall back to sudo
if [ -w "$INSTALL_DIR" ]; then
  mv "/tmp/$FILENAME" "$INSTALL_DIR/$BINARY"
else
  echo "Requires sudo to install to $INSTALL_DIR"
  sudo mv "/tmp/$FILENAME" "$INSTALL_DIR/$BINARY"
fi

echo ""
echo "dblm $VERSION installed to $INSTALL_DIR/$BINARY"
echo "Run 'dblm --help' to get started."
