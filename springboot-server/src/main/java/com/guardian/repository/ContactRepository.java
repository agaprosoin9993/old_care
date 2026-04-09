package com.guardian.repository;

import com.guardian.entity.Contact;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ContactRepository extends JpaRepository<Contact, Long> {
    List<Contact> findByUserIdOrderByCreatedAtAsc(Long userId);
    List<Contact> findByUserIdIsNullOrUserIdOrderByCreatedAtAsc(Long userId);
}
