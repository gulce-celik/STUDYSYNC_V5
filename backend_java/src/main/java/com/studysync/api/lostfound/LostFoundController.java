/* FILE PURPOSE: HTTP endpoint katmani; request/response sozlesmesini servis katmanina baglar. */

package com.studysync.api.lostfound;

import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.dto.LostFoundReportRequestDto;
import com.studysync.domain.dto.LostItemDto;
import com.studysync.domain.service.LostFoundService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * GET/POST /api/v1/lost-found
 *
 * <p>POST gövdesi typed DTO’ya çevrilmeli: {@code workspaceId}, {@code description}.
 * İsteğe bağlı fotoğraf URL’si için genişletme alanı bırakın.
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
    public ActionResultDto reportLostItem(@Valid @RequestBody LostFoundReportRequestDto body) {
        return lostFoundService.reportLostItem(body.workspaceId(), body.description());
    }

    @org.springframework.web.bind.annotation.PatchMapping("/{id}/found")
    public ActionResultDto markAsFound(@org.springframework.web.bind.annotation.PathVariable String id) {
        return lostFoundService.markAsFound(id);
    }
}
