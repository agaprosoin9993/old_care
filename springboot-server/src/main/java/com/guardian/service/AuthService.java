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

        Long actualParentId = null;
        
        // Validate parentId if provided for child role
        // parentId实际上是老人的elderId（6位字符串），需要转换为老人的数据库ID
        if ("child".equals(role) && parentId != null) {
            // 将Long转换为String（elderId是6位字符串）
            String elderId = String.format("%06d", parentId);
            User parentUser = userRepository.findByElderId(elderId)
                    .orElseThrow(() -> new RuntimeException("老人账号ID不存在"));
            if (!"elder".equals(parentUser.getRole())) {
                throw new RuntimeException("指定的ID不是老人账号");
            }
            // 使用老人的数据库ID作为parentId
            actualParentId = parentUser.getId();
        }

        String passwordHash = passwordEncoder.encode(password);
        User user = new User();
        user.setUsername(username);
        user.setPasswordHash(passwordHash);
        user.setDisplayName(displayName != null ? displayName : "");
        user.setRole(role != null ? role : "elder");
        user.setParentId(actualParentId);
        
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
    public UserInfo updateParentId(Long userId, Long elderId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("user not found"));
        
        // elderId实际上是老人的elderId（6位字符串），需要转换为字符串后查找
        String elderIdStr = String.format("%06d", elderId);
        User parentUser = userRepository.findByElderId(elderIdStr)
                .orElseThrow(() -> new RuntimeException("老人账号ID不存在"));
        if (!"elder".equals(parentUser.getRole())) {
            throw new RuntimeException("指定的ID不是老人账号");
        }
        
        // 使用老人的数据库ID作为parentId
        user.setParentId(parentUser.getId());
        user = userRepository.save(user);
        
        return UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId(), user.getElderId());
    }

    @Transactional
    public UserInfo unbindElder(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("user not found"));
        
        user.setParentId(null);
        user = userRepository.save(user);
        
        return UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId(), user.getElderId());
    }

    @Transactional
    public UserInfo updateLocation(Long userId, String location) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("user not found"));
        
        user.setLastLocation(location);
        user.setLastLocationUpdate(java.time.LocalDateTime.now());
        user = userRepository.save(user);
        
        return UserInfo.of(user.getId(), user.getUsername(), user.getDisplayName(), user.getRole(), user.getParentId(), user.getElderId());
    }

    public record AuthResult(String token, UserInfo user) {}
}
