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
    public Reminder createReminder(Long userId, String title, String time, Integer repeating, 
                                    String weekdays, Boolean completed, Boolean enabled) {
        Reminder reminder = new Reminder();
        reminder.setTitle(title);
        reminder.setTime(time);
        reminder.setRepeating(repeating != null ? repeating : 1);
        reminder.setWeekdays(weekdays);
        reminder.setCompleted(completed != null ? completed : false);
        reminder.setEnabled(enabled != null ? enabled : true);
        reminder.setUserId(userId);
        return reminderRepository.save(reminder);
    }

    @Transactional
    public Reminder updateReminder(Long id, Long userId, String title, String time, Integer repeating,
                                    String weekdays, Boolean completed, Boolean enabled) {
        Reminder reminder = reminderRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("not found"));

        if (reminder.getUserId() != null && !reminder.getUserId().equals(userId)) {
            throw new RuntimeException("forbidden");
        }

        if (title != null) reminder.setTitle(title);
        if (time != null) reminder.setTime(time);
        if (repeating != null) reminder.setRepeating(repeating);
        if (weekdays != null) reminder.setWeekdays(weekdays);
        if (completed != null) reminder.setCompleted(completed);
        if (enabled != null) reminder.setEnabled(enabled);

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
