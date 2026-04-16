package com.guardian.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ReminderRequest {
    @NotBlank(message = "title is required")
    private String title;

    @NotBlank(message = "time is required")
    private String time;

    private Integer repeating = 1;

    private String weekdays;

    private Boolean completed = false;

    private Boolean enabled = true;
}
