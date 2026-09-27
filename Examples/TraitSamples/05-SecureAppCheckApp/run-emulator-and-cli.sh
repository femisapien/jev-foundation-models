#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="${SCRIPT_DIR}/backend"
FUNCTIONS_DIR="${BACKEND_DIR}/functions"

PROJECT_ID="my-secure-project"
ENDPOINT_URL="http://127.0.0.1:5001/${PROJECT_ID}/us-central1/jevProxy"
MAX_POLL_SECONDS=30

echo "================================================================="
echo "  05-SecureAppCheckApp: Local Firebase Emulator & CLI Runner     "
echo "================================================================="

# Step 1: Check if Node.js and Firebase tools are installed
echo "--> Step 1: Checking prerequisites (node, firebase)..."

if ! command -v node >/dev/null 2>&1; then
    echo "Error: Node.js is not installed or not in PATH."
    exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
    echo "Error: Firebase CLI ('firebase') is not installed or not in PATH."
    echo "Install it via: npm install -g firebase-tools"
    exit 1
fi

NODE_VERSION=$(node -v)
FIREBASE_VERSION=$(firebase --version)
echo "Found Node.js (${NODE_VERSION}) and Firebase CLI (${FIREBASE_VERSION})."

# Ensure dependencies are installed and functions are compiled
if [ ! -d "${FUNCTIONS_DIR}/node_modules" ]; then
    echo "Installing functions npm dependencies..."
    npm --prefix "${FUNCTIONS_DIR}" install
fi

if [ ! -f "${FUNCTIONS_DIR}/lib/index.js" ]; then
    echo "Building functions TypeScript..."
    npm --prefix "${FUNCTIONS_DIR}" run build
fi

# Step 2: Check if emulator is already running on port 5001
echo "--> Step 2: Checking emulator status on port 5001..."

EMULATOR_PID=""

cleanup() {
    if [ -n "${EMULATOR_PID:-}" ]; then
        echo ""
        echo "--> Cleaning up: Terminating background Firebase Emulator (PID: ${EMULATOR_PID})..."
        kill -TERM "${EMULATOR_PID}" 2>/dev/null || true
        wait "${EMULATOR_PID}" 2>/dev/null || true
        # kill any remaining processes on port 5001 if started by us
        lsof -ti :5001 | xargs kill -9 2>/dev/null || true
        echo "Emulator terminated cleanly."
    fi
}
trap cleanup EXIT INT TERM

if lsof -i :5001 >/dev/null 2>&1; then
    echo "Firebase Emulator is already running on port 5001."
else
    echo "Starting Firebase Emulator in background (functions only)..."
    pushd "${BACKEND_DIR}" >/dev/null
    firebase emulators:start --only functions --project "${PROJECT_ID}" >/dev/null 2>&1 &
    EMULATOR_PID=$!
    popd >/dev/null
    echo "Spawned emulator process with PID ${EMULATOR_PID}."
fi

# Step 3: Health-check / poll the jevProxy HTTP endpoint
echo "--> Step 3: Health-checking jevProxy endpoint at ${ENDPOINT_URL}..."
START_TIME=$(date +%s)
READY=false

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    # Send a probe request. We expect HTTP 405 (GET method) or 401/200 if active
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${ENDPOINT_URL}" || true)

    if [ "${HTTP_CODE}" = "405" ] || [ "${HTTP_CODE}" = "401" ] || [ "${HTTP_CODE}" = "200" ]; then
        echo "jevProxy Cloud Function is active and ready (HTTP status: ${HTTP_CODE}, took ${ELAPSED}s)."
        READY=true
        break
    fi

    if [ ${ELAPSED} -ge ${MAX_POLL_SECONDS} ]; then
        break
    fi

    sleep 1
done

if [ "${READY}" != true ]; then
    echo "Error: Timed out waiting for jevProxy endpoint to become ready after ${MAX_POLL_SECONDS}s."
    exit 1
fi

# Step 4: Run the Swift CLI app against the active emulator
echo "--> Step 4: Running Swift CLI against the emulator..."
swift run --package-path "${SCRIPT_DIR}" SecureAppCheckApp --cli --emulator

# Step 5: Report success
echo "--> Step 5: Finished successfully!"
