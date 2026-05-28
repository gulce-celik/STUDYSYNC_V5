package com.studysync.api.reservation;

import com.studysync.domain.dto.GroupInvitationDto;
import com.studysync.domain.service.GroupInvitationService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/group-invitations")
public class GroupInvitationController {

    private final GroupInvitationService groupInvitationService;

    public GroupInvitationController(GroupInvitationService groupInvitationService) {
        this.groupInvitationService = groupInvitationService;
    }

    @GetMapping("/pending")
    public List<GroupInvitationDto> listPending() {
        return groupInvitationService.listPending();
    }

    @PostMapping("/{inviteId}/accept")
    public void accept(@PathVariable String inviteId) {
        groupInvitationService.accept(inviteId);
    }

    @PostMapping("/{inviteId}/decline")
    public void decline(@PathVariable String inviteId) {
        groupInvitationService.decline(inviteId);
    }
}
