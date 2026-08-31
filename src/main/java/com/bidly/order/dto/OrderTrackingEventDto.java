package com.bidly.order.dto;

import java.time.Instant;
import java.util.UUID;

public class OrderTrackingEventDto {
    private UUID id;
    private String status;
    private String title;
    private String description;
    private Instant eventTime;
    private String formattedTime;
    private boolean isCompleted;

    public OrderTrackingEventDto() {}

    public OrderTrackingEventDto(UUID id, String status, String title, String description, Instant eventTime, String formattedTime, boolean isCompleted) {
        this.id = id;
        this.status = status;
        this.title = title;
        this.description = description;
        this.eventTime = eventTime;
        this.formattedTime = formattedTime;
        this.isCompleted = isCompleted;
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Instant getEventTime() { return eventTime; }
    public void setEventTime(Instant eventTime) { this.eventTime = eventTime; }

    public String getFormattedTime() { return formattedTime; }
    public void setFormattedTime(String formattedTime) { this.formattedTime = formattedTime; }

    public boolean isCompleted() { return isCompleted; }
    public void setCompleted(boolean completed) { isCompleted = completed; }
}
