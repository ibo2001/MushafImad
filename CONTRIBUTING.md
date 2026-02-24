# Contributing to MushafImad

**Assalamu Alaikum! (Peace be upon you)**

Welcome to **MushafImad**. We are honored to have you join us as part of the **Ramadan Impact (Ramadan Al-Athar)** campaign. Your code, documentation, and testing efforts are a form of *Sadaqah Jariyah* (ongoing charity) that will benefit Muslims reading the Quran around the world.

Our goal is not just to write code, but to build a community of refined craftsmen (*Itqan*) who produce high-quality, lasting software.

## Contribution Etiquette (The Workflow)

To ensure high quality and prevent wasted effort, we strictly follow this workflow. Please respect these steps:

1.  **Communicate First**: Before writing any code, look through the [Issues](https://github.com/ibo2001/MushafImad/issues). If you find one you like, or have a new idea, leave a comment on the issue/proposal.
    *   *Example: "Salam, I would like to work on this issue. Is it available?"*
2.  **Wait for Assignment**: Do not start working until a maintainer assigns the issue to you. This prevents multiple people from working on the same task.
3.  **Fork & Branch**:
    *   Fork the repository to your own GitHub account.
    *   Create a specific branch for your task (e.g., `feature/search-ui` or `fix/typo-readme`). **Do not work on `main`.**
4.  **Develop & Test**: Write your code. Ensure you run the existing tests (even if they are minimal) and add new ones if possible.
5.  **Submit a Pull Request (PR)**:
    *   Push your branch to your fork.
    *   Open a PR against the `main` branch of MushafImad.
    *   **Crucial**: Reference the Issue number in your PR description (e.g., "Fixes #12").

## Getting Started

### Prerequisites
*   macOS 14+
*   Xcode 15+
*   Swift 5.9+

### Setup
1.  Clone your fork:
    ```bash
    git clone https://github.com/YOUR_USERNAME/MushafImad.git
    cd MushafImad
    ```
2.  Open the project:
    *   Double-click `Package.swift` to open in Xcode as a package.
    *   **OR** open `Example/Example.xcodeproj` to run the sample app on a simulator.
3.  **Important**: The project uses a bundled Realm database (`quran.realm`). This is handled automatically by the package resources, but ensure you let Xcode finish "Indexing" before running.

### Project Structure
*   `Sources/Core`: Logic, Models, and Realm Database services.
*   `Sources/AudioPlayer`: All Audio logic (AVPlayer, timing).
*   `Sources/MushafImad`: The main SwiftUI Views (`MushafView`).

## Code of Conduct

We follow the general principles of Islamic brotherhood/sisterhood: act with kindness, respect, and patience. Constructive feedback is a gift.

**Jazakum Allahu Khairan** for your time and effort!
