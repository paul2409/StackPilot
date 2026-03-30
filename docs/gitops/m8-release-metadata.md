# M8 Release Metadata

## Purpose

This document explains how release metadata is represented during local M8.

## Current representation

- artifacts/releases/current-dev.txt
- artifacts/releases/current-staging.txt

These files are human-readable release truth helpers.

## Why this matters

The repo should answer:
- what dev is meant to run
- what staging is meant to run
- whether staging is consuming the same validated artifact as dev

## Promotion idea

Early M8:
- image references may still be simple and manually updated

Stronger M8:
- CI builds once
- CI publishes once
- dev consumes that artifact first
- staging later consumes the same artifact identity

## Future evolution

This can later become:
- images.lock.yaml
- digest-pinned values
- CI-generated release manifests
- milestone release notes
