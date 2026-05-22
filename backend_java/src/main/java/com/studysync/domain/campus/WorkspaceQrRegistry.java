package com.studysync.domain.campus;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Component;

/**
 * Fixed 4-digit QR code per workspace (desk / group room). Same codes on every deploy and restart.
 *
 * <p>Desks: {@code desk-N} → {@code 1000 + N} (e.g. desk-1 → 1001). Group rooms: {@code group-N} → {@code 2000 + N}.
 */
@Component
public class WorkspaceQrRegistry {

    private final Map<String, String> qrByWorkspaceId;

    public WorkspaceQrRegistry() {
        Map<String, String> map = new LinkedHashMap<>();
        for (int i = 1; i <= 24; i++) {
            map.put("desk-" + i, String.format("%04d", 1000 + i));
        }
        for (int g = 1; g <= 4; g++) {
            map.put("group-" + g, String.format("%04d", 2000 + g));
        }
        this.qrByWorkspaceId = Map.copyOf(map);
    }

    /** All campus workspace ids (24 desks + 4 group rooms). */
    public static List<String> allWorkspaceIds() {
        List<String> ids = new ArrayList<>();
        for (int i = 1; i <= 24; i++) {
            ids.add("desk-" + i);
        }
        for (int g = 1; g <= 4; g++) {
            ids.add("group-" + g);
        }
        return ids;
    }

    public String qrFor(String workspaceId) {
        if (workspaceId == null || workspaceId.isBlank()) {
            return "0000";
        }
        return qrByWorkspaceId.getOrDefault(workspaceId.trim(), "0000");
    }

    public Map<String, String> allCodes() {
        return qrByWorkspaceId;
    }
}
