/* FILE PURPOSE: JPA entity; veritabani tablosu alani ve iliski modelini tanimlar. */

package com.studysync.domain.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.FetchType;
import java.util.Collection;
import java.util.List;
import java.util.ArrayList;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

/**
 * Mobil profil / kayıt ekranları ve JWT {@code sub} ile eşleşen kullanıcı.
 *
 * <p><b>Flutter / UI uyumu:</b> {@code UserSummary} — id, name, nickname, email, department, year.
 *
 * <p><b>Implementasyon notları:</b>
 *
 * <ul>
 *   <li>{@code passwordHash}: BCrypt (Spring Security {@code PasswordEncoder}); düz metin saklamayın.
 *   <li>Kayıt akışı: email domain kuralı (@std.yeditepe.edu.tr) sunucuda da doğrulanmalı.
 *   <li>{@code responsibilityScore}: 0–100 veya yüzde modeli; QR check-in / iptal / no-show ile güncellenir
 *       ({@link com.studysync.domain.service.ResponsibilityScoreService}).
 *   <li>İleride: {@code studyBuddyPreferences} JSON veya ayrı tablo (Profile ekranındaki grid seçimleri).
 * </ul>
 */
@Entity
@Table(name = "user_accounts")
public class UserAccount implements UserDetails {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(nullable = false)
    private String name;

    private String nickname;

    /** {@code GET /reference/departments} içindeki {@code id} ile uyumlu (ör. cse, ie, math). */
    private String departmentId;

    // Antigravity Modification: Renamed column to academic_year to bypass SQL reserved keyword errors in H2
    @Column(name = "academic_year")
    private Integer year;

    @Column(name = "responsibility_score")
    private Integer responsibilityScore = 75;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "user_enrolled_courses", joinColumns = @JoinColumn(name = "user_id"))
    @Column(name = "course_code")
    private List<String> enrolledCourses = new ArrayList<>();

    // Antigravity Modification: Changed constructor from protected to public to fix compilation visibility errors
    public UserAccount() {}

    public Long getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getNickname() {
        return nickname;
    }

    public void setNickname(String nickname) {
        this.nickname = nickname;
    }

    public String getDepartmentId() {
        return departmentId;
    }

    public void setDepartmentId(String departmentId) {
        this.departmentId = departmentId;
    }

    public Integer getYear() {
        return year;
    }

    public void setYear(Integer year) {
        this.year = year;
    }

    public Integer getResponsibilityScore() {
        return responsibilityScore;
    }

    public void setResponsibilityScore(Integer responsibilityScore) {
        this.responsibilityScore = responsibilityScore;
    }

    public List<String> getEnrolledCourses() {
        return enrolledCourses;
    }

    public void setEnrolledCourses(List<String> enrolledCourses) {
        this.enrolledCourses = enrolledCourses;
    }

    // --- UserDetails Methods ---

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_USER"));
    }

    @Override
    public String getPassword() {
        return passwordHash;
    }

    @Override
    public String getUsername() {
        return email;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return true;
    }
}
