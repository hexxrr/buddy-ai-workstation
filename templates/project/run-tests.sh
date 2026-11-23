#!/bin/sh
# run-tests.sh — the project's test gate. Run before every commit.
set -eu
cd "$(dirname "$0")"

PYTHONPATH=src python3 -m unittest discover -s tests -v
