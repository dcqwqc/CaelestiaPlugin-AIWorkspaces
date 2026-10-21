# Native Caelestia plugin API migration (experimental)

Target: https://github.com/caelestia-dots/shell/pull/1703 (unmerged, changing API).
Branch: `feat/upstream-plugin-dev-20261021`; original default branch and previous behavior remain intact.

## Manifest integration
- Identity: `dcqwqc/AIWorkspaces` (case-insensitive in upstream loader).
- Requires upstream Caelestia >=2.1.0 **development plugin loader**; do not run this branch on current stable Caelestia.
- Declared entry points: custom, bar-entry, bar-popout.
- Settings file: `Settings.qml` (ensure root `SettingsObject` and settings injection load correctly).
- No custom settings UI.
- The upstream loader currently understands `custom`, `bar-entry`, `bar-popout`, `status-icon`, `quick-toggle` and `dashboard-tab` in the parser. Only bar entries/popouts and quick toggles have host integrations marked implemented. `custom` entry points and legacy `properties.slot` placements are **not** an automatic replacement for pre-existing private injection hooks.

## Required predeployment acceptance checks
1. Test in an isolated Caelestia build from PR #1703 and confirm the plugin loads without manifest/QML errors.
2. Validate all declared entry-point sources, plugin-specific settings persistence, and actual user-visible placement (including existing private injection hooks).
3. Verify launch, disable, enable, reload, service/device behavior, and session recovery; keep existing backend/config data intact.
4. Preserve rollback via the previous installed plugin directory and the original Git default branch. Do not deploy without an accessible live test and automatic rollback.

**Status:** Manifest prepared for native development loader; runtime behavior and deployment are not verified.
