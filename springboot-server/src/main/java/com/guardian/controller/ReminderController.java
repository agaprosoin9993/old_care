package com.guardian.controller;

import com.guardian.config.AuthHelper;
import com.guardian.dto.ApiResponse;
import com.guardian.dto.ReminderRequest;
import com.guardian.entity.Reminder;
import com.guardian.service.ReminderService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/reminders")
@RequiredArgsConstructor
public class ReminderController {
    private final ReminderService reminderService;
    private final AuthHelper authHelper;

    @GetMapping
    public ResponseEntity<?> getReminders(HttpServletRequest request) {
        Long userId = authHelper.getTargetUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
        List<Reminder> reminders = reminderService.getReminders(userId);
        return ResponseEntity.ok(reminders);
    }

    @PostMapping
    public ResponseEntity<?> createReminder(
            @Valid @RequestBody ReminderRequest reminderRequest,
            HttpServletRequest request) {
        Long userId = authHelper.getTargetUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
        Reminder reminder = reminderService.createReminder(
                userId,
                reminderRequest.getTitle(),
                reminderRequest.getTime(),
                reminderRequest.getRepeating(),
                reminderRequest.getCompleted()
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(reminder);
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> updateReminder(
            @PathVariable Long id,
            @Valid @RequestBody ReminderRequest reminderRequest,
            HttpServletRequest request) {
        Long userId = authHelper.getTargetUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
        try {
            Reminder reminder = reminderService.updateReminder(
                    id,
                    userId,
                    reminderRequest.getTitle(),
                    reminderRequest.getTime(),
                    reminderRequest.getRepeating(),
                    reminderRequest.getCompleted()
            );
            return ResponseEntity.ok(reminder);
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
    public ResponseEntity<?> deleteReminder(
            @PathVariable Long id,
            HttpServletRequest request) {
        Long userId = authHelper.getTargetUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
        try {
            reminderService.deleteReminder(id, userId);
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
