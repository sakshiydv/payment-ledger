#!/usr/bin/env bash
# Demonstrates the concurrency bug in the NAIVE transfer.
# Funds account 1 with Rs100, then fires 30 concurrent Rs10 transfers to account 2.
# Correct behaviour: exactly 10 succeed, final balance = 0.
# Buggy behaviour:   many more succeed, final balance goes NEGATIVE (overdraft).

BASE=http://localhost:8086
PSQL="/opt/homebrew/opt/postgresql@16/bin/psql"
export PGPASSWORD=shortener

echo "== reset ledger to a clean slate =="
$PSQL -h localhost -U shortener -d ledger -c "TRUNCATE ledger_entry, transfer RESTART IDENTITY;" >/dev/null

echo "== fund account 1 with 10000 paise (Rs100) =="
$PSQL -h localhost -U shortener -d ledger \
  -c "INSERT INTO ledger_entry (account_id, amount, created_at) VALUES (1, 10000, now());" >/dev/null

echo "== firing 30 concurrent transfers of 1000 paise (Rs10) each: 1 -> 2 =="
for i in $(seq 1 30); do
  curl -s -o /dev/null -X POST "$BASE/transfers" \
    -H 'Content-Type: application/json' \
    -H "Idempotency-Key: $(uuidgen)" \
    -d '{"fromAccountId":1,"toAccountId":2,"amount":1000}' &
done
wait
echo "all 30 fired."
echo

echo "== final balance of account 1  (CORRECT = 0, BUG = negative) =="
curl -s "$BASE/accounts/1/balance"; echo
echo
echo "== number of COMPLETED transfers  (CORRECT = 10, BUG = more) =="
$PSQL -h localhost -U shortener -d ledger -tc "SELECT count(*) FROM transfer WHERE status='COMPLETED';"
