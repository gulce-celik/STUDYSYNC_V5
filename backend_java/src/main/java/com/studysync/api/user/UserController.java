package com.studysync.api.user;

import com.studysync.domain.dto.UserSummaryDto;
import com.studysync.domain.service.UserService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping("/by-nickname/{nickname}")
    public UserSummaryDto lookupByNickname(@PathVariable String nickname) {
        return userService.lookupByNickname(nickname);
    }
}
