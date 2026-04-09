package com.guardian.service;

import com.guardian.entity.Contact;
import com.guardian.repository.ContactRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class ContactService {
    private final ContactRepository contactRepository;

    public List<Contact> getContacts(Long userId) {
        if (userId == null) {
            return contactRepository.findByUserIdIsNullOrUserIdOrderByCreatedAtAsc(userId);
        }
        return contactRepository.findByUserIdOrderByCreatedAtAsc(userId);
    }

    @Transactional
    public Contact createContact(Long userId, String name, String phone, String relation) {
        Contact contact = new Contact();
        contact.setName(name);
        contact.setPhone(phone);
        contact.setRelation(relation != null ? relation : "");
        contact.setUserId(userId);
        return contactRepository.save(contact);
    }

    @Transactional
    public Contact updateContact(Long id, Long userId, String name, String phone, String relation) {
        Contact contact = contactRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("not found"));

        if (contact.getUserId() != null && !contact.getUserId().equals(userId)) {
            throw new RuntimeException("forbidden");
        }

        if (name != null) contact.setName(name);
        if (phone != null) contact.setPhone(phone);
        if (relation != null) contact.setRelation(relation);

        return contactRepository.save(contact);
    }

    @Transactional
    public void deleteContact(Long id, Long userId) {
        Contact contact = contactRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("not found"));

        if (contact.getUserId() != null && !contact.getUserId().equals(userId)) {
            throw new RuntimeException("forbidden");
        }

        contactRepository.delete(contact);
    }
}
