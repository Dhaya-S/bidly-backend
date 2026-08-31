package com.bidly.auth.dto;

import jakarta.validation.constraints.NotBlank;

public class VerifyOtpRequest {

    @NotBlank(message = "Mobile number is required")
    private String mobile;

    @NotBlank(message = "OTP is required")
    private String otp;

    private String requestId;

    private String name;

    public VerifyOtpRequest() {}

    public VerifyOtpRequest(String mobile, String otp, String requestId, String name) {
        this.mobile = mobile;
        this.otp = otp;
        this.requestId = requestId;
        this.name = name;
    }

    public String getMobile() { return mobile; }
    public void setMobile(String mobile) { this.mobile = mobile; }

    public String getOtp() { return otp; }
    public void setOtp(String otp) { this.otp = otp; }

    public String getRequestId() { return requestId; }
    public void setRequestId(String requestId) { this.requestId = requestId; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
}
