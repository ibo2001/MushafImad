# Contributing to MushafImad

**Assalamu Alaikum! (Peace be upon you)**

Welcome to **MushafImad**. Your code, documentation, and testing efforts are a form of *Sadaqah
Jariyah* (ongoing charity) that will benefit Muslims reading the Quran around the world.

Our goal is not just to write code, but to build a community of refined craftsmen (*Itqan*) who
produce high-quality, lasting software — and who stay.

> **بالعربية:** [CONTRIBUTING.ar.md](CONTRIBUTING.ar.md)

## Contribution Etiquette (The Workflow)

To ensure high quality and prevent wasted effort, we strictly follow this workflow. Please respect
these steps:

1.  **Communicate First**: Before writing any code, look through the
    [Issues](https://github.com/ibo2001/MushafImad/issues). If you find one you like, or have a new
    idea, leave a comment on the issue.
    *   *Example: "Salam, I would like to work on this issue. Is it available?"*
2.  **Wait for Assignment**: Do not start working until a maintainer assigns the issue to you. This
    prevents multiple people from working on the same task. **Pull requests that arrive with no
    prior comment and no assignment will usually be closed without review.**
3.  **Fork & Branch**:
    *   Fork the repository to your own GitHub account.
    *   Create a specific branch for your task (e.g., `feature/search-ui` or `fix/typo-readme`).
        **Do not work on `main`.**
4.  **Develop & Test**: Write your code, run the existing tests, and add new ones.
5.  **Submit a Pull Request (PR)**:
    *   Push your branch to your fork.
    *   **Open the PR against the `main` branch of MushafImad.** `main` is the only integration
        branch; there is no `develop`.
    *   **Crucial**: Reference the issue number in your PR description (e.g., "Fixes #12").
6.  **Review**: A maintainer will approve, request changes, or explain why the PR cannot be taken.
    Constructive feedback is a gift — expect a round or two of it.
7.  **After the merge**: Write a short post about your experience in the
    [Itqan Community](https://community.itqan.dev) — what you built, what you learned, what got in
    your way. This is not a formality. It is how the next contributor finds their way in.

## Use of AI tools

AI assistants are welcome as **tools**, not as authors.

*   **You may** use AI to explore the codebase, draft code, write tests, or improve wording.
*   **You must** understand every line you submit and be able to explain why it is written that way.
    If a reviewer asks "why this approach?", "I don't know, the model wrote it" is not an answer, and
    the PR will be closed.
*   **Please mention it** in the PR description if AI wrote a substantial part of the change. This is
    not held against you — it tells the reviewer where to look hardest.
*   **Do not** open automated or drive-by pull requests. Unsolicited AI-generated PRs with no prior
    issue assignment are closed on sight, regardless of quality.

The rule behind all of this: the point of contributing here is that *you* learn the project well
enough to keep maintaining it. Output that no human understands does not serve that.

## Getting Started

### Prerequisites

*   macOS 14+
*   **Xcode 16+** (the package is `swift-tools-version: 6.0` and builds in Swift 6 language mode)
*   Deployment targets: **iOS 17+ / macOS 14+**

### Setup

1.  Clone your fork:
    ```bash
    git clone https://github.com/YOUR_USERNAME/MushafImad.git
    cd MushafImad
    ```
2.  Open the project:
    *   Double-click `Package.swift` to open in Xcode as a package.
    *   **OR** open `Example/Example.xcodeproj` to run the sample app on a simulator.
3.  The package uses a bundled Realm database (`quran.realm`) and ~110 MB of page images. Both are
    package resources and are handled automatically — but let Xcode finish indexing before running,
    and expect the first checkout to be large.

### Building and testing

```bash
swift build
swift test --no-parallel
```

**Run the tests serially.** The `--no-parallel` flag is not optional: the suites share singletons
(`RealmService.shared` and the caches), so parallel runs are flaky and silently cover less.

Tests use **swift-testing** (`import Testing`, `@Test`, `#expect`), not XCTest. Please match that in
new tests.

Some eye-tracking tests are recorded as **known issues** — they run, they fail, and the suite stays
green. If one of them starts *passing*, the run fails on purpose: that is the signal the underlying
bug was fixed and the marker should be removed. Never delete a known-issue marker just to make the
suite green.

### Things worth knowing before you send a PR

*   **This is a library.** Every `public` symbol is a contract with apps that already ship. Changing
    or removing a public signature is a breaking change and needs to be called out in the PR.
*   **Realm objects are returned frozen.** Frozen objects cross threads safely; live ones do not.
    Returning an unfrozen object is a latent crash in someone's app.
*   **Logging goes through `AppLogger.shared`** with a category. Please do not add `print`.
*   **User-facing strings** use `String(localized:)` and belong in `Resources/Localizable.xcstrings`.
*   **Platform-specific code** is fenced with `#if canImport(UIKit)` / `#elseif canImport(AppKit)`
    for types, and `#if os(iOS)` for behaviour.
*   **Commit messages** follow [Conventional Commits](https://www.conventionalcommits.org/)
    (`feat:`, `fix:`, `docs:`, `test:`, `ci:`, `refactor:`).

### Project structure

*   `Sources/MushafImad/` — the SwiftUI views (`MushafView`, `MushafTextView`, page views)
*   `Sources/MushafImad/Core/` — models, Realm services, caches, extensions
*   `Sources/MushafImad/AudioPlayer/` — recitation: player coordinator, timing, reciters, views
*   `Sources/MushafImad/EyeTracking/` — **experimental**, opt-in, known-incomplete
*   `Tests/MushafImadSPMTests/` — the test suite
*   `Example/` — a sample app for iOS and macOS

### Build-time tooling

Scripts at the repository root provide reproducible build-time asset generation. They are **not**
shipped inside the package.

| Script | Purpose |
| --- | --- |
| `configure_example_project.sh` | Sets up the Example Xcode project for network access |
| `compose_page_images.swift` | Composites 15 line PNGs per page into 604 full-page images |

#### Composing page images

The package ships 604 × 15 individual line images (`Sources/MushafImad/quran-images/<page>/<line>.png`,
each 1440×232). To generate full-page composites:

```bash
swift compose_page_images.swift
```

Output is written to `Sources/MushafImad/quran-page-images/<page>.png` (1440×3480 RGBA PNG). This
directory is `.gitignore`d because the generated output (~287 MB) is larger than the source line
images (~96 MB) — PNG compression is less effective on larger canvases.

The script is deterministic: running it twice on the same inputs produces byte-identical output.
Generated images preserve the alpha channel required for `.renderingMode(.template)` tinting.

## Code of Conduct

We follow the general principles of Islamic brotherhood/sisterhood: act with kindness, respect, and
patience. Constructive feedback is a gift.

**Jazakum Allahu Khairan** for your time and effort!
