package com.example.ledger.web;

import com.example.ledger.domain.Transfer;
import com.example.ledger.service.TransferService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

@RestController
@RequestMapping("/transfers")
public class TransferController {

    private final TransferService transferService;

    public TransferController(TransferService transferService) {
        this.transferService = transferService;
    }

    @PostMapping
    public ResponseEntity<Transfer> transfer(
            @RequestHeader("Idempotency-Key") String idempotencyKey,
            @RequestBody TransferRequest request) {
        Transfer transfer = transferService.transfer(
                idempotencyKey, request.fromAccountId(), request.toAccountId(), request.amount());
        return ResponseEntity.status(HttpStatus.CREATED).body(transfer);
    }

    @GetMapping("/{id}")
    public Transfer get(@PathVariable Long id) {
        return transferService.getTransfer(id);
    }

    public record TransferRequest(Long fromAccountId, Long toAccountId, long amount) {
    }
}
