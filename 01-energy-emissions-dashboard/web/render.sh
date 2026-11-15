#!/bin/bash
# Rebuild the static dashboard:  Rscript prep_data.R && quarto render
# Run from web/.
set -e
cd "$(dirname "$0")"
Rscript prep_data.R
rm -rf ../site
quarto render
rm -rf ../site/data
cp -r data ../site/data
cp -f plot.js ../site/plot.js
rm -f ../site/data/*.aux.xml data/*.aux.xml
echo "site/ ready (including data/ and vendored plot.js)"
