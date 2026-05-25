/* FILE PURPOSE: HTTP endpoint katmani; request/response sozlesmesini servis katmanina baglar. */

package com.studysync.api.admin;

import com.studysync.domain.dto.BuddyReportDto;
import com.studysync.domain.service.BuddyReportService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * GET /api/v1/admin/buddy-reports
 *
 * <p>Açık (OPEN) Study Buddy kullanıcı raporları — admin mobil konsol.
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminBuddyReportsController {

    private final BuddyReportService buddyReportService;

    public AdminBuddyReportsController(BuddyReportService buddyReportService) {
        this.buddyReportService = buddyReportService;
    }

    @GetMapping("/buddy-reports")
    public List<BuddyReportDto> listBuddyReports() {
        return buddyReportService.listOpenReports();
    }
}
