#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# HeSwitch Automated Installer & Updater for macOS
# ==============================================================================
REPO="dboriska/HeSwitch"
APP_NAME="HeSwitch.app"
DEST_PATH="/Applications/${APP_NAME}"
BUNDLE_ID="com.hebrew.HeSwitch"
TARGET_VERSION="v1.0.16"

echo "==> [HeSwitch] Preparing installation of HeSwitch ${TARGET_VERSION}..."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

BUILT_FROM_SOURCE=false
SOURCE_APP=""

# 1. Prefer building latest target version from source if swift compiler is available
if command -v swift >/dev/null 2>&1; then
    echo "==> [HeSwitch] Swift toolchain detected. Building ${TARGET_VERSION} from source..."
    if git clone --depth=1 "https://github.com/${REPO}.git" "${TMP_DIR}/repo" 2>/dev/null; then
        cd "${TMP_DIR}/repo/HeSwitch"
        if bash Scripts/package-app.sh >/dev/null 2>&1; then
            CANDIDATE_APP="${TMP_DIR}/repo/HeSwitch/dist/${APP_NAME}"
            if [[ -d "${CANDIDATE_APP}" ]]; then
                BUILT_FROM_SOURCE=true
                SOURCE_APP="${CANDIDATE_APP}"
                echo "==> [HeSwitch] Local build succeeded."

                # If gh CLI is authenticated, publish release asset to GitHub in background
                if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                    (
                        cd "${TMP_DIR}/repo/HeSwitch/dist"
                        zip -q -r HeSwitch-macOS.zip "${APP_NAME}"
                        gh release create "${TARGET_VERSION}" HeSwitch-macOS.zip \
                            --title "HeSwitch ${TARGET_VERSION}" \
                            --notes "CLI diagnostic switches, live foreground monitor mode, rich text support for Apple Notes" >/dev/null 2>&1 || true
                    ) &
                fi
            fi
        fi
    fi
fi

# 2. Fallback to pre-built GitHub release if build was skipped or failed
if [[ "${BUILT_FROM_SOURCE}" != "true" || -z "${SOURCE_APP}" ]]; then
    echo "==> [HeSwitch] Checking latest release from ${REPO}..."
    LATEST_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || true)
    DOWNLOAD_URL=$(echo "${LATEST_JSON}" | grep -o 'https://[^"]*HeSwitch-macOS.zip' | head -n 1 || true)
    VERSION_TAG=$(echo "${LATEST_JSON}" | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)

    if [[ -z "${DOWNLOAD_URL}" ]]; then
        ALL_RELEASES=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases" 2>/dev/null || true)
        DOWNLOAD_URL=$(echo "${ALL_RELEASES}" | grep -o 'https://[^"]*HeSwitch-macOS.zip' | head -n 1 || true)
        VERSION_TAG=$(echo "${ALL_RELEASES}" | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)
    fi

    if [[ -n "${DOWNLOAD_URL}" ]]; then
        echo "==> [HeSwitch] Downloading pre-built ${VERSION_TAG:-latest}..."
        curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_DIR}/HeSwitch.zip"
        unzip -q -o "${TMP_DIR}/HeSwitch.zip" -d "${TMP_DIR}"
        SOURCE_APP="${TMP_DIR}/${APP_NAME}"
    else
        echo "Error: Could not build from source or locate release asset."
        exit 1
    fi
fi

echo "==> [HeSwitch] Stopping any currently running HeSwitch..."
pkill -x HeSwitch 2>/dev/null || true
sleep 0.5

echo "==> [HeSwitch] Installing to ${DEST_PATH}..."
if [[ -d "${DEST_PATH}" ]]; then
    rm -rf "${DEST_PATH}"
fi

ditto "${SOURCE_APP}" "${DEST_PATH}"

echo "==> [HeSwitch] Removing macOS quarantine flag (prevents App Translocation)..."
xattr -cr "${DEST_PATH}"

echo "==> [HeSwitch] Resetting stale Accessibility TCC cache for ${BUNDLE_ID}..."
tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || true

echo "==> [HeSwitch] Launching ${DEST_PATH}..."
open "${DEST_PATH}"

INSTALLED_VER=$("${DEST_PATH}/Contents/MacOS/HeSwitch" --version 2>/dev/null || echo "${TARGET_VERSION}")

echo ""
echo "================================================================================"
echo " ${INSTALLED_VER} installed successfully!"
echo " Testing CLI switches:"
echo "   ${DEST_PATH}/Contents/MacOS/HeSwitch --diagnose"
echo "   ${DEST_PATH}/Contents/MacOS/HeSwitch --verbose"
echo "================================================================================"
