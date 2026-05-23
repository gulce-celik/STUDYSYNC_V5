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
 * Kayıp eşya bildirimi — mobil Lost &amp; Found listesi.
 *
 * <p><b>API:</b> {@code LostItemDto} — id, workspaceId, description, reportedAt.
 *
 * <p><b>Implementasyon:</b>
 *
 * <ul>
 *   <li>{@code reportedBy}: isteği atan kullanıcı (JWT).
 *   <li>Son kullanma / arşiv politikası (kampüs operasyonları) eklenebilir.
 *   <li>Harita üzerinde desk id ile ilişki; rezervasyon haritası geometrisi ile aynı {@code workspaceId} uzayı.
 * </ul>
 */
@Entity
@Table(name = "lost_items")
public class LostItemRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String workspaceId;

    @Column(nullable = false, length = 2000)
    private String description;

    @ManyToOne(optional = false)
    @JoinColumn(name = "reported_by_user_id", nullable = false)
    private UserAccount reportedBy;

    @Column(nullable = false)
    private Instant reportedAt;

    @Column(nullable = false)
    private String category; // e.g., ELECTRONICS, KEYS, WALLET, BOOK

    @Column(nullable = false)
    private String status; // LOST, FOUND, CLAIMED, RETURNED

    public LostItemRecord() {}

    public Long getId() {
        return id;
    }

    public String getWorkspaceId() {
        return workspaceId;
    }

    public void setWorkspaceId(String workspaceId) {
        this.workspaceId = workspaceId;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public UserAccount getReportedBy() {
        return reportedBy;
    }

    public void setReportedBy(UserAccount reportedBy) {
        this.reportedBy = reportedBy;
    }

    public Instant getReportedAt() {
        return reportedAt;
    }

    public void setReportedAt(Instant reportedAt) {
        this.reportedAt = reportedAt;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}
