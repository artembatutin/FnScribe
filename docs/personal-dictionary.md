# Personal dictionary and sentence refinement

Open **Settings → Dictionary** to manage vocabulary and text cleanup. These settings
apply to final dictation; the live speech preview remains a direct transcription.

## Settings

| Setting | Default | Behavior |
| --- | --- | --- |
| Enable Dictionary | On | Apply saved spoken → written replacements and enable vocabulary learning. |
| Auto-Learn | On | Learn a related spelling correction when you copy an edited version of the injected dictation within 30 seconds. |
| Suggest unusual words | On | Collect unfamiliar words for review in the Suggestions tab. Requires Enable Dictionary. |
| Refine sentences | Off | Correct grammar locally; add Apple Intelligence sentence rewriting when available. Independent of the dictionary toggle. |

Turning refinement off passes the transcript through without calling either cleanup
engine. Existing dictionary, code-formatting, file-tagging, and snippet settings still
apply independently. Task commands keep their existing parsing and skip refinement.

## Vocabulary suggestions

FnScribe checks final transcripts with the macOS spelling service, using the detected
speech language when its spelling dictionary is installed. Unrecognized words can be
names, specialist terminology, or transcription mistakes; they are offered for review.
URLs, email addresses, paths, inline code, and already-known vocabulary are excluded.

In **Suggestions**, each word includes its recent context, occurrence count, and an
editable suggested spelling:

- **Add correction** saves the heard word → the spelling you entered.
- **Keep spelling** saves the word as vocabulary without changing its spelling.
- **Ignore** dismisses it and suppresses future suggestions for that word.

The app retains up to 100 suggestions locally. The overflow menu can clear suggestions
and reset ignored words. Suggestions and ignored words are saved separately in
`~/Library/Application Support/FnScribe/dictionary_suggestions.json`; they are not
included in dictionary exports.

## Replacements and correction learning

Saved entries use the existing `dictionary.json` format and remain importable/exportable.
The longest matching phrase wins. Matching respects Unicode word boundaries and supports
terms such as `C++`, multiword phrases, and literal dollar signs or backslashes in the
written form. Replacements do not trigger further replacements within the same pass.
Usage counts update once per entry used in a dictation.

Correction learning begins only after successful text insertion. Copy the corrected
sentence within 30 seconds. A shared surrounding context and related spelling are
required, including corrections that join or split a short phrase, such as
“super base” → “Supabase”. Technical capitalization, such as “javascript” → “JavaScript”,
can also be learned. Unrelated copies, changed quantities, and broad rewrites are rejected.
Simply editing another app does not expose the edit to FnScribe; copying the corrected
text is necessary. Turning the dictionary or auto-learning off stops monitoring.

## Sentence refinement

The local grammar layer applies corrections offered by macOS and repairs common English
dictation issues such as repeated function words, subject/verb agreement, and missing
“be” in phrases such as “can toggled”. Its repairs are intentionally limited.

On macOS 26 or later, an eligible Mac with Apple Intelligence enabled and its language
model ready also gets sentence rewriting for broken sentence structure and flow. The
status in Settings reports the current availability; **Refresh** checks it again after
changing system settings. No account, API key, external server, or cloud fallback is used.

Refinement runs after dictionary replacements and before code formatting, file tagging,
and snippet expansion. Dictionary spellings, reviewed/flagged vocabulary, numbers,
negations, code identifiers, URLs, email addresses, paths, and inline code are protected.
A rewrite that changes protected content is discarded in favor of grammar correction.
If the model is unavailable, rejects a request, times out, or receives an overly long
input, macOS grammar correction still runs. Language-model output can still be imperfect;
the toggle allows you to keep the original speech wording whenever preferred.

## Verification

`DictionaryAndRefinementTests` covers literal/Unicode replacements, suggestion persistence,
approval and ignoring, correction learning, exact toggle-off behavior, native spelling
and grammar, current model availability, timeout/error fallback, and protected content.
Run the regular `FnScribeTests` scheme. Native spelling/grammar tests need access to the
macOS spelling service and should run outside a restricted execution sandbox.
