#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../vagrant"
vagrant ssh control
