package com.guardian.repository;

import com.guardian.entity.Reminder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReminderRepository extends JpaRepository<Reminder, Long> {
    List<Reminder> findByUserIdOrderByTimeAsc(Long userId);
    List<Reminder> findByUserIdIsNullOrUserIdOrderByTimeAsc(Long userId);
}
