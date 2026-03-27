# Project Context: Agentic Workflow for Unit Test Maintenance

## 1. Vision & Architecture
This project implements an **Agentic Workflow** pattern to automate the maintenance of Java unit tests. The core principle is the separation of concerns:
* **Deterministic Layer (Local Scripts):** Handles heavy lifting, file system scanning, AST parsing, and hashing. These are "Local Skills" that provide the AI with ground truth.
* **Reasoning Layer (LLM):** Handles code analysis, test generation, and logic updates based on the context provided by the local tools.

This approach minimizes token consumption and ensures that the AI only acts when a change is detected, maintaining high precision.

## 2. Technical Implementation: The PowerShell CLI Toolset
The system relies on a personal CLI composed of 4 PowerShell scripts. The AI is expected to call these scripts to understand the project state:

1.  **`Get-MethodHashes.ps1`**: Scans the source code using a specialized Java CLI (see Section 3). It outputs a list of methods and their unique hashes.
2.  **`Sync-TestInventory.ps1`**: Manages a `control.csv` file. It compares current hashes against the record and updates the **Status** column:
    * `DONE`: Synced.
    * `PENDING`: New method detected.
    * `UPDATED`: Logic change detected (Hash mismatch).
    * `EXCLUDED/PREEXISTENT`: Special flags.
3.  **`Get-PendingContext.ps1`**: Filters the CSV for `UPDATED` entries and extracts the source code of the modified method and its corresponding unit test to provide surgical context to the AI.
4.  **`Update-TestStatus.ps1`**: Post-processing script. Once the AI confirms the test update, this script recalculates the hash and resets the status to `DONE`.

## 3. The Java Parsing Problem & Solution
**Constraint:** Standard Regular Expressions (Regex) are insufficient for parsing Java due to nested structures (lambdas, inner classes, overloads).
**Solution:** The workflow utilizes a dedicated, lightweight Java CLI utility built with **JavaParser** (Open Source, Apache 2.0). 
* This utility generates an **Abstract Syntax Tree (AST)** to identify method boundaries precisely.
* It normalizes code (removing whitespace and comments) before hashing to prevent "false positives" caused by formatting changes.

## 4. Strict Constraints & Compliance (Corporate Environment)
The project is designed for deployment in high-security corporate environments (NTT DATA). The following rules are non-negotiable:

* **Zero Licensing Cost:** Every component (libraries, runners, dependencies) must be Open Source with permissive licenses (MIT, Apache 2.0, BSD). No commercial licenses or "trial-ware" allowed.
* **Digital Sovereignty & Privacy:** * No data shall be uploaded to third-party SaaS for processing (except for the LLM API calls which must be strictly limited to the code fragments being analyzed).
    * Parsing and hashing MUST happen locally. 
    * The AI must not attempt to "search the web" for internal library documentation or send proprietary codebases to external indexing services.
* **Local Execution:** The entire "Skill" catalog (PowerShell + Java CLI) runs in the local developer environment (WSL2/Windows).

## 5. Metadata Structure (control.csv)
| Column | Description |
| :--- | :--- |
| **Clase** | Full class name. |
| **Método** | Method signature (including params for overloads). |
| **Hash** | SHA-256 of the normalized method body. |
| **Estado** | Current workflow state (UPDATED, PENDING, DONE, etc.). |