# Events (Logs)

> All log events Claude Code emits over `OTEL_LOGS_EXPORTER`. Names are **fixed**. Every event carries
> the [standard event attributes](04-attributes.md) (incl. `prompt.id` correlation). Content fields are
> redacted unless the matching `OTEL_LOG_*` gate is set. Source: <https://code.claude.com/docs/en/monitoring-usage> · snapshot 2026-07-10.

## Event index

| Event (`claude_code.` prefix) | Purpose                                              | Gate to emit / un-redact                                       |
|-------------------------------|------------------------------------------------------|----------------------------------------------------------------|
| `user_prompt`                 | A user prompt was submitted                          | `prompt` field: `OTEL_LOG_USER_PROMPTS=1`                      |
| `assistant_response`          | Model produced a response *(v2.1.193+)*              | `response` field: `OTEL_LOG_ASSISTANT_RESPONSES=1`             |
| `tool_result`                 | A tool finished executing                            | details: `OTEL_LOG_TOOL_DETAILS=1`                             |
| `tool_decision`               | Permission decision on a tool call                   | params: `OTEL_LOG_TOOL_DETAILS=1`                              |
| `api_request`                 | One Anthropic API request (cost/tokens)              | always                                                         |
| `api_error`                   | An API request errored                               | always                                                         |
| `api_refusal`                 | Model refused (safety stop)                          | `category`: `OTEL_LOG_TOOL_DETAILS=1`                          |
| `api_retries_exhausted`       | Retries gave up (with final `api_error`)             | always                                                         |
| `api_request_body`            | Full request JSON                                    | `OTEL_LOG_RAW_API_BODIES`                                      |
| `api_response_body`           | Full response JSON                                   | `OTEL_LOG_RAW_API_BODIES`                                      |
| `permission_mode_changed`     | Permission mode switched                             | always                                                         |
| `auth`                        | Login/logout                                         | always                                                         |
| `mcp_server_connection`       | MCP server connect/fail/disconnect                   | names: `OTEL_LOG_TOOL_DETAILS=1`                               |
| `internal_error`              | Uncaught internal error                              | off if `DISABLE_ERROR_REPORTING`; never on Bedrock/GCP/Foundry |
| `plugin_installed`            | Plugin installed                                     | names: `OTEL_LOG_TOOL_DETAILS=1`                               |
| `plugin_loaded`               | Plugin loaded at startup                             | names: `OTEL_LOG_TOOL_DETAILS=1`                               |
| `skill_activated`             | A skill activated                                    | `skill.name`: `OTEL_LOG_TOOL_DETAILS=1`                        |
| `at_mention`                  | `@file`/`@agent`/etc. mention resolved               | always                                                         |
| `hook_registered`             | Per configured hook, at session start                | matcher: `OTEL_LOG_TOOL_DETAILS=1`                             |
| `hook_execution_start`        | Matching hooks began                                 | always                                                         |
| `hook_execution_complete`     | Matching hooks finished                              | always                                                         |
| `hook_plugin_metrics`         | Metrics emitted by official-marketplace plugin hooks | always                                                         |
| `compaction`                  | Context compaction ran                               | always                                                         |
| `feedback_survey`             | "How is Claude doing?" survey lifecycle              | `CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL`                  |

## Attribution & cost events

### `api_request` — the per-call cost/token record

| Attr                                                                                         | Values / meaning                                    |
|----------------------------------------------------------------------------------------------|-----------------------------------------------------|
| `model`                                                                                      | e.g. `claude-sonnet-5`                              |
| `cost_usd`                                                                                   | estimated cost                                      |
| `duration_ms`                                                                                | request duration                                    |
| `input_tokens` / `output_tokens`                                                             | token counts                                        |
| `cache_read_tokens` / `cache_creation_tokens`                                                | cache token counts                                  |
| `request_id`                                                                                 | Anthropic request id, e.g. `req_011...`             |
| `speed`                                                                                      | `fast` · `normal`                                   |
| `query_source`                                                                               | e.g. `repl_main_thread` · `compact` · subagent name |
| `effort`                                                                                     | `low`…`max` (absent if unsupported)                 |
| `agent.name` `skill.name` `plugin.name` `marketplace.name` `mcp_server.name` `mcp_tool.name` | attribution (standard redaction)                    |

### `api_error`

