# iOS experience update implementation plan

Goal: implement the approved 17 requirements in the existing iOS app.

Architecture: retain the v1 SQL schema and add a v2 metadata migration for structured semesters and subject identities; preserve compatibility with old archives. Share derived, read-only snapshots with WidgetKit. Reuse the verified backup codec for iCloud documents.

Tech stack: Swift 6, GRDB, SwiftUI / Charts / WidgetKit, XcodeGen, existing XLSX/backup codecs.

- [x] Add regression tests for the 32-term catalog, subject-only inheritance, stage isolation, full-data per-subject statistics, multi-user enforcement, and backup round trips.
- [x] Attempt the Docker Swift test command; Docker engine unavailable due to an existing socket error. Use authenticated macOS CI for the actual Swift and iOS test runs.
- [x] Implement Domain/SchoolTerm.swift and Data/Database/SchoolStore.swift; add the v2 migration and metadata restore in StudyStore.swift; preserve old snapshot decoding with optional fields.
- [x] Add a shared profile form / term picker; use in onboarding and user/semester management. Keep the primary action in the form and persist avatar with profile creation.
- [x] Add typed appearance preferences using the existing platformExtensions dictionary, color validation, native glass surfaces, wallpaper contrast and gradient top blur.
- [x] Merge navigation into four tabs; replace analysis with full-data grouped charts and expandable records, preserving editing, deleting, search and entry actions. Add progressive chart reveal and reduced-motion behavior.
- [x] Add per-subject home summaries and leading swipe deletion with undo.
- [x] Broaden XLSX picker types with content validation and imported-type declarations; add standard-term mapping before import.
- [x] Add iCloud document backup service and backup management UI with coordinated IO, download state, validation and restore preview.
- [x] Add configurable home/lock widgets with atomic App Group snapshots, privacy handling and deep links; embed extension and signing configurations.
- [x] Run core regression suite, SQL contracts and configuration checks; build app and extension on macOS; validate all three simulator targets and inspect final screenshots. Record actual results and remaining signed-device checks in docs/ios-2026-10-15-update.md.
