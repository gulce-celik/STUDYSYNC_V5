/* FILE PURPOSE: JPA entity; veritabani tablosu alani ve iliski modelini tanimlar. */

package com.studysync.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

/**
 * Çalışma alanı rezervasyonu — Reserve haritası ve My Bookings ile uyumlu.
 *
 * <p><b>API:</b> {@code ReservationDetailDto} / {@code ReservationSummaryDto} alanları buradan üretilmeli.
 *
 * <p><b>İş kuralları (ReservationService’te uygulanacak):</b>
 *
 * <ul>
 *   <li>Aynı {@code workspaceId} + {@code date} + {@code slotId} için çakışma yok.
 *   <li>Kullanıcı günlük / haftalık kota (analiz dokümanına göre).
 *   <li>Mon/Fri ön rezervasyon vs anlık masa kuralları.
 *   <li>{@code status}: ACTIVE, PENDING, COMPLETED, CANCELLED, NO_SHOW — mobil sekme filtreleri.
 *   <li>{@code participantsJson}: grup rezervasyonlarında nickname listesi (JSON array string); bireyselde boş veya tek eleman.
 *   <li>QR payload üretimi / doğrulama: {@link com.studysync.domain.policy.QrCheckInPolicy}.
 * </ul>
 */
@Entity
@Table(name = "reservations", indexes = {
    @Index(name = "idx_res_workspace_date_slot", columnList = "workspaceId, date, slotId"),
    @Index(name = "idx_res_user_date", columnList = "user_id, date")
})
public class ReservationRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id")
    private UserAccount user;

    @Column(nullable = false)
    private String workspaceId;

    @Column(nullable = false, length = 16)
    private String date;

    @Column(nullable = false)
    private String slotId;

    private String slotLabel;

    @Column(nullable = false)
    private String status;

    private String courseCode;

    /** JSON array of participant nicknames for group bookings. */
    @Column(name = "participants_json", length = 4000)
    private String participantsJson;

    @Column(name = "qr_payload", length = 512)
    private String qrPayload;

    /**
     * Responsibility score delta for this reservation — {@code 0} at creation;
     * updated on check-in, cancel, or no-show per {@code docs/decision-cancellation-scoring.md}.
     */
    @Column(name = "score_change", nullable = false)
    private int score = 0;

    // Antigravity Modification: Changed constructor from protected to public to fix compilation visibility errors
    public ReservationRecord() {}

    public Long getId() {
        return id;
    }

    public UserAccount getUser() {
        return user;
    }

    public void setUser(UserAccount user) {
        this.user = user;
    }

    public String getWorkspaceId() {
        return workspaceId;
    }

    public void setWorkspaceId(String workspaceId) {
        this.workspaceId = workspaceId;
    }

    public String getDate() {
        return date;
    }

    public void setDate(String date) {
        this.date = date;
    }

    public String getSlotId() {
        return slotId;
    }

    public void setSlotId(String slotId) {
        this.slotId = slotId;
    }

    public String getSlotLabel() {
        return slotLabel;
    }

    public void setSlotLabel(String slotLabel) {
        this.slotLabel = slotLabel;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getCourseCode() {
        return courseCode;
    }

    public void setCourseCode(String courseCode) {
        this.courseCode = courseCode;
    }

    public String getParticipantsJson() {
        return participantsJson;
    }

    public void setParticipantsJson(String participantsJson) {
        this.participantsJson = participantsJson;
    }

    public String getQrPayload() {
        return qrPayload;
    }

    public void setQrPayload(String qrPayload) {
        this.qrPayload = qrPayload;
    }

    public int getScore() {
        return score;
    }

    public void setScore(int score) {
        this.score = score;
    }
}
