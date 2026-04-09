package com.guardian.controller;

import com.guardian.config.AuthHelper;
import com.guardian.dto.ApiResponse;
import com.guardian.dto.SosRequest;
import com.guardian.entity.SosLog;
import com.guardian.service.SosService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;

@RestController
@RequestMapping("/sos")
@RequiredArgsConstructor
public class SosController {
    private final SosService sosService;
    private final AuthHelper authHelper;

    @GetMapping
    public ResponseEntity<?> getSosLogs(HttpServletRequest request) {
        Long userId = authHelper.getTargetUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
        List<SosLog> sosLogs = sosService.getSosLogs(userId);
        return ResponseEntity.ok(sosLogs);
    }

    @PostMapping
    public ResponseEntity<?> createSosLog(
            @Valid @RequestBody SosRequest sosRequest,
            HttpServletRequest request) {
        Long userId = authHelper.getTargetUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
        SosLog sosLog = sosService.createSosLog(
                userId,
                sosRequest.getLocation(),
                sosRequest.getContact(),
                sosRequest.getNote()
        );
        return ResponseEntity.status(HttpStatus.CREATED).body(sosLog);
    }
}
