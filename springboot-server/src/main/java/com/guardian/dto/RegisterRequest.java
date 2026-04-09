package com.guardian.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class RegisterRequest {
    @NotBlank(message = "username is required")
    private String username;

    @NotBlank(message = "password is required")
    private String password;

    private String displayName;
    
    private String role; // elder or child
    
    private Long parentId; // for child users
}
