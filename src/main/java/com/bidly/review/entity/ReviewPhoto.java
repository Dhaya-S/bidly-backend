package com.bidly.review.entity;

import com.bidly.common.entity.BaseEntity;
import jakarta.persistence.*;

@Entity
@Table(name = "review_photos", indexes = {
        @Index(name = "idx_review_photos_review", columnList = "review_id")
})
public class ReviewPhoto extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "review_id", nullable = false)
    private Review review;

    @Column(name = "photo_url", nullable = false, columnDefinition = "TEXT")
    private String photoUrl;

    public ReviewPhoto() {}

    public ReviewPhoto(Review review, String photoUrl) {
        this.review = review;
        this.photoUrl = photoUrl;
    }

    public Review getReview() { return review; }
    public void setReview(Review review) { this.review = review; }

    public String getPhotoUrl() { return photoUrl; }
    public void setPhotoUrl(String photoUrl) { this.photoUrl = photoUrl; }
}
