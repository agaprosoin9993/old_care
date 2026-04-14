package com.guardian.service;

import com.guardian.entity.SosLog;
import com.guardian.repository.SosLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class SosService {
    private final SosLogRepository sosLogRepository;

    public List<SosLog> getSosLogs(Long userId) {
        if (userId == null) {
            return sosLogRepository.findByUserIdIsNullOrUserIdOrderByCreatedAtDesc(userId).stream()
                    .limit(50)
                    .toList();
        }
        return sosLogRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .limit(50)
                .toList();
    }

    @Transactional
    public SosLog createSosLog(Long userId, String location, String contact, String note) {
        SosLog sosLog = new SosLog();
        sosLog.setLocation(location != null ? location : "");
        sosLog.setContact(contact != null ? contact : "");
        sosLog.setNote(note != null ? note : "");
        sosLog.setUserId(userId);
        sosLog.setIsRead(false);
        return sosLogRepository.save(sosLog);
    }

    @Transactional
    public void markAsRead(Long sosLogId) {
        sosLogRepository.findById(sosLogId).ifPresent(log -> {
            log.setIsRead(true);
            sosLogRepository.save(log);
        });
    }

    @Transactional
    public void markAllAsRead(Long userId) {
        List<SosLog> unreadLogs = sosLogRepository.findByUserIdAndIsReadFalse(userId);
        unreadLogs.forEach(log -> log.setIsRead(true));
        sosLogRepository.saveAll(unreadLogs);
    }

    public int getUnreadCount(Long userId) {
        if (userId == null) return 0;
        return sosLogRepository.countByUserIdAndIsReadFalse(userId);
    }
}
