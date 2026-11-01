# Idempotent Payment Ledger

A money-movement API built to demonstrate the thing that separates people who've *read* about ACID
from people who've had to defend a balance that must **never**, under any retry or race, be wrong.

The surface looks like CRUD — "move ₹X from account A to account B." The engineering is in guaranteeing
three invariants under concurrency and unreliable clients:

1. **A balance never goes negative.**
2. **Every payment is applied exactly once** — even if the client retries.
3. **The books always balance** — every debit has an equal credit.

**Stack:** Java 17 · Spring Boot 3 · PostgreSQL

---

## The core idea

Money is stored as a **double-entry ledger**, not a mutable balance column. Every transfer writes **two
immutable rows** — a debit (`−amount`) on the sender and an equal credit (`+amount`) on the receiver — and a
balance is **derived by summing** an account's entries. Because every debit has a matching credit, the whole
ledger always sums to zero, so corruption is *detectable* instead of silent.

Two independent protections guard the money (they solve different problems — don't conflate them):

| Protection | Problem it solves |
|---|---|
| **Row locking** (`SELECT … FOR UPDATE`) | Two *different* transfers running at once overdrawing an account |
| **Idempotency key** (+ unique constraint) | The *same* transfer retried after a timeout being applied twice |

---

## Architecture

```
  POST /accounts                 AccountController -> AccountRepository -> account
  POST /transfers                TransferController -> TransferService (@Transactional)
    Idempotency-Key: <key>                              |
    { fromAccountId, toAccountId, amount }              | 1. idempotency check (replay if key seen)
                                                        | 2. lock both accounts (ascending id order)
                                                        | 3. derive balance = SUM(entries); reject if < amount
                                                        | 4. write transfer row + two ledger_entry rows
                                                        v
                                       PostgreSQL: account, transfer, ledger_entry
  GET /accounts/{id}/balance     -> SUM(ledger_entry.amount)  (derived, never stored)
  GET /accounts/{id}/entries     -> the raw debit/credit rows (double-entry, visible)
```

---

## Design decisions (and their trade-offs)

- **Double-entry, append-only.** Auditable and self-checking; never `UPDATE`/`DELETE` an entry.
  *Trade-off:* balance is a `SUM`, not a column read — optimized later with a materialized balance.
- **Money as integer paise (`long`), never floating point.** `0.1 + 0.2 != 0.3` makes `double` unusable
  for money.
- **Derived balance.** Always the truth of recorded history; can't silently drift.
- **Pessimistic row locking** to serialize transfers per account, **locked in a consistent (ascending id)
  order** to avoid deadlocks when two transfers touch the same pair of accounts in opposite directions.
  *Trade-off:* a hot account becomes a bottleneck — the price of correctness where money moves.
- **Idempotency key required on every transfer**, checked first (replay) and backed by a **unique
  constraint** so the database — not an application `if` — guarantees exactly-once.
- **`@Transactional`** wraps the transfer so the transfer row + both entries commit all-or-nothing
  (atomicity). Default isolation is `READ COMMITTED`; correctness under concurrency comes from the explicit
  locking (with `SERIALIZABLE` as the alternative).

---

## The trap, and the fix (with real numbers)

The naïve transfer does `read balance → check → insert` as three separate steps. That's a
**lost-update / read-then-write race**: under concurrency, many requests read the same balance *before* any
writes its debit, so they all pass the check and overdraw the account.

Demonstrated with a load test — fund an account with **₹100**, fire **30 concurrent ₹10 transfers**:

| | Naïve | Fixed (row lock) |
|---|---|---|
| Final balance | **−5000** (−₹50, overdrawn) | **0** |
| Transfers completed | **15** | **10** |

And idempotency — the same `Idempotency-Key` sent twice:

| | Result |
|---|---|
| Both attempts | return the **same** transfer id (replay) |
| Balance moved | **once** (₹30, not ₹60) |
| Transfers in DB | **1** |

---

## Data model

`account` — `id`, `owner`, `currency`, `created_at`.
`transfer` — `id`, `idempotency_key` (unique), `from_account_id`, `to_account_id`, `amount` (paise),
`status` (COMPLETED/FAILED enum), `created_at`.
`ledger_entry` (append-only) — `id`, `account_id`, `amount` (signed paise), `transfer_id`, `created_at`.

Balance of an account = `SUM(ledger_entry.amount WHERE account_id = ?)`.

---

## API

| Method & path | Purpose | Notes |
|---|---|---|
| `POST /accounts` | create an account | `{ owner, currency }` → `201` |
| `GET /accounts/{id}` | fetch an account | `404` if missing |
| `GET /accounts/{id}/balance` | derived balance | `{ accountId, balance }` |
| `GET /accounts/{id}/entries` | the account's ledger rows | shows debits/credits |
| `POST /transfers` | move money | requires `Idempotency-Key` header; `422` on insufficient funds |
| `GET /transfers/{id}` | fetch a transfer | `404` if missing |

---

## Running locally

Requires PostgreSQL (a `ledger` database owned by user `shortener`) — see `application.yml`. The app runs on
port **8086**.

```bash
bash run.sh        # starts the app on Java 17
```

Helper scripts:
- `test.sh` — basic account + balance + transfer smoke test.
- `break.sh` — fires 30 concurrent transfers to demonstrate/verify the concurrency behaviour.
- `idempotency.sh` — sends the same idempotency key twice to verify safe retries.

---

## Roadmap / known limitations

- [ ] Gracefully replay a *concurrent* duplicate (catch the unique-key violation and return the existing transfer).
- [ ] Validate currency match; reject cross-currency transfers.
- [ ] Fingerprint the request body against the idempotency key (reject key reuse with a different payload).
- [ ] Materialized/cached balance for scale; partition/archive `ledger_entry`.
- [ ] Concurrency tests in the automated suite.
