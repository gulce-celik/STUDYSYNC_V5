/* FILE PURPOSE: HTTP endpoint katmani; request/response sozlesmesini servis katmanina baglar. */

package com.studysync.api.buddy;

import com.studysync.domain.dto.BuddyReportResultDto;
import com.studysync.domain.dto.CreateBuddyReportRequestDto;
import com.studysync.domain.dto.StudyBuddySuggestionDto;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.service.BuddyReportService;
import com.studysync.domain.service.StudyBuddyService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * GET /api/v1/study-buddies/suggestions?courseCode=&slotId=
 *
 * <p>İçerik: kullanıcı oturumuna göre kişiselleştirilmiş liste; rate limiting düşünün.
 */
@RestController
@RequestMapping("/api/v1/study-buddies")
public class StudyBuddyController {
    private final StudyBuddyService studyBuddyService;
    private final BuddyReportService buddyReportService;

    public StudyBuddyController(StudyBuddyService studyBuddyService, BuddyReportService buddyReportService) {
        this.studyBuddyService = studyBuddyService;
        this.buddyReportService = buddyReportService;
    }

    @GetMapping("/suggestions")
    public List<StudyBuddySuggestionDto> suggestions(
            @RequestParam String courseCode,
            @RequestParam String slotId,
            @org.springframework.security.core.annotation.AuthenticationPrincipal UserAccount currentUser) {
        return studyBuddyService.getSuggestions(courseCode, slotId, currentUser);
    }

    @PostMapping("/reports")
    public BuddyReportResultDto submitReport(
            @Valid @RequestBody CreateBuddyReportRequestDto body,
            @AuthenticationPrincipal UserAccount currentUser) {
        return buddyReportService.submitReport(body, currentUser);
    }

    @PostMapping("/listings")
    public com.studysync.domain.dto.BuddyListingResponseDto createListing(
            @Valid @RequestBody com.studysync.domain.dto.CreateBuddyListingRequestDto body,
            @AuthenticationPrincipal UserAccount currentUser) {
        return studyBuddyService.createListing(body, currentUser);
    }

    @GetMapping("/listings/me")
    public java.util.List<com.studysync.domain.dto.StudyBuddyListingDto> getMyListings(
            @org.springframework.security.core.annotation.AuthenticationPrincipal UserAccount currentUser) {
        return studyBuddyService.getMyActiveListings(currentUser);
    }

    @PostMapping("/listings/{id}/complete")
    public org.springframework.http.ResponseEntity<?> completeListing(
            @PathVariable Long id,
            @org.springframework.security.core.annotation.AuthenticationPrincipal UserAccount currentUser) {
        boolean success = studyBuddyService.completeListing(id, currentUser);
        if (success) {
            return org.springframework.http.ResponseEntity.ok(java.util.Map.of("success", true, "message", "Listing marked as completed."));
        } else {
            return org.springframework.http.ResponseEntity.badRequest().body(java.util.Map.of("success", false, "message", "Could not complete listing."));
        }
    }

    @PostMapping("/listings/{id}/cancel")
    public org.springframework.http.ResponseEntity<?> cancelListing(
            @PathVariable Long id,
            @org.springframework.security.core.annotation.AuthenticationPrincipal UserAccount currentUser) {
        boolean success = studyBuddyService.cancelListing(id, currentUser);
        if (success) {
            return org.springframework.http.ResponseEntity.ok(java.util.Map.of(
                    "success", true,
                    "message", "Listing cancelled successfully.",
                    "updatedResponsibilityScore", currentUser.getResponsibilityScore()
            ));
        } else {
            return org.springframework.http.ResponseEntity.badRequest().body(java.util.Map.of("success", false, "message", "Could not cancel listing."));
        }
    }
}
