package com.studysync.domain.service;

import com.studysync.domain.dto.StudyBuddySuggestionDto;
import com.studysync.domain.dto.CreateBuddyListingRequestDto;
import com.studysync.domain.dto.BuddyListingResponseDto;
import com.studysync.domain.entity.StudyBuddyListingEntity;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.entity.WeeklyScheduleBlockEntity;
import com.studysync.domain.repository.StudyBuddyListingRepository;
import com.studysync.domain.repository.UserAccountRepository;
import com.studysync.domain.repository.WeeklyScheduleBlockRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Çalışma arkadaşı önerileri ve eşleşme skoru hesaplama servisi.
 */
@Service
public class StudyBuddyService {

    private final UserAccountRepository userRepository;
    private final WeeklyScheduleBlockRepository scheduleRepository;
    private final StudyBuddyListingRepository listingRepository;
    private final Clock clock;

    public StudyBuddyService(
            UserAccountRepository userRepository,
            WeeklyScheduleBlockRepository scheduleRepository,
            StudyBuddyListingRepository listingRepository,
            Clock clock) {
        this.userRepository = userRepository;
        this.scheduleRepository = scheduleRepository;
        this.listingRepository = listingRepository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<StudyBuddySuggestionDto> getSuggestions(String courseCode, String slotId, UserAccount currentUser) {
        if (currentUser == null || courseCode == null || courseCode.trim().isEmpty()) {
            return List.of();
        }

        final String finalCourse = courseCode.trim().toUpperCase();

        // 1. Son 7 günde aktif ilan açmış aday kullanıcıları filtrele
        Instant since = Instant.now(clock).minus(7, java.time.temporal.ChronoUnit.DAYS);
        List<UserAccount> candidates = listingRepository.findActiveCandidatesSince(since, currentUser.getId()).stream()
                .filter(u -> u.getEnrolledCourses().stream().anyMatch(c -> c.equalsIgnoreCase(finalCourse)))
                .collect(Collectors.toList());

        if (candidates.isEmpty()) {
            return List.of();
        }

        // 2. Sınav aciliyet kontrolü için program bloklarını topluca çek ve grupla
        List<Long> candidateIds = candidates.stream().map(UserAccount::getId).collect(Collectors.toList());
        List<WeeklyScheduleBlockEntity> allBlocks = new ArrayList<>();
        allBlocks.addAll(scheduleRepository.findByUser_IdIn(candidateIds));
        allBlocks.addAll(scheduleRepository.findByUser_IdOrderByDayCodeAscTimeSlotAsc(currentUser.getId()));

        Map<Long, List<WeeklyScheduleBlockEntity>> blocksByUser = allBlocks.stream()
                .collect(Collectors.groupingBy(b -> b.getUser().getId()));

        List<WeeklyScheduleBlockEntity> currentUserBlocks = blocksByUser.getOrDefault(currentUser.getId(), List.of());
        LocalDate currentUserExamDate = getUpcomingExamDate(currentUserBlocks, finalCourse);

        LocalDate today = LocalDate.now(clock);

        List<StudyBuddySuggestionDto> suggestions = new ArrayList<>();

        for (UserAccount candidate : candidates) {
            // A. Ortak Dersler Hesabı
            List<String> commonCourses = currentUser.getEnrolledCourses().stream()
                    .filter(c -> candidate.getEnrolledCourses().stream().anyMatch(cc -> cc.equalsIgnoreCase(c)))
                    .map(String::toUpperCase)
                    .collect(Collectors.toList());

            long otherCoursesCount = commonCourses.stream()
                    .filter(c -> !c.equalsIgnoreCase(finalCourse))
                    .count();
            int otherCoursesScore = Math.min((int) otherCoursesCount * 2, 10);

            // B. Sınav Aciliyet Hesabı
            List<WeeklyScheduleBlockEntity> candidateBlocks = blocksByUser.getOrDefault(candidate.getId(), List.of());
            LocalDate candidateExamDate = getUpcomingExamDate(candidateBlocks, finalCourse);

            int examScore = 0;
            if (currentUserExamDate != null && candidateExamDate != null) {
                LocalDate closestExam = currentUserExamDate.isBefore(candidateExamDate) ? currentUserExamDate : candidateExamDate;
                long days = ChronoUnit.DAYS.between(today, closestExam);
                if (days >= 0) {
                    if (days <= 3) {
                        examScore = 25;
                    } else if (days <= 7) {
                        examScore = 15;
                    } else {
                        examScore = 10;
                    }
                }
            }

            // C. Çalışma Tarzı (Study Style) Hesabı
            int styleScore = calculateStudyStyleScore(currentUser.getStudyStyle(), candidate.getStudyStyle());

            // D. Toplam Eşleşme Skoru Hesabı
            int score = 45; // Taban Puan
            score += 5; // Ana Ders Eşleşme Bonusu
            score += otherCoursesScore; // Diğer Ortak Dersler (+2 per course, max 10)
            
            if (currentUser.getYear() != null && candidate.getYear() != null && currentUser.getYear().equals(candidate.getYear())) {
                score += 10; // Sınıf Uyum Puanı
            }

            score += styleScore; // Çalışma Tarzı Bonusu
            score += examScore; // Sınav Aciliyet Bonusu

            // Sınırlandırma (Clamp to 115)
            score = Math.min(score, 115);

            // Gizlilik Politikası: 'name' yerine candidate.getNickname() veya maskelenmiş isim dönülür
            String displayName = (candidate.getNickname() != null && !candidate.getNickname().trim().isEmpty())
                    ? candidate.getNickname().trim()
                    : candidate.getName();

            suggestions.add(new StudyBuddySuggestionDto(
                    candidate.getId().toString(),
                    displayName,
                    score,
                    commonCourses,
                    List.of() // İlgi alanları (topics) sıfırlandı
            ));
        }

        // Skorlara göre azalan sırada sırala
        suggestions.sort((a, b) -> b.matchScore().compareTo(a.matchScore()));

        return suggestions;
    }

    private int calculateStudyStyleScore(String styleA, String styleB) {
        if (styleA == null || styleB == null || styleA.trim().isEmpty() || styleB.trim().isEmpty()) {
            return 5;
        }
        String sA = styleA.trim().toLowerCase();
        String sB = styleB.trim().toLowerCase();

        // Practice together Match (+20)
        if (sA.contains("practice") && sB.contains("practice")) {
            return 20;
        }

        // Explain & Listen Match (+15)
        boolean isAExplain = sA.contains("explain");
        boolean isAListen = sA.contains("listen");
        boolean isBExplain = sB.contains("explain");
        boolean isBListen = sB.contains("listen");

        if ((isAExplain && isBListen) || (isAListen && isBExplain)) {
            return 15;
        }

        // Explain & Explain or Listen & Listen (+0)
        if ((isAExplain && isBExplain) || (isAListen && isBListen)) {
            return 0;
        }

        return 5; // Diğer durumlar (+5)
    }

    private LocalDate getUpcomingExamDate(List<WeeklyScheduleBlockEntity> blocks, String courseCode) {
        LocalDate today = LocalDate.now(clock);
        LocalDate closestExam = null;
        for (WeeklyScheduleBlockEntity block : blocks) {
            if (block.getBlockType() != null && block.getBlockType().equalsIgnoreCase("exam")) {
                LocalDate examDate = parseExamDate(block.getLabel());
                if (examDate != null && isExamForCourse(block.getLabel(), courseCode)) {
                    if (!examDate.isBefore(today)) {
                        if (closestExam == null || examDate.isBefore(closestExam)) {
                            closestExam = examDate;
                        }
                    }
                }
            }
        }
        return closestExam;
    }

    private LocalDate parseExamDate(String label) {
        if (label == null || !label.startsWith("EXAM:")) {
            return null;
        }
        String[] parts = label.split(":");
        if (parts.length < 3) {
            return null;
        }
        try {
            String dateStr = parts[2].trim();
            if (dateStr.contains("T")) {
                dateStr = dateStr.split("T")[0];
            }
            return LocalDate.parse(dateStr);
        } catch (Exception e) {
            return null;
        }
    }

    private boolean isExamForCourse(String label, String courseCode) {
        if (label == null || !label.startsWith("EXAM:")) {
            return false;
        }
        String[] parts = label.split(":");
        if (parts.length < 2) {
            return false;
        }
        return parts[1].trim().equalsIgnoreCase(courseCode.trim());
    }

    @Transactional
    public BuddyListingResponseDto createListing(CreateBuddyListingRequestDto dto, UserAccount currentUser) {
        if (currentUser == null) {
            return new BuddyListingResponseDto(false, "Authentication required.", null, null, null);
        }

        LocalDate today = LocalDate.now(clock);
        LocalDate monday = today.with(java.time.temporal.TemporalAdjusters.previousOrSame(java.time.DayOfWeek.MONDAY));
        LocalDate sunday = today.with(java.time.temporal.TemporalAdjusters.nextOrSame(java.time.DayOfWeek.SUNDAY));

        // Limit check: max 2 listings per calendar week (Mon-Sun, resets on Monday)
        Instant mondayStart = monday.atStartOfDay(clock.getZone()).toInstant();
        long count = listingRepository.countByUser_IdAndCreatedAtAfterAndStatusNot(currentUser.getId(), mondayStart, "CANCELLED");
        if (count >= 2) {
            return new BuddyListingResponseDto(
                    false,
                    "You have reached your weekly limit of 2 listings for this week (resets on Monday).",
                    null,
                    currentUser.getResponsibilityScore(),
                    null
            );
        }

        // Date check: must be in current week and not in the past
        if (dto.preferredWeekday() != null && !dto.preferredWeekday().trim().isEmpty()) {
            try {
                LocalDate selectedDate = LocalDate.parse(dto.preferredWeekday().trim());
                if (selectedDate.isBefore(today)) {
                    return new BuddyListingResponseDto(
                            false,
                            "Preferred date cannot be in the past.",
                            null,
                            currentUser.getResponsibilityScore(),
                            null
                    );
                }
                if (selectedDate.isAfter(sunday)) {
                    return new BuddyListingResponseDto(
                            false,
                            "Preferred date must be within the current week (on or before " + sunday + ").",
                            null,
                            currentUser.getResponsibilityScore(),
                            null
                    );
                }
            } catch (Exception e) {
                return new BuddyListingResponseDto(
                        false,
                        "Invalid date format. Expected YYYY-MM-DD.",
                        null,
                        currentUser.getResponsibilityScore(),
                        null
                );
            }
        }

        // Deduct 1 responsibility score point
        int newScore = Math.max(currentUser.getResponsibilityScore() - 1, 0);
        currentUser.setResponsibilityScore(newScore);
        userRepository.save(currentUser);

        // Save listing record
        StudyBuddyListingEntity entity = new StudyBuddyListingEntity();
        entity.setUser(currentUser);
        entity.setCourseCode(dto.courseCode().trim().toUpperCase());
        entity.setPurpose(dto.purpose().trim());
        entity.setPreferredWeekday(dto.preferredWeekday() != null && !dto.preferredWeekday().trim().isEmpty()
                ? dto.preferredWeekday().trim() : null);
        entity.setPreferredSlotId(dto.preferredSlotId() != null && !dto.preferredSlotId().trim().isEmpty()
                ? dto.preferredSlotId().trim() : null);
        entity.setNote(dto.note() != null && !dto.note().trim().isEmpty() ? dto.note().trim() : null);
        entity.setCreatedAt(Instant.now(clock));
        entity.setStatus("ACTIVE");

        StudyBuddyListingEntity saved = listingRepository.save(entity);

        return new BuddyListingResponseDto(
                true,
                "Study Buddy listing posted successfully.",
                saved.getId(),
                newScore,
                saved.getCreatedAt()
        );
    }

    @Transactional(readOnly = true)
    public List<com.studysync.domain.dto.StudyBuddyListingDto> getMyActiveListings(UserAccount currentUser) {
        if (currentUser == null) {
            return List.of();
        }
        return listingRepository.findByUser_IdOrderByCreatedAtDesc(currentUser.getId()).stream()
                .map(l -> new com.studysync.domain.dto.StudyBuddyListingDto(
                        l.getId(),
                        l.getCourseCode(),
                        l.getPurpose(),
                        l.getPreferredWeekday(),
                        l.getPreferredSlotId(),
                        l.getNote(),
                        l.getStatus(),
                        l.getCreatedAt()
                ))
                .collect(Collectors.toList());
    }

    @Transactional
    public boolean completeListing(Long listingId, UserAccount currentUser) {
        if (currentUser == null || listingId == null) {
            return false;
        }
        java.util.Optional<StudyBuddyListingEntity> opt = listingRepository.findById(listingId);
        if (opt.isPresent()) {
            StudyBuddyListingEntity entity = opt.get();
            if (entity.getUser().getId().equals(currentUser.getId())) {
                entity.setStatus("COMPLETED");
                listingRepository.save(entity);
                return true;
            }
        }
        return false;
    }

    @Transactional
    public boolean cancelListing(Long listingId, UserAccount currentUser) {
        if (currentUser == null || listingId == null) {
            return false;
        }
        java.util.Optional<StudyBuddyListingEntity> opt = listingRepository.findById(listingId);
        if (opt.isPresent()) {
            StudyBuddyListingEntity entity = opt.get();
            if (entity.getUser().getId().equals(currentUser.getId())) {
                if (!"ACTIVE".equals(entity.getStatus())) {
                    return false; // Can only cancel active listings
                }
                entity.setStatus("CANCELLED");
                listingRepository.save(entity);

                // Refund 1 responsibility score point
                int newScore = Math.min(currentUser.getResponsibilityScore() + 1, 100);
                currentUser.setResponsibilityScore(newScore);
                userRepository.save(currentUser);
                return true;
            }
        }
        return false;
    }
}
