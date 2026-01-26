#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../vagrant"
vagrant up worker1
vagrant ssh worker1
