import Foundation

/// 1.5 이전의 Jira 대시보드가 남긴 설정을 플러그인 구조로 한 번 옮긴다.
/// Jira 자격증명 넷과 프로젝트 목록, 사용 여부만 옮기고, 나머지 옛 키는 지운다. 다음 배포에서 삭제한다.
enum ScheduleMigration {
    private static let doneKey = "didMigrateScheduleV1"

    static func runIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }

        let secrets = PluginSecrets(plugin: .jira)
        for (old, new) in [("jiraWorkspaceSlug", "workspaceSlug"), ("jiraEmail", "email"),
                           ("jiraApiToken", "apiToken"), ("jiraCloudId", "cloudId")] {
            if let value = SecretStore.read(old), !value.isEmpty, secrets.read(new) == nil {
                secrets.write(value, for: new)
            }
            SecretStore.delete(old)
        }

        let keys = defaults.stringArray(forKey: "jiraProjectKeys") ?? []
        let names = (defaults.dictionary(forKey: "jiraProjectNames") as? [String: String]) ?? [:]
        if !keys.isEmpty {
            var settings = PluginSettings.load(.jira, default: JiraSettings())
            settings.enabled = defaults.bool(forKey: "jiraEnabled")
            settings.projects = JiraSettings.normalizedProjects(keys.map {
                JiraProjectSetting(key: $0, alias: names[$0] ?? "")
            })
            PluginSettings.save(settings, for: .jira)
        }

        let retired = [
            "jiraProjectKeys", "jiraProjectNames", "jiraEnabled", "iCalEnabled",
            "iCalDisabledCalendarIDs", "calendarDisabledProjectKeys", "menuBarAgendaEnabled",
            "didMigrateKeychainV1", "didMigrateKeychainToFileV1",
            "jiraOverdueSectionExpanded", "jiraSectionThisWeekExpanded", "jiraSectionHighestExpanded",
            "jiraSectionNextWeekExpanded", "jiraSectionBacklogExpanded", "jiraSectionSprintsExpanded",
            "jiraSectionEpicsExpanded",
        ]
        retired.forEach { defaults.removeObject(forKey: $0) }

        defaults.set(true, forKey: doneKey)
    }
}
