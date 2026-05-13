# Syntax-Aware Dictation

_Last updated: 2026-02-02_

## Overview
Syntax-Aware Dictation (Feature 2.1) converts spoken developer intent into properly formatted code-ready text. It runs after base transcription and dictionary corrections but before text injection, so all downstream targets (IDEs, CLIs, editors) receive already formatted output.

Key capabilities:

1. **Case commands** – voice-friendly shortcuts for camelCase, snake_case, PascalCase, kebab-case, CONSTANT_CASE, uppercase, lowercase, and Title Case.
2. **CLI command normalization** – maps phrases like “git commit dash m” or “docker compose up dash d” to their exact terminal equivalents.
3. **Code symbol replacements** – translates verbalized operators, punctuation, and common language keywords into their textual forms (e.g., “fat arrow” → `=>`).

## Processing pipeline
```
SpeechRecognizer → Personal Dictionary → SyntaxTransformer → FileTagger → TextInjectionService
```

* `SyntaxTransformer` lives in `Domain/Services/SyntaxTransformer.swift` and orchestrates the three transformation stages via:
  * `Infrastructure/Syntax/CaseTransformer.swift`
  * `Infrastructure/Syntax/CLIPatternMatcher.swift`
  * `Infrastructure/Syntax/CodePatterns.swift`

## Voice command reference
| Voice phrase | Result | Notes |
|--------------|--------|-------|
| “camel case user profile manager” | `userProfileManager` | Equivalent aliases: “camelcase”, “camel”. |
| “snake case max retry count” | `max_retry_count` | Also accepts “snakecase”. |
| “pascal case session manager” | `SessionManager` | Works for PascalCase / TitleCase style types. |
| “kebab case build target name” | `build-target-name` | Alias: “dash case”. |
| “constant case api timeout seconds” | `API_TIMEOUT_SECONDS` | Alias: “screaming snake”. |
| “upper case environment flag” | `ENVIRONMENT FLAG` | Alias: “all caps”. |
| “lower case environment flag” | `environment flag` | Alias: “no caps”. |
| “title case release notes header” | `Release Notes Header` | Useful for documentation. |

The transformer detects command phrases, consumes them, and applies the requested format to the trailing words up to the next command or punctuation boundary.

## CLI patterns
`CLIPatternMatcher` maintains curated patterns grouped by Git, npm/yarn/pnpm, Docker, and general shell usage. Examples:

- “git commit dash m” → `git commit -m`
- “git checkout dash b” → `git checkout -b`
- “npm install dash dash save dev” → `npm install --save-dev`
- “docker run dash it” → `docker run -it`
- “ls dash la” → `ls -la`

Symbol phrases are processed greedily (longest first) to avoid partial matches: “dash dash” → `--`, “double ampersand” → `&&`, “pipe” → `|`, “dot slash” → `./`, etc.

### Extending CLI patterns
1. Edit `Infrastructure/Syntax/CLIPatternMatcher.swift`.
2. Append to `patterns` with the spoken phrase in lowercase and desired output.
3. Rebuild; no additional wiring is required because the transformer auto-loads the static list.

## Code symbol replacements
`CodePatterns` covers:

- Comparison/assignment operators (`equals`, `double equals`, `not equals`, `plus equals`, …)
- Arithmetic & bitwise operators (`asterisk`, `modulo`, `left shift`, `tilde`, …)
- Brackets and punctuation (`open bracket`, `close brace`, `semicolon`, `ellipsis`, …)
- Special tokens & keywords (`fat arrow`, `line comment`, `doc comment`, `class`, `struct`, `async`, `await`, …)

Replacements use word-boundary matching, so saying “open brace” only inserts `{` when it appears as a standalone phrase.

## Settings
The feature is fully user-tunable via `SettingsStore` (`Application/Stores/SettingsStore.swift`). Relevant flags:

| AppStorage key | Purpose | Default |
|----------------|---------|---------|
| `syntaxTransformEnabled` | Master toggle for Syntax-Aware Dictation. | `true` |
| `caseTransformationsEnabled` | Enables/disables voice case commands. | `true` |
| `cliPatternsEnabled` | Enables CLI command normalization. | `true` |
| `codeSymbolsEnabled` | Enables code symbol replacements. | `true` |

Disabling any sub-feature leaves the others unaffected; the transformer checks each flag before running the respective stage. Settings are read when `AppDependencies` boots and resynchronized before every transcription pass to pick up runtime changes.

## Integration touchpoints
- **Initialization**: `AppDependencies` constructs `SyntaxTransformer` and mirrors the user-configured settings.
- **Transcription pipeline**: After dictionary corrections (`DictionaryManager.applyDictionary`), `SyntaxTransformer.transform` runs if `syntaxTransformEnabled` is true.
- **File tagging**: Runs immediately after syntax transformation; order matters so tags see already-formatted text.

## Testing tips
1. Build/run FnScribe with logging enabled (Xcode → Debug console) to inspect intermediate text states via `appState.updateTranscription`.
2. Speak or paste phrases into a mock pipeline harness to verify transformations without full audio capture.
3. For regression coverage, add unit tests around the pure functions (`CaseTransformer`, `CLIPatternMatcher`, `CodePatterns`). Each component operates purely on strings, making them straightforward to test.

## Future extensions
- **Context-aware delimiters**: e.g., auto-wrap transformed identifiers when dictating structured templates.
- **Custom command macros**: user-defined phrases mapping to bulk transformations.
- **IDE-specific presets**: per-adapter overrides for CLI vs. code editors (e.g., disable CLI patterns inside documentation apps).
