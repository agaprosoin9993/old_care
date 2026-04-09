package com.guardian.dto;

import lombok.Data;

@Data
public class SosRequest {
    private String location;
    private String contact;
    private String note;
}
