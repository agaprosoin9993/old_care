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
import java.security.SecureRandom;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {
    private final UserRepository userRepository;
    private final SessionRepository sessionRepository;
    private final PasswordEncoder passwordEncoder;
    private static final SecureRandom secureRandom = new SecureRandom();

    private String generateElderId() {
        while (true) {
            // 生成0-999999之间的随机数，确保是6位
            int randomNumber = secureRandom.nextInt(1000000);
            String elderId = String.format("%06d", randomNumber);
            System.out.println(elderId);
            System.out.println();
            System.out.println(randomNumber);
            if (!userRepository.existsByElderId(elderId)) {
                return elderId;
            }
        }
    }

    @Transactional
    public AuthResult register(String username, String password, String displayName, String role, Long parentId) {
        if (userRepository.existsByUsername(username)) {
            throw new RuntimeException("username already exists");
        }

        // Validate parentId if provided for child role
        if ("child".equals(role) && parentId != null) {
            User parentUser = userRepository.findById(parentId)
                    .orElseThrow(() -> new RuntimeException("老人账号ID不存在"));
            if (!"elder".equals(parentUser.getRole())) {
                throw new RuntimeException("指定的ID不是老人账号");
            }
        }

        String passwordHash = passwordEncoder.encode(password);
        User user = new User();
        user.setUsername(username);
        user.setPasswordHash(passwordHash);
        user.setDisplayName(displayName != null ? displayName : "");
        user.setRole(role != null ? role : "elder");
        user.setParentId(parentId);
        
        // Generate 6-digit random unique elderId for elder users
        if ("elder".equals(role)) {
            user.setElderId(generateElderId());
        }
        
        user = userRepository.save(user);

        String token = UUID.randomUUID().toString();
        Session session = new Session();
        session.setToken(token);
        session.setUserId(user.getId());
        sessionRepository.save(session);

        UserInfo userInfo = UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId(), user.getElderId());
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

        UserInfo userInfo = UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId(), user.getElderId());
        return new AuthResult(token, userInfo);
    }

    public Optional<UserInfo> getUserByToken(String token) {
        return sessionRepository.findByToken(token)
                .map(session -> {
                    User user = userRepository.findById(session.getUserId()).orElse(null);
                    if (user == null) return null;
                    return UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId(), user.getElderId());
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

    public Optional<UserInfo> getUserById(Long userId) {
        return userRepository.findById(userId)
                .map(user -> UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId(), user.getElderId()));
    }

    @Transactional
    public UserInfo updateParentId(Long userId, Long parentId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("user not found"));
        
        // 验证 parentId 是否存在且为老人角色
        User parentUser = userRepository.findById(parentId)
                .orElseThrow(() -> new RuntimeException("老人账号ID不存在"));
        if (!"elder".equals(parentUser.getRole())) {
            throw new RuntimeException("指定的ID不是老人账号");
        }
        
        user.setParentId(parentId);
        user = userRepository.save(user);
        
        return UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId(), user.getElderId());
    }

    public record AuthResult(String token, UserInfo user) {}
}
