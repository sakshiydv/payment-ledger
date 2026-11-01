package com.example.ledger.service;

import com.example.ledger.domain.LedgerEntry;
import com.example.ledger.domain.Transfer;
import com.example.ledger.domain.TransferStatus;
import com.example.ledger.repository.AccountRepository;
import com.example.ledger.repository.LedgerEntryRepository;
import com.example.ledger.repository.TransferRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.Optional;

@Service
public class TransferService {

    private final AccountRepository accountRepository;
    private final LedgerEntryRepository ledgerEntryRepository;
    private final TransferRepository transferRepository;

    public TransferService(AccountRepository accountRepository,
                           LedgerEntryRepository ledgerEntryRepository,
                           TransferRepository transferRepository) {
        this.accountRepository = accountRepository;
        this.ledgerEntryRepository = ledgerEntryRepository;
        this.transferRepository = transferRepository;
    }

    @Transactional
    public Transfer transfer(String idempotencyKey, Long fromAccountId, Long toAccountId, long amount) {
        // IDEMPOTENCY: if we've already processed this key, replay the original result.
        Optional<Transfer> existing = transferRepository.findByIdempotencyKey(idempotencyKey);
        if (existing.isPresent()) {
            return existing.get();
        }

        if (amount <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "amount must be positive");
        }
        if (fromAccountId.equals(toAccountId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "cannot transfer to the same account");
        }

        long firstToLock = Math.min(fromAccountId, toAccountId);
        long secondToLock = Math.max(fromAccountId, toAccountId);
        accountRepository.findByIdForUpdate(firstToLock)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "account " + firstToLock + " not found"));
        accountRepository.findByIdForUpdate(secondToLock)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "account " + secondToLock + " not found"));

        long balance = ledgerEntryRepository.balanceOf(fromAccountId);
        if (balance < amount) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "insufficient funds");
        }

        Transfer transfer = transferRepository.save(
                new Transfer(idempotencyKey, fromAccountId, toAccountId, amount, TransferStatus.COMPLETED));
        ledgerEntryRepository.save(new LedgerEntry(fromAccountId, -amount, transfer.getId()));
        ledgerEntryRepository.save(new LedgerEntry(toAccountId, amount, transfer.getId()));
        return transfer;
    }

    @Transactional(readOnly = true)
    public Transfer getTransfer(Long id) {
        return transferRepository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "transfer not found"));
    }

}
