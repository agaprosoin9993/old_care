package com.guardian.service;

import com.guardian.dto.UserInfo;
import com.guardian.entity.Session;
import com.guardian.entity.User;
import com.guardian.repository.SessionRepository;
import com.guardian.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {
    private final UserRepository userRepository;
    private final SessionRepository sessionRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public AuthResult register(String username, String password, String displayName, String role, Long parentId) {
        if (userRepository.existsByUsername(username)) {
            throw new RuntimeException("username already exists");
        }

        String passwordHash = passwordEncoder.encode(password);
        User user = new User();
        user.setUsername(username);
        user.setPasswordHash(passwordHash);
        user.setDisplayName(displayName != null ? displayName : "");
        user.setRole(role != null ? role : "elder");
        user.setParentId(parentId);
        user = userRepository.save(user);

        String token = UUID.randomUUID().toString();
        Session session = new Session();
        session.setToken(token);
        session.setUserId(user.getId());
        sessionRepository.save(session);

        UserInfo userInfo = UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId());
        return new AuthResult(token, userInfo);
    }

    @Transactional
    public AuthResult register(String username, String password, String displayName) {
        return register(username, password, displayName, "elder", null);
    }

    @Transactional
    public AuthResult login(String username, String password) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("invalid credentials"));

        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            throw new RuntimeException("invalid credentials");
        }

        String token = UUID.randomUUID().toString();
        Session session = new Session();
        session.setToken(token);
        session.setUserId(user.getId());
        sessionRepository.save(session);

        UserInfo userInfo = UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId());
        return new AuthResult(token, userInfo);
    }

    public Optional<UserInfo> getUserByToken(String token) {
        return sessionRepository.findByToken(token)
                .map(session -> {
                    User user = userRepository.findById(session.getUserId()).orElse(null);
                    if (user == null) return null;
                    return UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId());
                });
    }

    public Optional<Long> getUserIdByToken(String token) {
        return sessionRepository.findByToken(token)
                .map(Session::getUserId);
    }

    @Transactional
    public void logout(String token) {
        sessionRepository.deleteByToken(token);
    }

    public record AuthResult(String token, UserInfo user) {}
}
