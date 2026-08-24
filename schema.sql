-- deposit-rates D1 schema
-- wrangler d1 execute deposit-rates --file=schema.sql --remote

CREATE TABLE IF NOT EXISTS banks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug TEXT NOT NULL UNIQUE,          -- depositaccounts.com/banks/{slug}.html
  name TEXT,                          -- filled from scrape if null
  cert INTEGER,                       -- FDIC cert #, filled from scrape if null
  active INTEGER NOT NULL DEFAULT 1,
  added_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- One row per product per scrape (history preserved for trends/alerts)
CREATE TABLE IF NOT EXISTS rates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bank_id INTEGER NOT NULL REFERENCES banks(id),
  category TEXT NOT NULL,             -- savings | mma | checking | cd | ira
  account_name TEXT NOT NULL,
  apy REAL NOT NULL,
  min_deposit TEXT,                   -- as displayed: "$1k", "$0", "$100k"
  max_deposit TEXT,
  tiers TEXT,                         -- JSON array of {apy,min,max} for OTHER TIERS rows
  regional INTEGER NOT NULL DEFAULT 0,-- carried the † (varies by region) flag
  anomaly INTEGER NOT NULL DEFAULT 0, -- >2.00pp jump vs previous capture
  captured_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rates_bank_cap ON rates(bank_id, captured_at);
CREATE INDEX IF NOT EXISTS idx_rates_lookup ON rates(bank_id, category, account_name, captured_at);

CREATE TABLE IF NOT EXISTS scrape_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bank_id INTEGER REFERENCES banks(id),
  status TEXT NOT NULL,               -- ok | http_error | parse_empty | exception
  detail TEXT,
  rows_found INTEGER NOT NULL DEFAULT 0,
  ran_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Seed: SouthState as the parser test target + example competitor set.
-- Slugs are kebab-case; verify each at depositaccounts.com/banks/{slug}.html before adding.
INSERT OR IGNORE INTO banks (slug, name) VALUES
  ('south-state-bank', 'SouthState Bank');