| Attr                                                               | Values                          |
|--------------------------------------------------------------------|---------------------------------|
| `model`, `error`, `duration_ms`, `speed`, `query_source`, `effort` | as above                        |
| `status_code`                                                      | HTTP code (absent for non-HTTP) |
| `attempt`                                                          | total attempts (1 = no retry)   |
| `request_id`                                                       | absent for non-HTTP errors      |
| attribution attrs                                                  | as `api_request`                |

### `api_refusal`

| Attr                                                                | Values                                                                                                           |
|---------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| `model`, `request_id`, `query_source`, `speed`, `attempt`, `effort` | as above                                                                                                         |
| `server_fallback_hop`                                               | `true` if server-side fallback already retried                                                                   |
| `has_category` / `has_explanation`                                  | `true` if `stop_details.*` present                                                                               |
| `category`                                                          | `cyber` · `bio` · `frontier_llm` · `reasoning_extraction` (only with `OTEL_LOG_TOOL_DETAILS=1` + `has_category`) |
| attribution attrs                                                   | as `api_request`                                                                                                 |

### `api_retries_exhausted`

| Attr                                     | Values                         |
|------------------------------------------|--------------------------------|
| `model`, `error`, `status_code`, `speed` | —                              |
| `total_attempts`                         | total attempts made            |
| `total_retry_duration_ms`                | wall-clock across all attempts |

### `api_request_body` / `api_response_body` (raw bodies)

| Attr                    | Values                                                      |
|-------------------------|-------------------------------------------------------------|
| `body`                  | JSON (inline mode, 60 KB cap)                               |
| `body_ref`              | file path to untruncated body (file mode)                   |
| `body_length`           | untruncated length (UTF-8 bytes file / UTF-16 units inline) |
| `body_truncated`        | `true` on inline truncation                                 |
| `model`, `query_source` | —                                                           |
| `request_id`            | (response body only)                                        |

## Tool & decision events

### `tool_result`

| Attr                                               | Values                                                                                                                                                                                                                                                             |
|----------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `tool_name`                                        | tool name                                                                                                                                                                                                                                                          |
| `tool_use_id`                                      | invocation id (matches hooks / spans)                                                                                                                                                                                                                              |
| `success`                                          | `true` · `false`                                                                                                                                                                                                                                                   |
| `duration_ms`                                      | execution time                                                                                                                                                                                                                                                     |
| `error_type`                                       | e.g. `Error:ENOENT` · `ShellError` (on failure)                                                                                                                                                                                                                    |
| `error`                                            | full message (needs `OTEL_LOG_TOOL_DETAILS=1`)                                                                                                                                                                                                                     |
| `decision_type`                                    | always `accept` (rejects produce no result event)                                                                                                                                                                                                                  |
| `decision_source`                                  | `config` · `hook` · `user_permanent` · `user_temporary`                                                                                                                                                                                                            |
| `tool_input_size_bytes` / `tool_result_size_bytes` | sizes                                                                                                                                                                                                                                                              |
| `mcp_server_scope`                                 | for MCP tools                                                                                                                                                                                                                                                      |
| `tool_parameters`                                  | JSON of tool-specific params (needs `OTEL_LOG_TOOL_DETAILS=1`) — Bash: `bash_command`,`full_command`,`timeout`,`description`,`dangerouslyDisableSandbox`,`git_commit_id`; MCP: `mcp_server_name`,`mcp_tool_name`; Skill: `skill_name`; Agent/Task: `subagent_type` |
| `tool_input`                                       | JSON args, values >512 chars truncated, ~4 K total (needs `OTEL_LOG_TOOL_DETAILS=1`)                                                                                                                                                                               |

### `tool_decision`

| Attr              | Values                                                                                 |
|-------------------|----------------------------------------------------------------------------------------|
| `tool_name`       | e.g. `Read` `Edit` `Write` `NotebookEdit`                                              |
| `tool_use_id`     | invocation id                                                                          |
| `decision`        | `accept` · `reject`                                                                    |
| `source`          | `config` · `hook` · `user_permanent` · `user_temporary` · `user_abort` · `user_reject` |
| `tool_parameters` | as `tool_result` minus post-execution fields (needs `OTEL_LOG_TOOL_DETAILS=1`)         |

## Prompt / response events

### `user_prompt`

