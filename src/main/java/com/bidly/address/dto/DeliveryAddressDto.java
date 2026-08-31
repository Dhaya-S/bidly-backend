package com.bidly.address.dto;

import java.util.UUID;

public class DeliveryAddressDto {
    private UUID id;
    private String fullName;
    private String phone;
    private String addressLine;
    private String city;
    private String pincode;
    private boolean isDefault;

    public DeliveryAddressDto() {}

    public DeliveryAddressDto(UUID id, String fullName, String phone, String addressLine, String city, String pincode, boolean isDefault) {
        this.id = id;
        this.fullName = fullName;
        this.phone = phone;
        this.addressLine = addressLine;
        this.city = city;
        this.pincode = pincode;
        this.isDefault = isDefault;
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getAddressLine() { return addressLine; }
    public void setAddressLine(String addressLine) { this.addressLine = addressLine; }

    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }

    public String getPincode() { return pincode; }
    public void setPincode(String pincode) { this.pincode = pincode; }

    public boolean isDefault() { return isDefault; }
    public void setDefault(boolean aDefault) { isDefault = aDefault; }
}
