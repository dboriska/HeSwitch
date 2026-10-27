#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# HeSwitch Automated Installer & Updater for macOS
# ==============================================================================
# Single-command install or update:
#   curl -fsSL https://raw.githubusercontent.com/dboriska/HeSwitch/main/install.sh | bash
#
# What this script does:
# 1. Queries GitHub API for the latest HeSwitch release.
# 2. Terminates any running instance of HeSwitch.
# 3. Downloads and extracts HeSwitch.app into /Applications/HeSwitch.app.
# 4. Clears macOS quarantine attributes (xattr -cr) to prevent App Translocation.
# 5. Resets stale TCC accessibility database entries (tccutil reset Accessibility ...).
# 6. Launches /Applications/HeSwitch.app.
# 7. Opens macOS System Settings -> Privacy & Security -> Accessibility.
# ==============================================================================

REPO="dboriska/HeSwitch"
APP_NAME="HeSwitch.app"
DEST_PATH="/Applications/${APP_NAME}"
BUNDLE_ID="com.hebrew.HeSwitch"

echo "==> [HeSwitch] Checking latest release from ${REPO}..."

LATEST_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
DOWNLOAD_URL=$(echo "${LATEST_JSON}" | grep -o 'https://[^"]*HeSwitch-macOS.zip' | head -n 1 || true)
VERSION_TAG=$(echo "${LATEST_JSON}" | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)

if [[ -z "${DOWNLOAD_URL}" ]]; then
    echo "==> [HeSwitch] Could not find asset in latest release. Checking all releases..."
    ALL_RELEASES=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases")
    DOWNLOAD_URL=$(echo "${ALL_RELEASES}" | grep -o 'https://[^"]*HeSwitch-macOS.zip' | head -n 1)
    VERSION_TAG=$(echo "${ALL_RELEASES}" | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4)
fi

if [[ -z "${DOWNLOAD_URL}" ]]; then
    echo "Error: Could not locate HeSwitch-macOS.zip release asset."
    exit 1
fi

echo "==> [HeSwitch] Target release: ${VERSION_TAG:-latest}"
echo "==> [HeSwitch] Downloading from: ${DOWNLOAD_URL}"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_DIR}/HeSwitch.zip"

echo "==> [HeSwitch] Stopping any currently running HeSwitch..."
pkill -x HeSwitch 2>/dev/null || true
sleep 0.5

echo "==> [HeSwitch] Extracting to ${DEST_PATH}..."
unzip -q -o "${TMP_DIR}/HeSwitch.zip" -d "${TMP_DIR}"

if [[ -d "${DEST_PATH}" ]]; then
    rm -rf "${DEST_PATH}"
fi

ditto "${TMP_DIR}/${APP_NAME}" "${DEST_PATH}"

echo "==> [HeSwitch] Removing macOS quarantine flag (prevents App Translocation)..."
xattr -cr "${DEST_PATH}"

echo "==> [HeSwitch] Resetting stale Accessibility TCC cache for ${BUNDLE_ID}..."
tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || true

echo "==> [HeSwitch] Launching ${DEST_PATH}..."
open "${DEST_PATH}"

echo "==> [HeSwitch] Opening System Settings & revealing in Finder..."
open -R "${DEST_PATH}"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo ""
echo "================================================================================"
echo " HeSwitch ${VERSION_TAG} installed successfully!"
echo " IMPORTANT: In the System Settings window that just opened:"
echo " 1. Look for 'HeSwitch' in Privacy & Security → Accessibility and turn it ON."
echo " 2. If 'HeSwitch' is NOT in the list, drag 'HeSwitch.app' from the Finder window"
echo "    directly into the Accessibility list, or click '+' and select HeSwitch."
echo "================================================================================"
echo "================================================================================"
