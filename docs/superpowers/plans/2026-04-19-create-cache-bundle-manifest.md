# Create Cache Bundle Manifest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve `scripts/create-cache-bundle.sh` by generating a `manifest.md` containing a table of all downloaded binaries, their versions, and download links.

**Architecture:** 
1. Define all versions at the top of the file so they are easily accessible.
2. Build the markdown table content into a string.
3. Print the string to the console before downloading begins.
4. Save the string to `${staging_dir}/manifest.md` so it's included in the tarball.

**Tech Stack:** Bash

---

### Task 1: Generate Manifest

**Files:**
- Modify: `scripts/create-cache-bundle.sh`

- [ ] **Step 1: Replace file content to generate manifest**
