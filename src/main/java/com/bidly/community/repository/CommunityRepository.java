package com.bidly.community.repository;

import com.bidly.community.entity.Community;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CommunityRepository extends JpaRepository<Community, UUID> {
    Optional<Community> findByName(String name);
    Page<Community> findByActiveTrue(Pageable pageable);
    List<Community> findByActiveTrueOrderByCreatedAtDesc();
    List<Community> findByCityIgnoreCaseAndActiveTrue(String city);
}
