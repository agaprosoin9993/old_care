package com.guardian.repository;

import com.guardian.entity.SosLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SosLogRepository extends JpaRepository<SosLog, Long> {
    List<SosLog> findByUserIdOrderByCreatedAtDesc(Long userId);
    List<SosLog> findByUserIdIsNullOrUserIdOrderByCreatedAtDesc(Long userId);
    List<SosLog> findByUserIdAndIsReadFalse(Long userId);
    int countByUserIdAndIsReadFalse(Long userId);
}
