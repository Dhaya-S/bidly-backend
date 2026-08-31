package com.bidly.user.dto;

import java.util.HashSet;
import java.util.Set;

public class InterestsSetupRequest {
    private Set<String> interests = new HashSet<>();

    public InterestsSetupRequest() {}

    public InterestsSetupRequest(Set<String> interests) {
        this.interests = interests;
    }

    public Set<String> getInterests() { return interests; }
    public void setInterests(Set<String> interests) { this.interests = interests; }
}
