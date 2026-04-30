/* FILE PURPOSE: Is kurallari ve use-case akislari; controller ve repository arasinda orkestrasyon. */

package com.studysync.domain.service;

import com.studysync.domain.dto.ActionResultDto;
import com.studysync.domain.dto.WeeklyScheduleBlockDto;
import com.studysync.domain.dto.WeeklyScheduleResponseDto;
import com.studysync.domain.entity.UserAccount;
import com.studysync.domain.entity.WeeklyScheduleBlockEntity;
import com.studysync.domain.mapper.WeeklyScheduleMapper;
import com.studysync.domain.repository.WeeklyScheduleBlockRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Kullanıcı haftalık meşgul saatleri (ders/kulüp/kişisel).
 *
 * <p><b>getWeekly()</b>: Oturumdaki öğrencinin bloklarını DB’den okuyun.
 *
 * <p><b>putWeekly(blocks)</b>: Tam liste replace veya diff — mobil istemci tüm ızgarayı gönderiyorsa replace uygun.
 * Gün/slot/type doğrulaması (izin verilen enum’lar).
 */
@Service
public class ScheduleService {
    private final WeeklyScheduleBlockRepository scheduleRepository;

    public ScheduleService(WeeklyScheduleBlockRepository scheduleRepository) {
        this.scheduleRepository = scheduleRepository;
    }

    public WeeklyScheduleResponseDto getWeekly() {
        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (!(principal instanceof UserAccount)) {
            return new WeeklyScheduleResponseDto(List.of());
        }
        UserAccount currentUser = (UserAccount) principal;

        List<WeeklyScheduleBlockDto> blocks = scheduleRepository.findByUser_IdOrderByDayCodeAscTimeSlotAsc(currentUser.getId())
                .stream()
                .map(WeeklyScheduleMapper::toDto)
                .collect(Collectors.toList());

        return new WeeklyScheduleResponseDto(blocks);
    }

    @Transactional
    public ActionResultDto putWeekly(List<WeeklyScheduleBlockDto> next) {
        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (!(principal instanceof UserAccount)) {
            return new ActionResultDto(false, "Authentication missing or invalid", null, null);
        }
        UserAccount currentUser = (UserAccount) principal;

        // Clean up previous schedule
        scheduleRepository.deleteByUser_Id(currentUser.getId());

        if (next != null && !next.isEmpty()) {
            List<WeeklyScheduleBlockEntity> entities = new ArrayList<>();
            for (WeeklyScheduleBlockDto dto : next) {
                WeeklyScheduleBlockEntity entity = new WeeklyScheduleBlockEntity();
                WeeklyScheduleMapper.applyDto(entity, dto, currentUser);
                entities.add(entity);
            }
            scheduleRepository.saveAll(entities);
        }

        return new ActionResultDto(true, "Weekly schedule updated successfully", null, null);
    }
}
