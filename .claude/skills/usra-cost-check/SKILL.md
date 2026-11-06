---
name: usra-cost-check
description: Check what a Usra feature costs at 5,000 users before designing, building or merging it. Use for any feature that adds a backend call, SMS, push, AI or LLM call, file upload, cloud storage, third-party SDK or paid API, and whenever someone asks what something costs or whether it stays free.
---

# Usra cost check

Usra's goal: everything is free for the first 5,000 users, and running it costs us $0 a month. A feature that breaks this needs the founder's approval before any work starts.

## Steps

1. List everything the feature calls or stores outside the phone. If it's nothing, the verdict is FREE and you're done.
2. For each item, estimate monthly use at 5,000 users. Write the assumption next to the number: calls per user, size per user.
3. Compare with the free limits below. Open the pricing page and confirm a price first when it decides the verdict or the table is over 3 months old.
4. Also work out the cost at 50,000 users, so nothing surprises us later.
5. Give one verdict, with the numbers:
   - FREE: runs on the phone, or stays under 60% of every free limit.
   - TIGHT: over 60% of a free limit. Say which limit, and when it would run out.
   - COSTS MONEY: any paid usage. Say the monthly cost, then the cheapest free alternative.
6. For COSTS MONEY or TIGHT, stop and ask the founder before building. Never turn on a paid service, or add an API key for one, without a clear yes.

Put the verdict in the PR description.

## Free by design: prefer these

- Anything on the phone: encrypted database, photos, local notifications, on-device ML Kit, PDFs.
- Backup to a folder the user chooses or a place they send it, as an encrypted file. Never iCloud Drive for health data (Apple 5.1.3).
- Firebase Cloud Messaging for push.
- GitHub Actions on this public repo.

## Prices (checked 2026-11-06)

| Service | Free | Paid |
| --- | --- | --- |
| [Supabase](https://supabase.com/pricing) | 50,000 MAU, 500 MB database, 1 GB files, 5 GB egress, 500,000 function calls. Pauses after 1 week without activity | Pro from $25 a month |
| [Twilio SMS to Egypt](https://www.twilio.com/en-us/sms/pricing/eg) | None | $0.3959 per segment |
| Unifonic SMS | None | Get a quote |
| [Claude Sonnet 5.5](https://platform.claude.com/docs/en/about-claude/pricing) | None | $2 input, $10 output per million tokens |
| [Claude Haiku 5.5](https://platform.claude.com/docs/en/about-claude/pricing) | None | $0.10 input, $0.50 output per million tokens, for prompts up to 100,000 tokens |
| [RevenueCat](https://www.revenuecat.com/pricing/) | Up to $2,500 tracked revenue a month | 1% of tracked revenue above that |
| Store accounts | None | Google Play $25 once, Apple $99 a year. Fixed, not per user |

## Traps at 5,000 users

- **SMS codes:** one code per user is about $1,980 at the Twilio price, and it recurs with new phones and retries. Prefer Google or Apple sign-in, or no account.
- **Files:** 1 GB shared by 5,000 users is 200 KB each, less than one photo. Don't sync photos on the free plan.
- **Database:** 500 MB shared by 5,000 users is 100 KB each.
- **Function calls:** 500,000 a month is 100 calls per user. Don't poll.
- **AI:** every call costs money. Never free and unlimited: use on-device features, or paid credits.
- **Free plan backups:** check whether the plan includes database backups before storing anything people can't recreate.
