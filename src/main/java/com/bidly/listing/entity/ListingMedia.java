package com.bidly.listing.entity;

import com.bidly.common.entity.BaseEntity;
import jakarta.persistence.*;

/**
 * Media (image or video) attached to a Listing.
 */
@Entity
@Table(name = "listing_media")
public class ListingMedia extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "listing_id", nullable = false)
    private Listing listing;

    @Column(nullable = false)
    private String url;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private MediaType type = MediaType.IMAGE;

    @Column(name = "sort_order")
    private int sortOrder = 0;

    public ListingMedia() {}

    public ListingMedia(Listing listing, String url, MediaType type, int sortOrder) {
        this.listing = listing;
        this.url = url;
        this.type = type;
        this.sortOrder = sortOrder;
    }

    public enum MediaType {
        IMAGE, VIDEO
    }

    public Listing getListing() { return listing; }
    public void setListing(Listing listing) { this.listing = listing; }

    public String getUrl() { return url; }
    public void setUrl(String url) { this.url = url; }

    public MediaType getType() { return type; }
    public void setType(MediaType type) { this.type = type; }

    public int getSortOrder() { return sortOrder; }
    public void setSortOrder(int sortOrder) { this.sortOrder = sortOrder; }
}
