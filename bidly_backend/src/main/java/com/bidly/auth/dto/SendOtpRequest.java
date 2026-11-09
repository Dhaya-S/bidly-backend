package com.bidly.auth.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;

public class SendOtpRequest {

    @NotBlank(message = "Mobile number is required")
    private String mobile;

    private String name;

    @JsonProperty("isSignUp")
    @JsonAlias({"signUp", "isSignUp", "is_sign_up"})
    private Boolean isSignUp;

    public SendOtpRequest() {}

    public SendOtpRequest(String mobile, String name, Boolean isSignUp) {
        this.mobile = mobile;
        this.name = name;
        this.isSignUp = isSignUp;
    }

    public String getMobile() { return mobile; }
    public void setMobile(String mobile) { this.mobile = mobile; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Boolean isSignUp() { return isSignUp; }
    public Boolean getIsSignUp() { return isSignUp; }
    public void setSignUp(Boolean signUp) { this.isSignUp = signUp; }
    public void setIsSignUp(Boolean isSignUp) { this.isSignUp = isSignUp; }
}
