#!/bin/sh
set -e
set -u

ghc --make Build.hs \
    -rtsopts -with-rtsopts=-I0

./Build "$@"
