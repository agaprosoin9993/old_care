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

    @GetMapping("/users/{id}")
    public ResponseEntity<?> getUserById(@PathVariable Long id, @RequestHeader(value = "Authorization", required = false) String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        Optional<UserInfo> userInfo = authService.getUserById(id);
        if (userInfo.isPresent()) {
            return ResponseEntity.ok(userInfo.get());
        } else {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.error("user not found"));
        }
    }

    @PutMapping("/bind-elder")
    public ResponseEntity<?> bindElder(@RequestHeader(value = "Authorization", required = false) String authHeader, @RequestParam Long elderId) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        String token = authHeader.substring(7);
        Optional<Long> userIdOpt = authService.getUserIdByToken(token);
        if (!userIdOpt.isPresent()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        try {
            // 调用 AuthService 中的方法来更新用户的 parentId
            UserInfo updatedUser = authService.updateParentId(userIdOpt.get(), elderId);
            return ResponseEntity.ok(ApiResponse.success(updatedUser, "绑定成功"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    @PutMapping("/unbind-elder")
    public ResponseEntity<?> unbindElder(@RequestHeader(value = "Authorization", required = false) String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        String token = authHeader.substring(7);
        Optional<Long> userIdOpt = authService.getUserIdByToken(token);
        if (!userIdOpt.isPresent()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        try {
            UserInfo updatedUser = authService.unbindElder(userIdOpt.get());
            return ResponseEntity.ok(ApiResponse.success(updatedUser, "解绑成功"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }

    @PutMapping("/update-location")
    public ResponseEntity<?> updateLocation(
            @RequestHeader(value = "Authorization", required = false) String authHeader,
            @RequestBody java.util.Map<String, String> body) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        String token = authHeader.substring(7);
        Optional<Long> userIdOpt = authService.getUserIdByToken(token);
        if (!userIdOpt.isPresent()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        try {
            String location = body.get("location");
            UserInfo updatedUser = authService.updateLocation(userIdOpt.get(), location);
            return ResponseEntity.ok(ApiResponse.success(updatedUser, "位置更新成功"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(ApiResponse.error(e.getMessage()));
        }
    }
}
