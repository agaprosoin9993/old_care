package com.guardian.service;

import com.guardian.dto.UserInfo;
import com.guardian.entity.User;
import com.guardian.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.Random;

@Service
@RequiredArgsConstructor
public class AuthService {
    private final UserRepository userRepository;
    private final Map<String, Long> tokenStore = new HashMap<>();
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    @Transactional
    public AuthResult register(String username, String password, String displayName, String role, Long parentId) {
        if (userRepository.findByUsername(username).isPresent()) {
            throw new RuntimeException("username already exists");
        }

        User user = new User();
        user.setUsername(username);
        user.setPasswordHash(hashPassword(password));
        user.setDisplayName(displayName != null && !displayName.isEmpty() ? displayName : username);
        user.setRole(role != null ? role : "elder");

        if ("child".equals(role) && parentId != null) {
            user.setParentId(parentId);
        } else if ("elder".equals(role)) {
            user.setElderId(generateElderId());
        }

        user = userRepository.save(user);
        String token = generateToken(user.getId());

        return new AuthResult(token, UserInfo.of(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getRole(),
                user.getParentId(),
                user.getElderId()
        ));
    }

    @Transactional
    public AuthResult login(String username, String password) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("invalid credentials"));

        if (!verifyPassword(password, user.getPasswordHash())) {
            throw new RuntimeException("invalid credentials");
        }

        String token = generateToken(user.getId());

        return new AuthResult(token, UserInfo.of(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getRole(),
                user.getParentId(),
                user.getElderId()
        ));
    }

    public Optional<UserInfo> getUserByToken(String token) {
        Long userId = tokenStore.get(token);
        if (userId == null) {
            return Optional.empty();
        }

        return userRepository.findById(userId)
                .map(user -> UserInfo.of(
                        user.getId(),
                        user.getUsername(),
                        user.getDisplayName(),
                        user.getRole(),
                        user.getParentId(),
                        user.getElderId()
                ));
    }

    public Optional<Long> getUserIdByToken(String token) {
        return Optional.ofNullable(tokenStore.get(token));
    }

    public Optional<UserInfo> getUserById(Long id) {
        return userRepository.findById(id)
                .map(user -> UserInfo.of(
                        user.getId(),
                        user.getUsername(),
                        user.getDisplayName(),
                        user.getRole(),
                        user.getParentId(),
                        user.getElderId()
                ));
    }

    @Transactional
    public UserInfo updateParentId(Long userId, Long parentId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("user not found"));

        if (!"child".equals(user.getRole())) {
            throw new RuntimeException("only child users can bind elder");
        }

        User elder = userRepository.findById(parentId)
                .orElseThrow(() -> new RuntimeException("elder not found"));

        if (!"elder".equals(elder.getRole())) {
            throw new RuntimeException("target user is not an elder");
        }

        user.setParentId(parentId);
        user = userRepository.save(user);

        return UserInfo.of(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getRole(),
                user.getParentId(),
                user.getElderId()
        );
    }

    @Transactional
    public UserInfo unbindElder(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("user not found"));

        user.setParentId(null);
        user = userRepository.save(user);

        return UserInfo.of(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getRole(),
                user.getParentId(),
                user.getElderId()
        );
    }

    @Transactional
    public UserInfo updateLocation(Long userId, String location, Double latitude, Double longitude) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("user not found"));

        user.setLastLocation(location);
        user.setLatitude(latitude);
        user.setLongitude(longitude);
        user.setLastLocationUpdate(LocalDateTime.now());
        user = userRepository.save(user);

        return UserInfo.of(
                user.getId(),
                user.getUsername(),
                user.getDisplayName(),
                user.getRole(),
                user.getParentId(),
                user.getElderId()
        );
    }

    private String generateToken(Long userId) {
        String token = "token_" + System.currentTimeMillis() + "_" + new Random().nextInt(10000);
        tokenStore.put(token, userId);
        return token;
    }

    private String hashPassword(String password) {
        return passwordEncoder.encode(password);
    }

    private boolean verifyPassword(String password, String hash) {
        if (hash.startsWith("$2a$") || hash.startsWith("$2b$") || hash.startsWith("$2y$")) {
            return passwordEncoder.matches(password, hash);
        }
        return hash.equals("hashed_" + password);
    }

    private String generateElderId() {
        Random random = new Random();
        String elderId;
        do {
            elderId = String.format("%06d", random.nextInt(1000000));
        } while (userRepository.findByElderId(elderId).isPresent());
        return elderId;
    }

    public record AuthResult(String token, UserInfo user) {}
}
