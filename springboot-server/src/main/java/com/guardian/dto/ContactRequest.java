package com.guardian.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ContactRequest {
    @NotBlank(message = "name is required")
    private String name;

    @NotBlank(message = "phone is required")
    private String phone;

    private String relation;
}
