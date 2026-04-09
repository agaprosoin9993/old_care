package com.guardian.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ReminderRequest {
    @NotBlank(message = "title is required")
    private String title;

    @NotBlank(message = "time is required")
    private String time;

    private Boolean repeating = true;

    private Boolean completed = false;
}
