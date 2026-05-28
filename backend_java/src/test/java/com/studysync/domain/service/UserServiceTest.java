package com.studysync.domain.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

import com.studysync.domain.dto.UserSummaryDto;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.repository.UserAccountRepository;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserAccountRepository userAccountRepository;

    @Mock
    private ReferenceCatalogService referenceCatalogService;

    private UserService service;

    @BeforeEach
    void setUp() {
        service = new UserService(userAccountRepository, referenceCatalogService);
    }

    @Test
    void lookupByNickname_found_returnsSummary() {
        UserAccount alice = new UserAccount();
        alice.setName("Alice Smith");
        alice.setNickname("Alice");
        alice.setEmail("alice@std.yeditepe.edu.tr");
        alice.setDepartmentId("cse");
        alice.setYear(3);
        when(userAccountRepository.findByNicknameIgnoreCase("Alice")).thenReturn(Optional.of(alice));
        when(referenceCatalogService.resolveDepartmentName("cse")).thenReturn(Optional.of("Computer Engineering"));

        UserSummaryDto dto = service.lookupByNickname("Alice");

        assertEquals("Alice", dto.nickname());
        assertEquals("Alice Smith", dto.name());
    }

    @Test
    void lookupByNickname_empty_throws() {
        IllegalStateException ex =
                assertThrows(IllegalStateException.class, () -> service.lookupByNickname("  "));
        assertEquals("Nickname cannot be empty.", ex.getMessage());
    }

    @Test
    void lookupByNickname_notFound_throws() {
        when(userAccountRepository.findByNicknameIgnoreCase("Nobody")).thenReturn(Optional.empty());

        IllegalStateException ex =
                assertThrows(IllegalStateException.class, () -> service.lookupByNickname("Nobody"));
        assertEquals("User not found: Nobody", ex.getMessage());
    }
}
