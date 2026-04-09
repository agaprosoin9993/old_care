package com.guardian.service;

import com.guardian.entity.Reminder;
import com.guardian.repository.ReminderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ReminderService {
    private final ReminderRepository reminderRepository;

    public List<Reminder> getReminders(Long userId) {
        if (userId == null) {
            return reminderRepository.findByUserIdIsNullOrUserIdOrderByTimeAsc(userId);
        }
        return reminderRepository.findByUserIdOrderByTimeAsc(userId);
    }

    @Transactional
    public Reminder createReminder(Long userId, String title, String time, Boolean repeating, Boolean completed) {
        Reminder reminder = new Reminder();
        reminder.setTitle(title);
        reminder.setTime(time);
        reminder.setRepeating(repeating != null ? repeating : true);
        reminder.setCompleted(completed != null ? completed : false);
        reminder.setUserId(userId);
        return reminderRepository.save(reminder);
    }

    @Transactional
    public Reminder updateReminder(Long id, Long userId, String title, String time, Boolean repeating, Boolean completed) {
        Reminder reminder = reminderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("not found"));

        if (reminder.getUserId() != null && !reminder.getUserId().equals(userId)) {
            throw new RuntimeException("forbidden");
        }

        if (title != null) reminder.setTitle(title);
        if (time != null) reminder.setTime(time);
        if (repeating != null) reminder.setRepeating(repeating);
        if (completed != null) reminder.setCompleted(completed);

        return reminderRepository.save(reminder);
    }

    @Transactional
    public void deleteReminder(Long id, Long userId) {
        Reminder reminder = reminderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("not found"));

        if (reminder.getUserId() != null && !reminder.getUserId().equals(userId)) {
            throw new RuntimeException("forbidden");
        }

        reminderRepository.delete(reminder);
    }
}
