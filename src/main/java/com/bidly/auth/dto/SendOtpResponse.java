package com.bidly.auth.dto;

public class SendOtpResponse {
    private String requestId;
    private String mobile;
    private String message;
    private boolean isNewUser;

    public SendOtpResponse() {}

    public SendOtpResponse(String requestId, String mobile, String message, boolean isNewUser) {
        this.requestId = requestId;
        this.mobile = mobile;
        this.message = message;
        this.isNewUser = isNewUser;
    }

    public String getRequestId() { return requestId; }
    public void setRequestId(String requestId) { this.requestId = requestId; }

    public String getMobile() { return mobile; }
    public void setMobile(String mobile) { this.mobile = mobile; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public boolean isNewUser() { return isNewUser; }
    public void setNewUser(boolean newUser) { isNewUser = newUser; }
}
