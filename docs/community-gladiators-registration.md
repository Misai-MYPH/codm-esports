# Community Gladiators native registration (development)

Preview page: `community-gladiators.html?tournament=community-gladiators-dec-2026`

This is an **unreleased MVP** on the feature branch. It does not replace `register.html` or the live Google Form.

## Installation
1. Review and apply `supabase/migrations/20261119_community_gladiators_registration.sql` to the existing CODM Supabase project.
2. Enable Supabase Auth email OTP / magic-link and allow the deployment URL in Auth redirect settings.
3. Host the branch preview on an authorized test domain. Do not publish participant registration until privacy and admin workflows have been tested.
4. Verify tournament slug and rules against the event's actual approved configuration before launch.

## Included
- Email-authenticated submission to a security-definer RPC; client has no direct INSERT privileges.
- PH Messenger / MYSG WhatsApp contacts; four divisions; exact roster sizes (1/4/1/5).
- Separate tables, RLS self-read, pending status, and duplicate UID/Open ID constraints per tournament and division.
- Rulebook and accuracy declarations.

## Not yet implemented
- Discord OAuth verification or server-side Discord role assignment. A typed username is **not verified**.
- Private image uploads (player photos, team logo); the optional logo URL is not a verified uploaded image.
- Admin approval UI for these new tables; existing `admin_teams.html` does not automatically handle them.
- CAPTCHA/rate limiting, privacy notice and retention schedule, and final organizer acceptance tests.
- Tournament-specific configuration managed by admin (currently slug via URL; deployment should constrain allowed tournaments).
- Existing registrations in Google Forms are not migrated.

Do not merge into main or announce registration live until these items are addressed.
