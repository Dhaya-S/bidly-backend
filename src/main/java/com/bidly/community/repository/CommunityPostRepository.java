package com.bidly.community.repository;

import com.bidly.community.entity.CommunityPost;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Repository
public interface CommunityPostRepository extends JpaRepository<CommunityPost, UUID> {

    @EntityGraph(attributePaths = {"author", "community", "listing", "listing.media"})
    Page<CommunityPost> findAllByOrderByCreatedAtDesc(Pageable pageable);

    @EntityGraph(attributePaths = {"author", "community", "listing", "listing.media"})
    Page<CommunityPost> findByCommunityIsNullOrderByCreatedAtDesc(Pageable pageable);

    @EntityGraph(attributePaths = {"author", "community", "listing", "listing.media"})
    Page<CommunityPost> findByCommunityIdOrderByCreatedAtDesc(UUID communityId, Pageable pageable);

    @Modifying
    @Transactional
    @Query("UPDATE CommunityPost p SET p.likesCount = p.likesCount + 1 WHERE p.id = :id")
    void incrementLikes(UUID id);

    @Modifying
    @Transactional
    @Query("UPDATE CommunityPost p SET p.likesCount = CASE WHEN p.likesCount > 0 THEN p.likesCount - 1 ELSE 0 END WHERE p.id = :id")
    void decrementLikes(UUID id);

    @Modifying
    @Transactional
    @Query("UPDATE CommunityPost p SET p.sharesCount = p.sharesCount + 1 WHERE p.id = :id")
    void incrementShares(UUID id);
}
