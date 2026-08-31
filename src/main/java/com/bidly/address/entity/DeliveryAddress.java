package com.bidly.address.entity;

import com.bidly.common.entity.BaseEntity;
import com.bidly.user.entity.User;
import jakarta.persistence.*;

@Entity
@Table(name = "delivery_addresses", indexes = {
        @Index(name = "idx_addresses_user", columnList = "user_id")
})
public class DeliveryAddress extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "full_name", nullable = false, length = 100)
    private String fullName;

    @Column(nullable = false, length = 20)
    private String phone;

    @Column(name = "address_line", nullable = false, columnDefinition = "TEXT")
    private String addressLine;

    @Column(nullable = false, length = 100)
    private String city;

    @Column(nullable = false, length = 20)
    private String pincode;

    @Column(name = "is_default", nullable = false)
    private boolean isDefault = false;

    public DeliveryAddress() {}

    public DeliveryAddress(User user, String fullName, String phone, String addressLine, String city, String pincode, boolean isDefault) {
        this.user = user;
        this.fullName = fullName;
        this.phone = phone;
        this.addressLine = addressLine;
        this.city = city;
        this.pincode = pincode;
        this.isDefault = isDefault;
    }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

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
