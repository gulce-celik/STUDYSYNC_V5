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
import java.time.Instant;

/** Per-invitee row for a group reservation — 15-minute accept window. */
@Entity
@Table(
        name = "group_reservation_invites",
        indexes = {
            @Index(name = "idx_gri_reservation", columnList = "reservation_id"),
            @Index(name = "idx_gri_invitee_status", columnList = "invitee_user_id, status")
        })
public class GroupReservationInvite {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "reservation_id", nullable = false)
    private ReservationRecord reservation;

    @ManyToOne(optional = false)
    @JoinColumn(name = "invitee_user_id", nullable = false)
    private UserAccount invitee;

    @Column(nullable = false, length = 16)
    private String status;

    @Column(nullable = false)
    private Instant createdAt;

    @Column(nullable = false)
    private Instant expiresAt;

    public GroupReservationInvite() {}

    public Long getId() {
        return id;
    }

    public ReservationRecord getReservation() {
        return reservation;
    }

    public void setReservation(ReservationRecord reservation) {
        this.reservation = reservation;
    }

    public UserAccount getInvitee() {
        return invitee;
    }

    public void setInvitee(UserAccount invitee) {
        this.invitee = invitee;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(Instant expiresAt) {
        this.expiresAt = expiresAt;
    }
}
