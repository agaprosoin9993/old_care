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

    public static UserInfo of(Long id, String username, String displayName) {
        return new UserInfo(id, username, displayName);
    }
}
