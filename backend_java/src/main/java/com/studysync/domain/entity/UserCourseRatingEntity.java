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
import java.time.Instant;

/**
 * Kullanıcının derse verdiği yıldız — {@code POST /courses/{courseCode}/rating}.
 *
 * <p><b>Kısıt:</b> aynı kullanıcı + ders kodu tekil ({@code uk_user_course}).
 *
 * <p><b>Mantık:</b> rating 1–5 validasyonu; kayıt sonrası {@link CourseCatalogEntity} özet alanları güncellenir.
 */
@Entity
@Table(
        name = "user_course_ratings",
        uniqueConstraints = @UniqueConstraint(name = "uk_user_course", columnNames = {"user_id", "course_code"}))
public class UserCourseRatingEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id")
    private UserAccount user;

    @Column(name = "course_code", nullable = false, length = 32)
    private String courseCode;

    @Column(nullable = false)
    private Integer rating;

    @Column(nullable = false)
    private Instant createdAt;

    public UserCourseRatingEntity() {}

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

    public Integer getRating() {
        return rating;
    }

    public void setRating(Integer rating) {
        this.rating = rating;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }
}
