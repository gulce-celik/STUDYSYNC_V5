/* FILE PURPOSE: JPA entity; veritabani tablosu alani ve iliski modelini tanimlar. */

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

/**
 * Study Buddy kullanıcı şikayeti — öğrenci başka öğrenciyi raporlar.
 *
 * <p><b>API:</b> {@code BuddyReportDto} — id, reportedUserId, reportedName, reporterLabel, reason, comment,
 * createdAt, status.
 *
 * <p><b>Implementasyon:</b>
 *
 * <ul>
 *   <li>{@code reportedBy}: JWT ile gelen raporlayan kullanıcı (istek gövdesinde yok).
 *   <li>{@code reportedUser}: raporlanan kullanıcı ({@code reportedUserId} ile çözülür).
 * </ul>
 */
@Entity
@Table(name = "buddy_reports")
public class BuddyReportRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "reported_user_id", nullable = false)
    private UserAccount reportedUser;

    @ManyToOne(optional = false)
    @JoinColumn(name = "reported_by_user_id", nullable = false)
    private UserAccount reportedBy;

    @Column(nullable = false, length = 500)
    private String reason;

    @Column(length = 2000)
    private String comment;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private String status;

    public BuddyReportRecord() {}

    public Long getId() {
        return id;
    }

    public UserAccount getReportedUser() {
        return reportedUser;
    }

    public void setReportedUser(UserAccount reportedUser) {
        this.reportedUser = reportedUser;
    }

    public UserAccount getReportedBy() {
        return reportedBy;
    }

    public void setReportedBy(UserAccount reportedBy) {
        this.reportedBy = reportedBy;
    }

    public String getReason() {
        return reason;
    }

    public void setReason(String reason) {
        this.reason = reason;
    }

    public String getComment() {
        return comment;
    }

    public void setComment(String comment) {
        this.comment = comment;
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