| Attr             | Values                                                                                                             |
|------------------|--------------------------------------------------------------------------------------------------------------------|
| `prompt_length`  | chars                                                                                                              |
| `prompt`         | content (redacted unless `OTEL_LOG_USER_PROMPTS=1`)                                                                |
| `command_name`   | built-in/bundled verbatim (`compact`,`debug`); custom/plugin/MCP → `custom`/`mcp` unless `OTEL_LOG_TOOL_DETAILS=1` |
| `command_source` | `builtin` · `custom` · `mcp`                                                                                       |

### `assistant_response` *(v2.1.193+)*

| Attr              | Values                                                                                                        |
|-------------------|---------------------------------------------------------------------------------------------------------------|
| `response_length` | chars                                                                                                         |
| `response`        | text, 60 KB cap; `<REDACTED>` unless `OTEL_LOG_ASSISTANT_RESPONSES=1` (falls back to `OTEL_LOG_USER_PROMPTS`) |
| `model`           | model id                                                                                                      |
| `request_id`      | Anthropic request id (if returned)                                                                            |
| `query_source`    | e.g. `repl_main_thread` · `compact` · subagent                                                                |

## Lifecycle & session events

### `permission_mode_changed`

| Attr                    | Values                                                                                       |
|-------------------------|----------------------------------------------------------------------------------------------|
| `from_mode` / `to_mode` | `default` · `plan` · `acceptEdits` · `auto` · `bypassPermissions`                            |
| `trigger`               | `shift_tab` · `exit_plan_mode` · `auto_gate_denied` · `auto_opt_in` (absent from SDK/bridge) |

### `auth`

| Attr             | Values                                         |
|------------------|------------------------------------------------|
| `action`         | `login` · `logout`                             |
| `success`        | `true` · `false`                               |
| `auth_method`    | e.g. `oauth`                                   |
| `error_category` | categorical error (raw message never included) |
| `status_code`    | HTTP code string on failure                    |

### `compaction`

| Attr                         | Values                                                                                                      |
|------------------------------|-------------------------------------------------------------------------------------------------------------|
| `trigger`                    | `auto` · `manual`                                                                                           |
| `success`                    | `true` · `false`                                                                                            |
| `duration_ms`                | —                                                                                                           |
| `pre_tokens` / `post_tokens` | approx token counts around compaction                                                                       |
| `error`                      | on failure                                                                                                  |
| `precompute_reuse`           | only if `trigger=manual`: `hit` · `miss_custom_instructions` · `miss_hook` · `miss_not_ready` *(v2.1.153+)* |

### `at_mention`

| Attr           | Values                                          |
|----------------|-------------------------------------------------|
| `mention_type` | `file` · `directory` · `agent` · `mcp_resource` |
| `success`      | `true` · `false`                                |

### `feedback_survey`

| Attr                   | Values                                                  |
|------------------------|---------------------------------------------------------|
| `event_type`           | `appeared` · `responded` · `transcript_prompt_appeared` |
| `appearance_id`        | links events for one survey instance                    |
| `survey_type`          | `session` (the "How is Claude doing?" prompt)           |
| `response`             | user selection on `responded`                           |
| `enabled_via_override` | `true` when enabled via override env                    |

### `internal_error`

| Attr         | Values                           |
|--------------|----------------------------------|
| `error_name` | e.g. `TypeError` · `SyntaxError` |
| `error_code` | Node errno, e.g. `ENOENT`        |

## MCP & plugin & skill events

### `mcp_server_connection`

| Attr             | Values                                                                       |
|------------------|------------------------------------------------------------------------------|
| `status`         | `connected` · `failed` · `disconnected`                                      |
| `transport_type` | `stdio` · `sse` · `http`                                                     |
| `server_scope`   | `user` · `project` · `local`                                                 |
| `duration_ms`    | connect attempt duration                                                     |
| `error_code`     | on failure                                                                   |
| `is_plugin`      | `true`/`false`                                                               |
| `plugin_id_hash` | stable hash (when `is_plugin`)                                               |
| `plugin.name`    | when `is_plugin`; 3rd-party → `third-party` unless `OTEL_LOG_TOOL_DETAILS=1` |
| `server_name`    | needs `OTEL_LOG_TOOL_DETAILS=1`                                              |
| `error`          | full message, needs `OTEL_LOG_TOOL_DETAILS=1`                                |

### `skill_activated`

