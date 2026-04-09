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
        return sosLogRepository.save(sosLog);
    }
}
