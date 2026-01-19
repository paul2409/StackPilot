#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../vagrant"
vagrant up worker2
vagrant ssh worker2
