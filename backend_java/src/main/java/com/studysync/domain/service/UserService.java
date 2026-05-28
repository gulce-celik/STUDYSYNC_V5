package com.studysync.domain.service;

import com.studysync.domain.dto.UserSummaryDto;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.mapper.UserAccountMapper;
import com.studysync.domain.repository.UserAccountRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    private final UserAccountRepository userAccountRepository;
    private final ReferenceCatalogService referenceCatalogService;

    public UserService(UserAccountRepository userAccountRepository, ReferenceCatalogService referenceCatalogService) {
        this.userAccountRepository = userAccountRepository;
        this.referenceCatalogService = referenceCatalogService;
    }

    @Transactional(readOnly = true)
    public UserSummaryDto lookupByNickname(String nickname) {
        if (nickname == null || nickname.isBlank()) {
            throw new IllegalStateException("Nickname cannot be empty.");
        }
        String trimmed = nickname.trim();
        UserAccount user = userAccountRepository
                .findByNicknameIgnoreCase(trimmed)
                .orElseThrow(() -> new IllegalStateException("User not found: " + trimmed));
        return toSummary(user);
    }

    private UserSummaryDto toSummary(UserAccount user) {
        String deptName = referenceCatalogService
                .resolveDepartmentName(user.getDepartmentId())
                .orElse(user.getDepartmentId());
        return UserAccountMapper.toSummary(user, deptName);
    }
}
