package com.guardian.controller;

import com.guardian.config.AuthHelper;
import com.guardian.dto.ApiResponse;
import com.guardian.dto.ContactRequest;
import com.guardian.entity.Contact;
import com.guardian.service.ContactService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/contacts")
@RequiredArgsConstructor
public class ContactController {
    private final ContactService contactService;
    private final AuthHelper authHelper;

    @GetMapping
    public ResponseEntity<?> getContacts(HttpServletRequest request) {
        Long userId = authHelper.getTargetUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
        List<Contact> contacts = contactService.getContacts(userId);
        return ResponseEntity.ok(contacts);
    }

    @PostMapping
    public ResponseEntity<?> createContact(
            @Valid @RequestBody ContactRequest contactRequest,
            HttpServletRequest request) {
        Long userId = authHelper.getTargetUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
        Contact contact = contactService.createContact(
                userId,
                contactRequest.getName(),
                contactRequest.getPhone(),
                contactRequest.getRelation()
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(contact);
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> updateContact(
            @PathVariable Long id,
            @Valid @RequestBody ContactRequest contactRequest,
            HttpServletRequest request) {
        Long userId = authHelper.getTargetUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
        try {
            Contact contact = contactService.updateContact(
                    id,
                    userId,
                    contactRequest.getName(),
                    contactRequest.getPhone(),
                    contactRequest.getRelation()
            );
            return ResponseEntity.ok(contact);
        } catch (RuntimeException e) {
            if (e.getMessage().equals("not found")) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(ApiResponse.error("not_found"));
            }
            if (e.getMessage().equals("forbidden")) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(ApiResponse.error("forbidden"));
            }
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteContact(
            @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = authHelper.getTargetUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
        try {
            contactService.deleteContact(id, userId);
            return ResponseEntity.ok(java.util.Map.of("ok", true));
        } catch (RuntimeException e) {
            if (e.getMessage().equals("not found")) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(ApiResponse.error("not_found"));
            }
            if (e.getMessage().equals("forbidden")) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN)
                        .body(ApiResponse.error("forbidden"));
            }
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }
}
