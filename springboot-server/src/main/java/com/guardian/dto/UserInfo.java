package com.guardian.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserInfo {
    private Long id;
    private String username;
    private String displayName;
    private String role;
    private Long parentId;

    public static UserInfo of(Long id, String username, String displayName) {
        return new UserInfo(id, username, displayName, "elder", null);
    }

    public static UserInfo of(Long id, String username, String displayName, String role, Long parentId) {
        return new UserInfo(id, username, displayName, role, parentId);
    }
}
