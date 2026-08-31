package com.bidly.user.dto;

public class IdentitySetupRequest {
    private String provider = "DIGILOCKER";
    private String aadhaarNumber;
    private String panNumber;

    public IdentitySetupRequest() {}

    public IdentitySetupRequest(String provider, String aadhaarNumber, String panNumber) {
        this.provider = provider;
        this.aadhaarNumber = aadhaarNumber;
        this.panNumber = panNumber;
    }

    public String getProvider() { return provider; }
    public void setProvider(String provider) { this.provider = provider; }

    public String getAadhaarNumber() { return aadhaarNumber; }
    public void setAadhaarNumber(String aadhaarNumber) { this.aadhaarNumber = aadhaarNumber; }

    public String getPanNumber() { return panNumber; }
    public void setPanNumber(String panNumber) { this.panNumber = panNumber; }
}
