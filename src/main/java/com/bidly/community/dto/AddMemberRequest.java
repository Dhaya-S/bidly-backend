package com.bidly.community.dto;

import java.util.UUID;

public class AddMemberRequest {
    private String phone;
    private UUID userId;
    private String role = "MEMBER";

    public AddMemberRequest() {}

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }
}
