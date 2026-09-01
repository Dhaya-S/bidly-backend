package com.bidly.media.repository;

import com.bidly.media.entity.MediaJob;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface MediaJobRepository extends JpaRepository<MediaJob, UUID> {

    Optional<MediaJob> findFirstByMediaUrlOrderByCreatedAtDesc(String mediaUrl);

    List<MediaJob> findByStatus(MediaJob.ProcessingStatus status);
}
