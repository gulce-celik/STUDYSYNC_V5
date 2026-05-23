/* FILE PURPOSE: HTTP endpoint katmani; request/response sozlesmesini servis katmanina baglar. */

package com.studysync.api.lostfound;

import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.dto.LostFoundReportRequestDto;
import com.studysync.domain.dto.LostFoundReportResultDto;
import com.studysync.domain.dto.LostItemDto;
import com.studysync.domain.service.LostFoundService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * GET/POST/PATCH /api/v1/lost-found
 *
 * <p>POST gövdesi: {@code workspaceId}, {@code description}. {@code reportedBy} JWT kullanıcısından set edilir.
 */
@RestController
@RequestMapping("/api/v1/lost-found")
public class LostFoundController {
    private final LostFoundService lostFoundService;

    public LostFoundController(LostFoundService lostFoundService) {
        this.lostFoundService = lostFoundService;
    }

    @GetMapping
    public List<LostItemDto> getLostItems() {
        return lostFoundService.getLostItems();
    }

    @PostMapping
    public LostFoundReportResultDto reportLostItem(@Valid @RequestBody LostFoundReportRequestDto body) {
        return lostFoundService.reportLostItem(body.workspaceId(), body.description());
    }

    @PatchMapping("/{id}/found")
    public ActionResultDto markAsFound(@PathVariable String id) {
        return lostFoundService.markAsFound(id);
    }
}
