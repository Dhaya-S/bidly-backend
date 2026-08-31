package com.bidly.auth.dto;

import jakarta.validation.constraints.NotBlank;

public class SendOtpRequest {

    @NotBlank(message = "Mobile number is required")
    private String mobile;

    private String name;

    private boolean isSignUp;

    public SendOtpRequest() {}

    public SendOtpRequest(String mobile, String name, boolean isSignUp) {
        this.mobile = mobile;
        this.name = name;
        this.isSignUp = isSignUp;
    }

    public String getMobile() { return mobile; }
    public void setMobile(String mobile) { this.mobile = mobile; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public boolean isSignUp() { return isSignUp; }
    public void setSignUp(boolean signUp) { isSignUp = signUp; }
}
