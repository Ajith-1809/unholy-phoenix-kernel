#!/bin/bash
set -e

echo "=================================================="
echo "  Push to GitHub for Cloud Build"
echo "=================================================="
echo ""

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASE_DIR"

# Init git if needed
if [ ! -d ".git" ]; then
    echo "[+] Initializing git repository..."
    git init
fi

# Check for remote
if ! git remote get-url origin > /dev/null 2>&1; then
    echo ""
    echo "[!] No remote configured."
    echo ""
    echo "Please create a GitHub repository first, then run:"
    echo "  git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
    echo ""
    echo "Or enter your GitHub repo URL now:"
    read -p "URL: " REPO_URL
    if [ -n "$REPO_URL" ]; then
        git remote add origin "$REPO_URL"
    else
        echo "No URL provided. Please add remote manually."
        exit 1
    fi
fi

# Add files
echo "[+] Adding files..."
git add build_setup.sh build_kernel.sh push_to_github.sh README.md 2>/dev/null || true
git add .github/ 2>/dev/null || true
git add -A

# Show status
echo ""
echo "[+] Git status:"
git status

# Commit
echo ""
echo "[+] Creating commit..."
git commit -m "Kernel build: Unholy Phoenix v2.2

- KernelSU-Next v3.2.0
- SusFS v1.4.2 (kernel 4.14)
- Kernel 4.14.356 (Poco X2 / Redmi K30)
- GitHub Actions workflow for cloud build
- Custom backports for kernel 4.14"

echo ""
echo "=================================================="
echo "  Ready to push!"
echo "=================================================="
echo ""
echo "Run the following commands:"
echo ""
echo "  git branch -M main"
echo "  git push -u origin main"
echo ""
echo "Then go to GitHub > Actions tab > Run workflow"
echo "=================================================="
