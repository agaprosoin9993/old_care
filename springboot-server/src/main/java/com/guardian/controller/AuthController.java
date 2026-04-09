package com.guardian.controller;

import com.guardian.dto.ApiResponse;
import com.guardian.dto.AuthResponse;
import com.guardian.dto.LoginRequest;
import com.guardian.dto.RegisterRequest;
import com.guardian.dto.UserInfo;
import com.guardian.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Optional;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {
    private final AuthService authService;

    @PostMapping("/register")
    public ResponseEntity<?> register(@Valid @RequestBody RegisterRequest request) {
        try {
            AuthService.AuthResult result = authService.register(
                    request.getUsername(),
                    request.getPassword(),
                    request.getDisplayName(),
                    request.getRole(),
                    request.getParentId()
            );
            AuthResponse response = AuthResponse.of(result.token(), result.user());
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (RuntimeException e) {
            if (e.getMessage().equals("username already exists")) {
                return ResponseEntity.status(HttpStatus.CONFLICT)
                        .body(ApiResponse.error("username exists"));
            }
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest request) {
        try {
            AuthService.AuthResult result = authService.login(request.getUsername(), request.getPassword());
            AuthResponse response = AuthResponse.of(result.token(), result.user());
            return ResponseEntity.ok(response);
        } catch (RuntimeException e) {
            if (e.getMessage().equals("invalid credentials")) {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                        .body(ApiResponse.error("invalid_credentials"));
            }
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    @GetMapping("/me")
    public ResponseEntity<?> me(@RequestHeader(value = "Authorization", required = false) String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        String token = authHeader.substring(7);
        Optional<UserInfo> userInfo = authService.getUserByToken(token);
        if (userInfo.isPresent()) {
            return ResponseEntity.ok(userInfo.get());
        } else {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }
    }
}
