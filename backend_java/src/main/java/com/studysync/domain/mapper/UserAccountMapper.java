/* FILE PURPOSE: Entity-DTO donusumleri; API modeli ile persistence modeli arasinda esleme. */

package com.studysync.domain.mapper;

import com.studysync.domain.dto.UserSummaryDto;
import com.studysync.domain.entity.UserAccount;

/**
 * {@link UserAccount} → {@link UserSummaryDto} (departmentId → görünen isim için
 * {@link com.studysync.domain.service.ReferenceCatalogService} enjekte edilir).
 *
 * <p><b>Araç:</b> elle map veya MapStruct ({@code @Mapper}).
 */
public final class UserAccountMapper {

    private UserAccountMapper() {}

    public static UserSummaryDto toSummary(UserAccount u, String departmentDisplayName) {
        if (u == null) {
            return null;
        }
        return new UserSummaryDto(
                String.valueOf(u.getId()),
                u.getName(),
                u.getNickname(),
                u.getEmail(),
                departmentDisplayName != null ? departmentDisplayName : u.getDepartmentId(),
                u.getYear(),
                u.getResponsibilityScore(),
                u.getEnrolledCourses());
    }
}
