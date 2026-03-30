#!/usr/bin/env bash
set -euo pipefail

echo "[1/5] Strengthening .gitignore"
grep -q "Local generated residue" .gitignore 2>/dev/null || cat >> .gitignore <<'EOF'

# Local generated residue
tmp/*
!tmp/.gitkeep

artifacts/logs/*
!artifacts/logs/.keep

artifacts/drills/*
!artifacts/drills/.keep

artifacts/reports/*
!artifacts/reports/.keep

artifacts/smoke-tests/*
!artifacts/smoke-tests/.keep

# Local tool/binary residue
vagrant/k3s-bin/
venv/
.venv/
__pycache__/
*.pyc
EOF

echo "[2/5] Creating keep files"
mkdir -p artifacts/logs artifacts/drills artifacts/reports artifacts/smoke-tests tmp
touch artifacts/logs/.keep artifacts/drills/.keep artifacts/reports/.keep artifacts/smoke-tests/.keep tmp/.gitkeep

echo "[3/5] Untracking generated residue"
git rm -r --cached tmp 2>/dev/null || true
git rm -r --cached artifacts/logs 2>/dev/null || true
git rm -r --cached artifacts/drills 2>/dev/null || true
git rm -r --cached vagrant/k3s-bin 2>/dev/null || true
git rm -r --cached venv 2>/dev/null || true
git rm -r --cached .venv 2>/dev/null || true

echo "[4/5] Removing local junk from working tree"
rm -rf tmp/*
rm -rf artifacts/logs/*
rm -rf artifacts/drills/*
rm -rf vagrant/k3s-bin
rm -rf venv .venv

touch artifacts/logs/.keep artifacts/drills/.keep artifacts/reports/.keep artifacts/smoke-tests/.keep tmp/.gitkeep

echo "[5/5] Done. Review with:"
echo "  git status"
echo "  du -sh .[!.]* * 2>/dev/null | sort -h"