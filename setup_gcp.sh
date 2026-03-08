#!/bin/bash

# setup_gcp.sh
# Automated Google Cloud setup script for Infinite Flight Simulator

set -e

echo "====================================================="
echo " Infinite Flight Simulator: Google Cloud Setup Script"
echo "====================================================="
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Error: Google Cloud CLI (gcloud) is not installed."
    echo "Please install it first: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

echo "✅ Google Cloud CLI is installed."

# Ensure user is authenticated
if ! gcloud auth print-access-token &> /dev/null; then
    echo "🔑 Please log in to Google Cloud:"
    gcloud auth login
fi

echo "✅ Authenticated with Google Cloud."
echo ""

# Ask for Project ID
read -p "Enter a NEW Google Cloud Project ID (must be globally unique, e.g., flight-sim-1234): " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Error: Project ID cannot be empty."
    exit 1
fi

echo "🚀 Creating project: $PROJECT_ID..."
gcloud projects create "$PROJECT_ID" --name="Infinite Flight Simulator"

echo "✅ Project created."
echo ""

# Link billing account
echo "💳 Fetching available billing accounts..."
BILLING_ACCOUNTS=$(gcloud billing accounts list --format="value(name,displayName)")

if [ -z "$BILLING_ACCOUNTS" ]; then
    echo "❌ Error: No billing accounts found. Please create one at https://console.cloud.google.com/billing"
    exit 1
fi

echo "Available Billing Accounts:"
gcloud billing accounts list
echo ""
read -p "Enter the ACCOUNT_ID of the billing account to link to this project: " BILLING_ID

if [ -z "$BILLING_ID" ]; then
    echo "❌ Error: Billing ID cannot be empty."
    exit 1
fi

echo "🔗 Linking billing account..."
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ID"

echo "✅ Billing account linked."
echo ""

# Set project as default
gcloud config set project "$PROJECT_ID"

# Enable APIs
echo "⚡ Enabling Vertex AI and Earth Engine APIs..."
gcloud services enable aiplatform.googleapis.com
gcloud services enable earthengine.googleapis.com

echo "✅ APIs enabled."
echo ""

# Create Service Account
SA_NAME="flight-sim-backend"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🤖 Creating Service Account: $SA_NAME..."
gcloud iam service-accounts create "$SA_NAME" \
    --description="Backend service account for Infinite Flight Simulator" \
    --display-name="Flight Sim Backend"

# Assign Roles
echo "🔐 Assigning roles (Vertex AI User & Earth Engine Resource Viewer)..."
sleep 5 # Wait for SA to propagate
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/aiplatform.user" > /dev/null

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/earthengine.viewer" > /dev/null

echo "✅ Roles assigned."
echo ""

# Generate Key
echo "🔑 Generating service-account-key.json..."
gcloud iam service-accounts keys create service-account-key.json \
    --iam-account="$SA_EMAIL"

echo ""
echo "🎉 Setup Complete!"
echo "Your service account key has been saved as 'service-account-key.json'."
echo "You can now run the simulator."
echo "====================================================="
