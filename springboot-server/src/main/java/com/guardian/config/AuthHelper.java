package com.guardian.config;

import com.guardian.dto.UserInfo;
import com.guardian.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Optional;

@Component
@RequiredArgsConstructor
public class AuthHelper {
    private final AuthService authService;

    public Long getUserId(HttpServletRequest request) {
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return null;
        }

        String token = authHeader.substring(7);
        return authService.getUserIdByToken(token).orElse(null);
    }

    public Optional<UserInfo> getUserInfo(HttpServletRequest request) {
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return Optional.empty();
        }

        String token = authHeader.substring(7);
        return authService.getUserByToken(token);
    }

    public Long getTargetUserId(HttpServletRequest request) {
        Optional<UserInfo> userInfo = getUserInfo(request);
        if (userInfo.isEmpty()) {
            return null;
        }

        UserInfo info = userInfo.get();
        if ("elder".equals(info.getRole())) {
            return info.getId();
        } else if ("child".equals(info.getRole())) {
            return info.getParentId();
        }
        return null;
    }
}
