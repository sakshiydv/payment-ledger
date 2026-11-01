package com.example.ledger.repository;

import com.example.ledger.domain.LedgerEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LedgerEntryRepository extends JpaRepository<LedgerEntry, Long> {

    @Query("select coalesce(sum(e.amount), 0) from LedgerEntry e where e.accountId = :accountId")
    long balanceOf(@Param("accountId") Long accountId);

    java.util.List<com.example.ledger.domain.LedgerEntry> findByAccountIdOrderByIdAsc(Long accountId);
}