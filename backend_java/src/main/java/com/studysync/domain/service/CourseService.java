/* FILE PURPOSE: Is kurallari ve use-case akislari; controller ve repository arasinda orkestrasyon. */

package com.studysync.domain.service;

import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.dto.CourseDto;
import com.studysync.domain.entity.CourseCatalogEntity;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.entity.UserCourseRatingEntity;
import com.studysync.domain.mapper.CourseMapper;
import com.studysync.domain.repository.CourseCatalogRepository;
import com.studysync.domain.repository.UserCourseRatingRepository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

/**
 * Ders kataloğu ve zorluk oylaması.
 *
 * <p>
 * <b>getCourses()</b>: Tüm dersleri veya kullanıcının bölümüne göre
 * filtrelenmiş listeyi döndürün.
 * Ortalama zorluk ve oy sayısı aggregate sorgu ile hesaplanabilir (rating
 * tablosu).
 *
 * <p>
 * <b>rateCourse(courseCode, rating)</b>: 1–5 doğrulaması; kullanıcı başına ders
 * başına tek aktif oy veya
 * güncelleme politikası; başarıda {@code ActionResultDto} ile isteğe bağlı
 * sorumluluk puanı etkisi.
 */
@Service
public class CourseService {

    private final CourseCatalogRepository courseCatalogRepository;
    private final UserCourseRatingRepository userCourseRatingRepository;

    public CourseService(CourseCatalogRepository courseCatalogRepository,
            UserCourseRatingRepository userCourseRatingRepository) {
        this.courseCatalogRepository = courseCatalogRepository;
        this.userCourseRatingRepository = userCourseRatingRepository;
    }

    public List<CourseDto> getCourses() {
        return courseCatalogRepository.findAll()
                .stream()
                .map(CourseMapper::toDto)
                .collect(Collectors.toList());
    }

    public ActionResultDto rateCourse(String courseCode, Integer rating) {
        if (rating == null || rating < 1 || rating > 5) {
            return new ActionResultDto(false, "Rating must be between 1 and 5.", null, null);
        }

        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (!(principal instanceof UserAccount)) {
            return new ActionResultDto(false, "Authentication missing or invalid", null, null);
        }
        UserAccount currentUser = (UserAccount) principal;

        CourseCatalogEntity course = courseCatalogRepository.findById(courseCode).orElse(null);
        if (course == null) {
            // Create the course catalog entry if it doesn't exist
            course = new CourseCatalogEntity();
            course.setCode(courseCode);
            course.setName(courseCode); // Defaulting name to code if not found
            course.setDifficultyRating(0.0);
            course.setRatingCount(0);
            course = courseCatalogRepository.save(course);
        }

        Optional<UserCourseRatingEntity> existingRatingOpt = userCourseRatingRepository
                .findByUser_IdAndCourseCode(currentUser.getId(), courseCode);

        UserCourseRatingEntity userRating;
        if (existingRatingOpt.isPresent()) {
            userRating = existingRatingOpt.get();
            userRating.setRating(rating);
            userRating.setCreatedAt(Instant.now());
        } else {
            userRating = new UserCourseRatingEntity();
            userRating.setUser(currentUser);
            userRating.setCourseCode(courseCode);
            userRating.setRating(rating);
            userRating.setCreatedAt(Instant.now());
        }
        userCourseRatingRepository.save(userRating);

        // Recalculate average
        List<UserCourseRatingEntity> allRatings = userCourseRatingRepository.findAll()
                .stream()
                .filter(r -> r.getCourseCode().equals(courseCode))
                .collect(Collectors.toList());

        int count = allRatings.size();
        double sum = allRatings.stream().mapToInt(UserCourseRatingEntity::getRating).sum();
        double avg = count > 0 ? sum / count : 0.0;

        course.setRatingCount(count);
        course.setDifficultyRating(avg);
        courseCatalogRepository.save(course);

        return new ActionResultDto(true, "Rating successfully saved for " + courseCode, null, null);
    }
}
