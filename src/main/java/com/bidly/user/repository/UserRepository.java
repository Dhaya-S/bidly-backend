package com.bidly.user.repository;

import com.bidly.user.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByPhone(String phone);
    Optional<User> findFirstByNameIgnoreCase(String name);
    boolean existsByPhone(String phone);
}
