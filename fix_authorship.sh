#!/bin/bash

# fix_authorship.sh
# Correct authorship to Siarhei Tabalevich / xabpaxabp@gmail.com
# Run from the root of structural-rank-eta repository

set -e

echo "🔍 Replacing authorship in README.md..."
sed -i 's/Сергей Табалевич/Siarhei Tabalevich/g' README.md
sed -i 's/Sergei V\. Tabalevich/Siarhei Tabalevich/g' README.md
sed -i 's/Sergei Tabalevich/Siarhei Tabalevich/g' README.md
sed -i 's/6955400@gmail\.com/xabpaxabp@gmail.com/g' README.md

echo "🔍 Replacing authorship in CUDA source files..."
sed -i 's/Sergei V\. Tabalevich/Siarhei Tabalevich/g' eta_scanner/*.cu
sed -i 's/Sergei Tabalevich/Siarhei Tabalevich/g' eta_scanner/*.cu

echo "🔍 Replacing authorship in theoretical paper..."
if [ -f eta_rank_theory/structural_rank_paper.md ]; then
    sed -i 's/Сергей Табалевич/Siarhei Tabalevich/g' eta_rank_theory/structural_rank_paper.md
    sed -i 's/Sergei V\. Tabalevich/Siarhei Tabalevich/g' eta_rank_theory/structural_rank_paper.md
    sed -i 's/Sergei Tabalevich/Siarhei Tabalevich/g' eta_rank_theory/structural_rank_paper.md
    sed -i 's/6955400@gmail\.com/xabpaxabp@gmail.com/g' eta_rank_theory/structural_rank_paper.md
fi

echo "🔍 Updating BibTeX entry in README.md..."
sed -i 's/author={Табалевич, Сергей}/author={Tabalevich, Siarhei}/g' README.md
sed -i 's/author={Александров, Сергей}/author={Alexandrova, Irina}/g' README.md

echo "✅ Authorship updated successfully."
echo "➡️  Now run:"
echo "      git add ."
echo "      git config user.name \"Siarhei Tabalevich\""
echo "      git config user.email \"xabpaxabp@gmail.com\""
echo "      git commit -m \"Correct authorship to Siarhei Tabalevich\""
echo "      git push"
