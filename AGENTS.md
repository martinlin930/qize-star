# Player data must survive updates

The user requires every future game update to preserve all existing accounts, password hashes, character names, sessions, and saved progress.

- The persistent store is the existing Supabase project muygvqqohkbexmcpmpyz, with game records in qize_private. Keep the existing project and account identifiers. Render's local filesystem is not persistent player storage.
- Deploying code must never reset or seed production data. Never run database initialization SQL from application startup, build commands, or deployment hooks. Files in database/ document changes; they are not scripts to rerun on every deployment.
- Extend the database with additive migrations. Preserve existing rows, account ownership, password hashes, character names, and timestamps. Do not drop, truncate, recreate, or replace production tables to implement new features.
- Keep old save formats readable when adding chapters, fields, or save versions. Supply defaults for new fields; avoid forcing players to create new accounts or start over.
- Before any migration that could discard data, prepare a recoverable backup and obtain explicit authorization for the actual data removal. Routine feature updates do not authorize deleting player records.
- Verify compatibility with an existing account and an older save after relevant changes. Use temporary test records; only delete the exact test records created for that verification.
- Changing screens or game content must not alter stored data unless the player intentionally performs the corresponding account or save action.
