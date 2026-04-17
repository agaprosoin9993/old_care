package com.guardian.controller;

import com.guardian.config.AuthHelper;
import com.guardian.dto.ApiResponse;
import com.guardian.entity.Reminder;
import com.guardian.entity.SosLog;
import com.guardian.entity.User;
import com.guardian.repository.UserRepository;
import com.guardian.service.ReminderService;
import com.guardian.service.SosService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/child")
@RequiredArgsConstructor
public class ChildController {
    private final UserRepository userRepository;
    private final ReminderService reminderService;
    private final SosService sosService;
    private final AuthHelper authHelper;

    @GetMapping("/elder/location")
    public ResponseEntity<?> getElderLocation(HttpServletRequest request) {
        Long userId = authHelper.getUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("user not found"));
        }

        User user = userOpt.get();
        if (!"child".equals(user.getRole())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("only child can access this api"));
        }

        Long parentId = user.getParentId();
        if (parentId == null) {
            return ResponseEntity.ok(Map.of(
                    "location", "未绑定老人",
                    "latitude", (Object) null,
                    "longitude", (Object) null,
                    "updatedAt", (Object) null
            ));
        }

        Optional<User> elderOpt = userRepository.findById(parentId);
        if (elderOpt.isEmpty()) {
            return ResponseEntity.ok(Map.of(
                    "location", "老人账号不存在",
                    "latitude", (Object) null,
                    "longitude", (Object) null,
                    "updatedAt", (Object) null
            ));
        }

        User elder = elderOpt.get();
        return ResponseEntity.ok(Map.of(
                "location", elder.getLastLocation() != null ? elder.getLastLocation() : "未获取位置",
                "latitude", elder.getLatitude(),
                "longitude", elder.getLongitude(),
                "updatedAt", elder.getLastLocationUpdate()
        ));
    }

    @GetMapping("/elder/sos-logs")
    public ResponseEntity<?> getElderSosLogs(HttpServletRequest request) {
        Long userId = authHelper.getUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("user not found"));
        }

        User user = userOpt.get();
        if (!"child".equals(user.getRole())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("only child can access this api"));
        }

        Long parentId = user.getParentId();
        if (parentId == null) {
            return ResponseEntity.ok(List.of());
        }

        List<SosLog> sosLogs = sosService.getSosLogs(parentId);
        return ResponseEntity.ok(sosLogs);
    }

    @GetMapping("/elder/reminders")
    public ResponseEntity<?> getElderReminders(HttpServletRequest request) {
        Long userId = authHelper.getUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("user not found"));
        }

        User user = userOpt.get();
        if (!"child".equals(user.getRole())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("only child can access this api"));
        }

        Long parentId = user.getParentId();
        if (parentId == null) {
            return ResponseEntity.ok(List.of());
        }

        List<Reminder> reminders = reminderService.getReminders(parentId);
        return ResponseEntity.ok(reminders);
    }

    @GetMapping("/elder/sos-unread-count")
    public ResponseEntity<?> getElderSosUnreadCount(HttpServletRequest request) {
        Long userId = authHelper.getUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("user not found"));
        }

        User user = userOpt.get();
        if (!"child".equals(user.getRole())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("only child can access this api"));
        }

        Long parentId = user.getParentId();
        if (parentId == null) {
            return ResponseEntity.ok(Map.of("count", 0));
        }

        int count = sosService.getUnreadCount(parentId);
        return ResponseEntity.ok(Map.of("count", count));
    }

    @PutMapping("/elder/sos-logs/{sosId}/read")
    public ResponseEntity<?> markSosAsRead(
            @PathVariable Long sosId,
            HttpServletRequest request) {
        Long userId = authHelper.getUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("user not found"));
        }

        User user = userOpt.get();
        if (!"child".equals(user.getRole())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("only child can access this api"));
        }

        sosService.markAsRead(sosId);
        return ResponseEntity.ok(Map.of("success", true));
    }

    @PutMapping("/elder/sos-logs/read-all")
    public ResponseEntity<?> markAllSosAsRead(HttpServletRequest request) {
        Long userId = authHelper.getUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("user not found"));
        }

        User user = userOpt.get();
        if (!"child".equals(user.getRole())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("only child can access this api"));
        }

        Long parentId = user.getParentId();
        if (parentId != null) {
            sosService.markAllAsRead(parentId);
        }
        return ResponseEntity.ok(Map.of("success", true));
    }

    @DeleteMapping("/elder/sos-logs/{sosId}")
    public ResponseEntity<?> deleteSosLog(
            @PathVariable Long sosId,
            HttpServletRequest request) {
        Long userId = authHelper.getUserId(request);
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("unauthorized"));
        }

        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("user not found"));
        }

        User user = userOpt.get();
        if (!"child".equals(user.getRole())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(ApiResponse.error("only child can access this api"));
        }

        Long parentId = user.getParentId();
        if (parentId == null) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("no elder bound"));
        }

        boolean deleted = sosService.deleteSosLog(sosId, parentId);
        if (!deleted) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("cannot delete: not found, not read, or not owned"));
        }
        return ResponseEntity.ok(Map.of("success", true));
    }
}
