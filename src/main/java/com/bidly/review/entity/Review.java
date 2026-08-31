package com.bidly.review.entity;

import com.bidly.common.entity.BaseEntity;
import com.bidly.listing.entity.Listing;
import com.bidly.order.entity.Order;
import com.bidly.user.entity.User;
import jakarta.persistence.*;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "reviews", indexes = {
        @Index(name = "idx_reviews_seller", columnList = "seller_id"),
        @Index(name = "idx_reviews_listing", columnList = "listing_id")
})
public class Review extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false, unique = true)
    private Order order;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewer_id", nullable = false)
    private User reviewer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "seller_id", nullable = false)
    private User seller;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "listing_id", nullable = false)
    private Listing listing;

    @Column(nullable = false)
    private int rating;

    @Column(columnDefinition = "TEXT")
    private String comment;

    @OneToMany(mappedBy = "review", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private List<ReviewPhoto> photos = new ArrayList<>();

    public Review() {}

    public Review(Order order, User reviewer, User seller, Listing listing, int rating, String comment) {
        this.order = order;
        this.reviewer = reviewer;
        this.seller = seller;
        this.listing = listing;
        this.rating = rating;
        this.comment = comment;
    }

    public Order getOrder() { return order; }
    public void setOrder(Order order) { this.order = order; }

    public User getReviewer() { return reviewer; }
    public void setReviewer(User reviewer) { this.reviewer = reviewer; }

    public User getSeller() { return seller; }
    public void setSeller(User seller) { this.seller = seller; }

    public Listing getListing() { return listing; }
    public void setListing(Listing listing) { this.listing = listing; }

    public int getRating() { return rating; }
    public void setRating(int rating) { this.rating = rating; }

    public String getComment() { return comment; }
    public void setComment(String comment) { this.comment = comment; }

    public List<ReviewPhoto> getPhotos() { return photos; }
    public void setPhotos(List<ReviewPhoto> photos) { this.photos = photos; }
}
