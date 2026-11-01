#!/usr/bin/env bash
# Demonstrates idempotency: the SAME Idempotency-Key sent twice must move money only ONCE.
# Correct: attempt 2 returns the SAME transfer, balance moved once (7000).
# Bug:     attempt 2 moves money again, balance moved twice (4000).

BASE=http://localhost:8086
PSQL="/opt/homebrew/opt/postgresql@16/bin/psql"
export PGPASSWORD=shortener

echo "== reset + fund account 1 with 10000 paise (Rs100) =="
$PSQL -h localhost -U shortener -d ledger -c "TRUNCATE ledger_entry, transfer RESTART IDENTITY;" >/dev/null
$PSQL -h localhost -U shortener -d ledger \
  -c "INSERT INTO ledger_entry (account_id, amount, created_at) VALUES (1, 10000, now());" >/dev/null

KEY=$(uuidgen)
echo "== using one Idempotency-Key for BOTH attempts: $KEY =="
echo

echo "== attempt 1: transfer 3000 (Rs30) =="
curl -s -X POST "$BASE/transfers" \
  -H 'Content-Type: application/json' \
  -H "Idempotency-Key: $KEY" \
  -d '{"fromAccountId":1,"toAccountId":2,"amount":3000}'; echo
echo

echo "== attempt 2: SAME key (a retry) — should replay, NOT move money again =="
curl -s -X POST "$BASE/transfers" \
  -H 'Content-Type: application/json' \
  -H "Idempotency-Key: $KEY" \
  -d '{"fromAccountId":1,"toAccountId":2,"amount":3000}'; echo
echo

echo "== balance of account 1  (CORRECT = 7000 = moved once; BUG = 4000 = moved twice) =="
curl -s "$BASE/accounts/1/balance"; echo
echo "== number of transfers in DB  (CORRECT = 1) =="
$PSQL -h localhost -U shortener -d ledger -tc "SELECT count(*) FROM transfer;"
