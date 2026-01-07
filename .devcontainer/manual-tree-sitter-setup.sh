#!/bin/bash
# Manual tree-sitter setup script for devcontainer debugging
# Run this if the automatic setup failed

set -e

echo "=== Manual Tree-Sitter Setup ==="
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root in the devcontainer"
  echo "Try: sudo bash .devcontainer/manual-tree-sitter-setup.sh"
  exit 1
fi

echo "1. Checking for existing tree-sitter installation..."
if ldconfig -p | grep -q libtree-sitter; then
  echo "   ✓ tree-sitter runtime found"
  ldconfig -p | grep libtree-sitter
else
  echo "   ✗ tree-sitter runtime NOT found"
  echo "   Installing libtree-sitter-dev..."
  apt-get update
  apt-get install -y libtree-sitter-dev
fi

echo ""
echo "2. Building tree-sitter-jsonc from source..."
TMPDIR=tmp/
#TMPDIR=$(mktemp -d)
#trap "rm -rf $TMPDIR" EXIT
echo "   Working in: $TMPDIR"

cd "$TMPDIR"
wget -v https://gitlab.com/WhyNotHugo/tree-sitter-jsonc/-/archive/main/tree-sitter-jsonc-main.zip -O jsonc.zip
unzip -q jsonc.zip
cd tree-sitter-jsonc-main

echo "   Compiling parser.c..."
gcc -fPIC -I./src -c src/parser.c -o parser.o

# jsonc grammar has no scanner.c
#echo "   Compiling scanner.c..."
#sudo gcc -fPIC -I./src -c src/scanner.c -o scanner.o

echo "   Linking shared library..."
# jsonc grammar has no scanner.c
# sudo gcc -shared -o libtree-sitter-jsonc.so parser.o scanner.o
gcc -shared -o libtree-sitter-jsonc.so parser.o

echo "   Installing to /usr/local/lib/..."
sudo cp libtree-sitter-jsonc.so /usr/local/lib/

echo "   Updating ldconfig cache..."
sudo ldconfig

echo ""
echo "3. Verification:"
if [ -f /usr/local/lib/libtree-sitter-jsonc.so ]; then
  echo "   ✓ /usr/local/lib/libtree-sitter-jsonc.so exists"
  ls -lh /usr/local/lib/libtree-sitter-jsonc.so
else
  echo "   ✗ ERROR: File not found!"
  exit 1
fi

if ldconfig -p | grep -q libtree-sitter-jsonc; then
  echo "   ✓ ldconfig can find libtree-sitter-jsonc.so"
  sudo ldconfig -p | grep libtree-sitter-jsonc
else
  echo "   ✗ WARNING: ldconfig cannot find the library"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "You can now test with:"
echo "  ruby -e \"require 'bundler/setup'; require 'tree_haver'; puts TreeHaver::GrammarFinder.new(:jsonc).find_library_path\""
echo ""
