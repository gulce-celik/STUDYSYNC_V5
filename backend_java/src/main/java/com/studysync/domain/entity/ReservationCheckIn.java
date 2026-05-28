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
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;

/** Per-user QR check-in for a reservation (group: one row per organizer/invitee). */
@Entity
@Table(
        name = "reservation_check_ins",
        uniqueConstraints = @UniqueConstraint(columnNames = {"reservation_id", "user_id"}),
        indexes = {
            @Index(name = "idx_rci_reservation", columnList = "reservation_id"),
            @Index(name = "idx_rci_user", columnList = "user_id")
        })
public class ReservationCheckIn {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "reservation_id", nullable = false)
    private ReservationRecord reservation;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private UserAccount user;

    @Column(nullable = false)
    private Instant checkedInAt;

    public ReservationCheckIn() {}

    public Long getId() {
        return id;
    }

    public ReservationRecord getReservation() {
        return reservation;
    }

    public void setReservation(ReservationRecord reservation) {
        this.reservation = reservation;
    }

    public UserAccount getUser() {
        return user;
    }

    public void setUser(UserAccount user) {
        this.user = user;
    }

    public Instant getCheckedInAt() {
        return checkedInAt;
    }

    public void setCheckedInAt(Instant checkedInAt) {
        this.checkedInAt = checkedInAt;
    }
}
