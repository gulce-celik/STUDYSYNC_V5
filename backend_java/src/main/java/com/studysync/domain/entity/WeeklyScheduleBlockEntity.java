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
import jakarta.persistence.UniqueConstraint;

/**
 * Kullanıcı haftalık ızgarası (lesson / club / busy) — Schedule ekranı ve study-time önerileri.
 *
 * <p><b>API:</b> {@code WeeklyScheduleBlockDto} — day, timeSlot, type, label.
 *
 * <p><b>Kısıt:</b> aynı kullanıcı + gün + slot tekil olmalı ({@code uk_user_day_slot}).
 *
 * <p><b>Mantık:</b> Study Buddy ve rezervasyon önerileri bu blokları “meşgul” kabul ederek çakışma önler.
 */
@Entity
@Table(
        name = "weekly_schedule_blocks",
        uniqueConstraints = @UniqueConstraint(name = "uk_user_day_slot", columnNames = {"user_id", "day_code", "time_slot"}))
public class WeeklyScheduleBlockEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id")
    private UserAccount user;

    @Column(name = "day_code", nullable = false, length = 8)
    private String dayCode;

    @Column(name = "time_slot", nullable = false, length = 16)
    private String timeSlot;

    /** lesson | club | busy | null/free */
    @Column(length = 16)
    private String blockType;

    @Column(length = 64)
    private String label;

    public WeeklyScheduleBlockEntity() {}

    public Long getId() {
        return id;
    }

    public UserAccount getUser() {
        return user;
    }

    public void setUser(UserAccount user) {
        this.user = user;
    }

    public String getDayCode() {
        return dayCode;
    }

    public void setDayCode(String dayCode) {
        this.dayCode = dayCode;
    }

    public String getTimeSlot() {
        return timeSlot;
    }

    public void setTimeSlot(String timeSlot) {
        this.timeSlot = timeSlot;
    }

    public String getBlockType() {
        return blockType;
    }

    public void setBlockType(String blockType) {
        this.blockType = blockType;
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label;
    }
}
