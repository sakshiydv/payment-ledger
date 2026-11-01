#!/usr/bin/env bash
# Payment Ledger — quick test script.
# Run everything:      bash test.sh
# Or copy any single curl line below into your terminal and tweak it.
# Edit the values (owner, id, amount) here and re-run — this is your one test file.

BASE=http://localhost:8086
ID=1

echo "== 1. create account =="
curl -s -X POST "$BASE/accounts" \
  -H 'Content-Type: application/json' \
  -d '{"owner":"Asha","currency":"INR"}'
echo; echo

echo "== 2. get account $ID =="
curl -s "$BASE/accounts/$ID"
echo; echo

echo "== 3. balance of account $ID =="
curl -s "$BASE/accounts/$ID/balance"
echo; echo

echo "== 4. missing account (expect 404) =="
curl -s -o /dev/null -w "HTTP %{http_code}\n" "$BASE/accounts/999"
