# deposit-rates worker (dr-1.0.0)

Scrapes published deposit rates from DepositAccounts.com per-bank pages (server-rendered, one page per institution) on a daily cron into D1, and serves them as JSON for the Deposit Command Competitor Rates tab. National benchmark comes from the existing fred-proxy — this worker deliberately doesn't duplicate it.

## Deploy

```bash
wrangler d1 create deposit-rates          # paste database_id into wrangler.toml
wrangler d1 execute deposit-rates --file=schema.sql --remote
wrangler secret put ADMIN_KEY             # optional; protects /refresh and /debug
wrangler deploy
```

First smoke test (SouthState is pre-seeded, cert 33555):

```
GET /debug?slug=south-state-bank&key=...    # parse without storing; check diag block
GET /refresh?slug=south-state-bank&key=...  # store a snapshot
GET /rates?cert=33555                       # what the widget will consume
GET /health                                 # build tag + stalest bank
```

If /debug returns `parse_empty`, the `diag.headings_seen` and `rows_rejected` fields show what the parser saw — the parser keys on heading keywords ("Savings", "Money Market", "CD"...) and %-shaped first cells, not exact markup, so it should survive cosmetic redesigns.

## Adding competitor banks

Slugs are the kebab-case path at `depositaccounts.com/banks/{slug}.html`. Verify each in a browser, then:

```sql
INSERT INTO banks (slug) VALUES ('first-national-bank-of-x');
```

Name and FDIC cert auto-backfill from the first successful scrape. Cert is the Salesforce matching key (`FDIC_Cert_Number__c`), so competitor sets can be driven per-client later.

## National benchmark (fred-proxy, no new plumbing)

FRED mirrors the FDIC National Rates release monthly. Verified series: `SNDR` (savings national rate), `SNDRRCA` (savings rate cap, national rate + 75bps). The siblings follow the same family for interest checking, money market, and each CD tenor plus their `...RCA` cap variants — confirm exact IDs with a quick `fred-proxy /series?id=` probe per product before wiring the widget (a wrong ID fails loudly, so it's a 2-minute check).

## Data caveats (surface these in the widget disclaimer)

- DA states rates are checked daily but may lag the bank's own site; for regionally-priced products they show the region nearest the bank's HQ (rows flagged `regional: true` carried their † marker).
- Anomaly flag: any account whose APY moved >2.00pp between captures gets `anomaly: true` — render with a "verify" treatment rather than hiding.
- History rows accumulate ~1 row/product/bank/day; at 30 banks that's trivial for D1, but a quarterly prune of >18-month history is cheap hygiene.

## The licensing question (before this ships in a paid product)

Fine for an internal prototype and for validating the feature. But Deposit Command is being commercialized with subscription order forms, and DepositAccounts is LendingTree property whose Terms of Use almost certainly prohibit automated collection — repackaging their data into a paid product is a real exposure, not a theoretical one. Two honest paths before launch:

1. **License it.** LendingTree/DA has done data partnerships; their site invites contact about data. A per-seat cost passed into the subscription tiers may be entirely workable.
2. **Shift the scrape target to the banks' own sites** for each client's competitor set (the published rates themselves are facts, and first-party pages avoid the aggregator's ToS) — messier to parse, which is where an LLM-extraction step earns its keep.

The worker's output schema stays identical either way, so the widget doesn't care which path wins.
