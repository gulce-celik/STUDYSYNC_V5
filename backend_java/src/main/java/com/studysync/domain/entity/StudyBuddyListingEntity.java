package com.studysync.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "study_buddy_listings")
public class StudyBuddyListingEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id")
    private UserAccount user;

    @Column(name = "course_code", nullable = false, length = 16)
    private String courseCode;

    @Column(name = "purpose", nullable = false, length = 64)
    private String purpose;

    @Column(name = "preferred_weekday", length = 32)
    private String preferredWeekday;

    @Column(name = "preferred_slot_id", length = 16)
    private String preferredSlotId;

    @Column(name = "note", length = 255)
    private String note;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "status", nullable = false, length = 16)
    private String status = "ACTIVE";

    public StudyBuddyListingEntity() {}

    public Long getId() {
        return id;
    }

    public UserAccount getUser() {
        return user;
    }

    public void setUser(UserAccount user) {
        this.user = user;
    }

    public String getCourseCode() {
        return courseCode;
    }

    public void setCourseCode(String courseCode) {
        this.courseCode = courseCode;
    }

    public String getPurpose() {
        return purpose;
    }

    public void setPurpose(String purpose) {
        this.purpose = purpose;
    }

    public String getPreferredWeekday() {
        return preferredWeekday;
    }

    public void setPreferredWeekday(String preferredWeekday) {
        this.preferredWeekday = preferredWeekday;
    }

    public String getPreferredSlotId() {
        return preferredSlotId;
    }

    public void setPreferredSlotId(String preferredSlotId) {
        this.preferredSlotId = preferredSlotId;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}
