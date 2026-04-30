/* FILE PURPOSE: JPA entity; veritabani tablosu alani ve iliski modelini tanimlar. */

package com.studysync.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Ders kataloğu — Course Rating ekranındaki liste ({@code GET /courses}).
 *
 * <p><b>Alanlar:</b> {@code CourseDto} ile uyumlu — code, name, difficultyRating, ratingCount.
 *
 * <p><b>Implementasyon:</b> Admin/ETL ile doldurulur. {@link com.studysync.domain.entity.UserCourseRatingEntity}
 * kayıtlarından {@code ratingCount} ve ortalama zorluk güncellenir (batch veya trigger).
 */
@Entity
@Table(name = "course_catalog")
public class CourseCatalogEntity {

    @Id
    @Column(length = 32)
    private String code;

    @Column(nullable = false)
    private String name;

    @Column(name = "difficulty_rating")
    private Double difficultyRating;

    @Column(name = "rating_count")
    private Integer ratingCount;

    public CourseCatalogEntity() {}

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Double getDifficultyRating() {
        return difficultyRating;
    }

    public void setDifficultyRating(Double difficultyRating) {
        this.difficultyRating = difficultyRating;
    }

    public Integer getRatingCount() {
        return ratingCount;
    }

    public void setRatingCount(Integer ratingCount) {
        this.ratingCount = ratingCount;
    }
}
