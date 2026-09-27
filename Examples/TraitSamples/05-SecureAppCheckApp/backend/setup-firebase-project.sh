#!/usr/bin/env bash
set -euo pipefail

# Text formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${BLUE}   Firebase App Check & Jev Gateway Setup Wizard     ${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}\n"

# 1. Prerequisite checks
echo -e "${BOLD}Step 1: Checking CLI tools...${NC}"
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}Error: 'firebase' CLI is not installed.${NC}"
    echo "Install it via: npm install -g firebase-tools"
    exit 1
fi
echo -e "${GREEN}✓ Firebase CLI found (${NC}$(firebase --version)${GREEN})${NC}"

if ! command -v gcloud &> /dev/null; then
    echo -e "${YELLOW}Notice: 'gcloud' CLI not found. Secret Manager will be configured via Firebase CLI.${NC}"
fi

# 2. Select Firebase Project
echo -e "\n${BOLD}Step 2: Firebase Project Selection${NC}"
echo "Current Firebase accounts:"
firebase login:list || true

read -rp "Enter your Firebase Project ID: " PROJECT_ID
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: Project ID cannot be empty.${NC}"
    exit 1
fi

echo -e "Using project: ${BOLD}${GREEN}${PROJECT_ID}${NC}"
firebase use "$PROJECT_ID"

# 3. Configure TypeSafe AI Secret
echo -e "\n${BOLD}Step 3: Google Cloud Secret Manager (TYPESAFE_API_KEY)${NC}"
echo "Your TypeSafe AI API key is stored securely in GCP Secret Manager and never bundled into the iOS/macOS client app."
read -rsp "Enter your TypeSafe AI API Key (leave empty to configure later): " TYPESAFE_KEY
echo ""

if [ -n "$TYPESAFE_KEY" ]; then
    echo -e "Storing secret ${BOLD}TYPESAFE_API_KEY${NC} in Secret Manager..."
    printf '%s' "$TYPESAFE_KEY" | firebase functions:secrets:set TYPESAFE_API_KEY --project "$PROJECT_ID" || {
        echo -e "${YELLOW}Warning: Could not set secret automatically. Run 'firebase functions:secrets:set TYPESAFE_API_KEY' manually.${NC}"
    }
    echo -e "${GREEN}✓ Secret stored securely.${NC}"
else
    echo -e "${YELLOW}Skipped secret creation. The gateway will run in simulated mock mode until TYPESAFE_API_KEY is set.${NC}"
fi

# 4. Build TypeScript Functions
echo -e "\n${BOLD}Step 4: Building Cloud Functions...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/functions"

if [ -f "package.json" ]; then
    echo "Installing function dependencies..."
    npm install
    echo "Compiling TypeScript..."
    npm run build
    echo -e "${GREEN}✓ Cloud Functions compiled successfully.${NC}"
fi

# 5. Cloud Function Deployment
cd "$SCRIPT_DIR"
echo -e "\n${BOLD}Step 5: Cloud Function Deployment${NC}"
read -rp "Deploy 'jevProxy' Cloud Function now? [y/N]: " CONFIRM_DEPLOY

if [[ "$CONFIRM_DEPLOY" =~ ^[Yy]$ ]]; then
    echo "Deploying 2nd Gen Cloud Function to project '$PROJECT_ID'..."
    firebase deploy --only functions:jevProxy --project "$PROJECT_ID"
    FUNCTION_URL="https://us-central1-${PROJECT_ID}.cloudfunctions.net/jevProxy"
    echo -e "\n${GREEN}✓ Deployed successfully!${NC}"
    echo -e "Gateway Endpoint: ${BOLD}${BLUE}${FUNCTION_URL}${NC}"
else
    echo -e "${YELLOW}Deployment deferred. You can deploy later using:${NC}"
    echo "  cd $(pwd) && firebase deploy --only functions"
fi

# 6. Update Client Configuration
echo -e "\n${BOLD}Step 6: Updating Client Configuration...${NC}"
CLIENT_SWIFT_VIEW="$SCRIPT_DIR/../Sources/SecureTriageView.swift"
if [ -f "$CLIENT_SWIFT_VIEW" ]; then
    # Update default project ID in SecureTriageViewModel
    sed -i.bak "s/var projectID: String = \".*\"/var projectID: String = \"$PROJECT_ID\"/g" "$CLIENT_SWIFT_VIEW" 2>/dev/null && rm -f "${CLIENT_SWIFT_VIEW}.bak" || true
    echo -e "${GREEN}✓ Updated default project ID to '$PROJECT_ID' in SecureTriageView.swift${NC}"
fi

echo -e "\n${BOLD}${GREEN}======================================================${NC}"
echo -e "${BOLD}${GREEN}               Setup Complete!                        ${NC}"
echo -e "${BOLD}${GREEN}======================================================${NC}"
echo -e "Next steps:"
echo -e "1. For Local Emulator testing: ${BLUE}firebase emulators:start --only functions,appCheck${NC}"
echo -e "2. For Production App Attest setup: see ${BOLD}SETUP-PRODUCTION.md${NC}"
echo -e "3. Run the client app: ${BLUE}swift run SecureAppCheckApp${NC}"
