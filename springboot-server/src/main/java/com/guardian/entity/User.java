package com.guardian.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String username;

    @Column(nullable = false)
    private String passwordHash;

    @Column(name = "display_name", length = 100)
    private String displayName;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Column(nullable = false, columnDefinition = "varchar(20) default 'elder'")
    private String role; // elder or child

    @Column(name = "parent_id")
    private Long parentId; // for child users, refers to elder user id

    @Column(name = "elder_id", length = 6, unique = true)
    private String elderId; // 6-digit random unique ID for elder users

    @Column(name = "last_location", length = 500)
    private String lastLocation;

    @Column(name = "last_location_update")
    private LocalDateTime lastLocationUpdate;
}
