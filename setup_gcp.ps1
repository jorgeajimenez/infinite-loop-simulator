<#
.SYNOPSIS
Automated Google Cloud setup script for Infinite Flight Simulator

.DESCRIPTION
This PowerShell script sets up a new Google Cloud project, links it to a billing account,
enables necessary APIs (Vertex AI and Earth Engine), creates a service account,
assigns roles, and generates a service-account-key.json file.
#>

$ErrorActionPreference = "Stop"

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Infinite Flight Simulator: Google Cloud Setup Script" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

# Check if gcloud is installed
if (!(Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: Google Cloud CLI (gcloud) is not installed." -ForegroundColor Red
    Write-Host "Please install it first: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Google Cloud CLI is installed." -ForegroundColor Green

# Ensure user is authenticated
try {
    $null = gcloud auth print-access-token 2>&1
} catch {
    Write-Host "🔑 Please log in to Google Cloud:" -ForegroundColor Yellow
    gcloud auth login
}

Write-Host "✅ Authenticated with Google Cloud." -ForegroundColor Green
Write-Host ""

# Ask for Project ID
$PROJECT_ID = Read-Host "Enter a NEW Google Cloud Project ID (must be globally unique, e.g., flight-sim-1234)"

if ([string]::IsNullOrWhiteSpace($PROJECT_ID)) {
    Write-Host "❌ Error: Project ID cannot be empty." -ForegroundColor Red
    exit 1
}

Write-Host "🚀 Creating project: $PROJECT_ID..." -ForegroundColor Cyan
gcloud projects create "$PROJECT_ID" --name="Infinite Flight Simulator"

Write-Host "✅ Project created." -ForegroundColor Green
Write-Host ""

# Link billing account
Write-Host "💳 Fetching available billing accounts..." -ForegroundColor Cyan
$BILLING_ACCOUNTS = gcloud billing accounts list --format="value(name,displayName)"

if ([string]::IsNullOrWhiteSpace($BILLING_ACCOUNTS)) {
    Write-Host "❌ Error: No billing accounts found. Please create one at https://console.cloud.google.com/billing" -ForegroundColor Red
    exit 1
}

Write-Host "Available Billing Accounts:" -ForegroundColor Yellow
gcloud billing accounts list
Write-Host ""
$BILLING_ID = Read-Host "Enter the ACCOUNT_ID of the billing account to link to this project"

if ([string]::IsNullOrWhiteSpace($BILLING_ID)) {
    Write-Host "❌ Error: Billing ID cannot be empty." -ForegroundColor Red
    exit 1
}

Write-Host "🔗 Linking billing account..." -ForegroundColor Cyan
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ID"

Write-Host "✅ Billing account linked." -ForegroundColor Green
Write-Host ""

# Set project as default
gcloud config set project "$PROJECT_ID"

# Enable APIs
Write-Host "⚡ Enabling Vertex AI, Earth Engine, and Map Tiles APIs..." -ForegroundColor Cyan
gcloud services enable aiplatform.googleapis.com
gcloud services enable earthengine.googleapis.com
gcloud services enable maptiles.googleapis.com

Write-Host "✅ APIs enabled." -ForegroundColor Green
Write-Host ""

# Create Service Account
$SA_NAME = "flight-sim-backend"
$SA_EMAIL = "${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

Write-Host "🤖 Creating Service Account: $SA_NAME..." -ForegroundColor Cyan
gcloud iam service-accounts create "$SA_NAME" `
    --description="Backend service account for Infinite Flight Simulator" `
    --display-name="Flight Sim Backend"

# Assign Roles
Write-Host "🔐 Assigning roles (Vertex AI User & Earth Engine Resource Viewer)..." -ForegroundColor Cyan
Start-Sleep -Seconds 5 # Wait for SA to propagate

gcloud projects add-iam-policy-binding "$PROJECT_ID" `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/aiplatform.user" > $null

gcloud projects add-iam-policy-binding "$PROJECT_ID" `
    --member="serviceAccount:$SA_EMAIL" `
    --role="roles/earthengine.viewer" > $null

Write-Host "✅ Roles assigned." -ForegroundColor Green
Write-Host ""

# Generate Key
Write-Host "🔑 Generating service-account-key.json..." -ForegroundColor Cyan
gcloud iam service-accounts keys create service-account-key.json `
    --iam-account="$SA_EMAIL"

Write-Host ""
Write-Host "🎉 Setup Complete!" -ForegroundColor Green
Write-Host "Your service account key has been saved as 'service-account-key.json'." -ForegroundColor Yellow
Write-Host "You can now run the simulator." -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
