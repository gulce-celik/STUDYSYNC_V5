package com.studysync.domain.campus;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

/**
 * Static QR / check-in code per workspace. Desks use the desk number only ({@code desk-12} → {@code 12});
 * group rooms use {@code G} + number ({@code group-2} → {@code G2}) to avoid colliding with desk ids.
 */
@Component
public class WorkspaceQrRegistry {

    private static final Pattern DESK_ID = Pattern.compile("^desk-(\\d+)$", Pattern.CASE_INSENSITIVE);
    private static final Pattern GROUP_ID = Pattern.compile("^group-(\\d+)$", Pattern.CASE_INSENSITIVE);

    private final Map<String, String> qrByWorkspaceId;

    public WorkspaceQrRegistry() {
        Map<String, String> map = new LinkedHashMap<>();
        for (String id : allWorkspaceIds()) {
            map.put(id, qrForWorkspaceId(id));
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
            return "";
        }
        String key = workspaceId.trim();
        return qrByWorkspaceId.getOrDefault(key, qrForWorkspaceId(key));
    }

    /** Desk number or group code used as {@code qrPayload} on reservations and check-in. */
    public static String qrForWorkspaceId(String workspaceId) {
        if (workspaceId == null || workspaceId.isBlank()) {
            return "";
        }
        String id = workspaceId.trim();
        Matcher desk = DESK_ID.matcher(id);
        if (desk.matches()) {
            return desk.group(1);
        }
        Matcher group = GROUP_ID.matcher(id);
        if (group.matches()) {
            return "G" + group.group(1);
        }
        return id;
    }

    public Map<String, String> allCodes() {
        return qrByWorkspaceId;
    }
}
