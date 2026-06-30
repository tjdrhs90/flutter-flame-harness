# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems (leaked credentials, unsafe credential
handling, a template that could commit secrets, etc.).

Instead, report privately via GitHub's **"Report a vulnerability"** button on the repository's
**Security** tab, or email the maintainer listed in [`.claude-plugin/plugin.json`](.claude-plugin/plugin.json).
You'll get an acknowledgement, and a fix will be coordinated before public disclosure.

## Credential policy

**Credentials and secrets never enter this repository.** This is a hard rule, enforced two ways:

- The repo `.gitignore` excludes `credentials/`, `secrets/`, `*.jks`, `*.p8`, `*.p12`,
  `key.properties`, `play-store-key.json`, and key `*.json` files.
- Every generated game appends `templates/gitignore.template`, which excludes the same key material
  the build phase copies into the game (`.p8`, `.jks`, `play-store-key.json`, `key.properties`,
  `ios/fastlane/certs/`, `**/google-services.json`).
- `scripts/validate.sh` fails if any developer identity or credential value leaks into tracked files.

Developer/store identity (names, emails, signing IDs) lives only in the user's own
`<credentials_dir>/store-metadata.md` (gitignored), or is collected interactively at bootstrap — it is
never hard-coded into skills, docs, or templates.

## If a secret is accidentally committed

1. Treat it as compromised — **rotate it immediately** (new ASC API key, new upload keystore, etc.).
2. Remove it from the working tree and, if it was pushed, purge it from history
   (`git filter-repo`) and force-push.
3. Report it (see above) so we can check for exposure.

## Out of scope

Vulnerabilities in Flutter, Flame, or third-party dependencies belong to their respective
maintainers — please report them upstream.