| Attr                               | Values                                                           |
|------------------------------------|------------------------------------------------------------------|
| `skill.name`                       | user/3rd-party → `custom_skill` unless `OTEL_LOG_TOOL_DETAILS=1` |
| `invocation_trigger`               | `user-slash` · `claude-proactive` · `nested-skill`               |
| `skill.source`                     | `bundled` · `userSettings` · `projectSettings` · `plugin`        |
| `skill.kind`                       | `workflow` (absent otherwise)                                    |
| `plugin.name` / `marketplace.name` | when official or `OTEL_LOG_TOOL_DETAILS=1`                       |

### `plugin_installed`

| Attr                                                  | Values                                              |
|-------------------------------------------------------|-----------------------------------------------------|
| `marketplace.is_official`                             | `true`/`false`                                      |
| `install.trigger`                                     | `cli` · `ui`                                        |
| `plugin.name` / `plugin.version` / `marketplace.name` | 3rd-party redacted unless `OTEL_LOG_TOOL_DETAILS=1` |

### `plugin_loaded`

| Attr                                                           | Values                                                                  |
|----------------------------------------------------------------|-------------------------------------------------------------------------|
| `plugin.name` / `marketplace.name` / `plugin.version`          | 3rd-party/non-official → `third-party` unless `OTEL_LOG_TOOL_DETAILS=1` |
| `plugin.scope`                                                 | `official` · `org` · `user-local` · `default-bundle`                    |
| `enabled_via`                                                  | `default-enable` · `org-policy` · `seed-mount` · `user-install`         |
| `plugin_id_hash`                                               | deterministic hash (exporter only)                                      |
| `has_hooks` / `has_mcp`                                        | booleans                                                                |
| `host_owned_mcp`                                               | `true` when SDK host manages MCP *(v2.1.172+)*                          |
| `skill_path_count` / `command_path_count` / `agent_path_count` | declared dir counts                                                     |
| `safe_mode`                                                    | `true` under `--safe-mode` *(v2.1.169+)*                                |

## Hook events

### `hook_registered` (once per configured hook, at session start)

| Attr                             | Values                                                                                                  |
|----------------------------------|---------------------------------------------------------------------------------------------------------|
| `hook_event`                     | e.g. `PreToolUse` · `PostToolUse`                                                                       |
| `hook_type`                      | `command` · `prompt` · `mcp_tool` · `http` · `agent`                                                    |
| `hook_source`                    | `userSettings` · `projectSettings` · `localSettings` · `flagSettings` · `policySettings` · `pluginHook` |
| `safe_mode`                      | `true`/`false` *(v2.1.169+)*                                                                            |
| `hook_matcher`                   | needs `OTEL_LOG_TOOL_DETAILS=1`                                                                         |
| `plugin.name` / `plugin_id_hash` | when `hook_source=pluginHook`                                                                           |

### `hook_execution_start`

| Attr               | Values                                                             |
|--------------------|--------------------------------------------------------------------|
| `hook_event`       | type                                                               |
| `hook_name`        | full name incl. matcher, e.g. `PreToolUse:Write`                   |
| `num_hooks`        | matching hook commands                                             |
| `managed_only`     | `true` when only managed-policy hooks allowed                      |
| `hook_source`      | `policySettings` · `merged`                                        |
| `safe_mode`        | *(v2.1.169+)*                                                      |
| `hook_definitions` | JSON (only with detailed beta tracing + `OTEL_LOG_TOOL_DETAILS=1`) |

### `hook_execution_complete`

| Attr                                                                        | Values                           |
|-----------------------------------------------------------------------------|----------------------------------|
| `hook_event`, `hook_name`, `num_hooks`                                      | as above                         |
| `num_success` / `num_blocking` / `num_non_blocking_error` / `num_cancelled` | outcome counts                   |
| `total_duration_ms`                                                         | wall-clock of all matching hooks |
| `managed_only`, `hook_source`, `safe_mode`, `hook_definitions`              | as above                         |

### `hook_plugin_metrics` (official-marketplace plugins only)

| Attr                     | Values                                                |
|--------------------------|-------------------------------------------------------|
| `plugin_id`              | `<name>@<marketplace>`                                |
| `hook_event`             | emitting hook event                                   |
| *(up to 20 custom keys)* | names `^[a-z][a-z0-9_]{0,39}$`, boolean/number values |
