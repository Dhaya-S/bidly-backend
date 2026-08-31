package com.bidly.listing.entity;

import com.bidly.common.entity.BaseEntity;
import com.bidly.user.entity.User;
import jakarta.persistence.*;

/**
 * Saved (favorited) listings by a user.
 */
@Entity
@Table(name = "saved_listings",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_saved_user_listing",
                columnNames = {"user_id", "listing_id"}
        ))
public class SavedListing extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "listing_id", nullable = false)
    private Listing listing;

    public SavedListing() {}

    public SavedListing(User user, Listing listing) {
        this.user = user;
        this.listing = listing;
    }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

    public Listing getListing() { return listing; }
    public void setListing(Listing listing) { this.listing = listing; }
}
