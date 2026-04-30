# Add Destination to Cache Bundle Manifest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve `scripts/create-cache-bundle.sh` by adding a "Destination" column to the `manifest.md` table to show where binaries are deployed.

**Architecture:** 
1. Update the `MANIFEST_MD` heredoc string in `scripts/create-cache-bundle.sh` to include a new "Destination" column header.
2. Update all the rows in the markdown table to include the destination path.

**Tech Stack:** Bash

---

### Task 1: Add Destination to Manifest Table

**Files:**
- Modify: `scripts/create-cache-bundle.sh`

- [ ] **Step 1: Replace file content to add destination column**
