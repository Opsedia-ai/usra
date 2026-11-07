# Usra

Arabic-first family medical records app. Flutter app in `app/`, optional Supabase backend in `supabase/`. Product plan: `docs/prd-v1.md` and `docs/product-definition.md`. Security rules: `docs/security.md`.

## Cost rule

The free goal is about what users get: everything stays free for the first 5,000 users.

Approved fixed running cost (founder, 7 Nov 2026): Supabase Pro, about $25 a month, from the moment real member numbers exist, because they can't be recreated and Free has no backups (until then nothing runs); the Apple Developer account; and the Google Play account.

Before designing, building or merging any feature, check whether it costs money, using the `usra-cost-check` skill. Put the verdict and numbers in the PR description.

Any other paid use still needs asking: if a feature would cost money or come close to a free limit, stop and ask the founder first. Never turn on a paid service, or add an API key for one, without a clear yes.
