#! /usr/bin/env bash

function articlepdf() {
  md="$1"
  pdf="${md%.*}.pdf"
  pandoc --filter=pandoc-fignos "$md" -o "$pdf"
  echo "$pdf"
}

[ -n "$1" ] || { echo "Usage: $0 <markdown file>" ; exit 1 }

articlepdf "$1"
