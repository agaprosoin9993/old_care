package com.guardian.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AuthResponse {
    private String token;
    private UserInfo user;

    public static AuthResponse of(String token, UserInfo user) {
        return new AuthResponse(token, user);
    }
}
