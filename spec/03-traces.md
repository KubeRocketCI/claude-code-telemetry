# Traces / Spans (Beta)

> Distributed-tracing span tree. **Beta** — off by default. Names/attributes are fixed. Emits OTel
> **GenAI semantic conventions** (`gen_ai.*`) alongside Claude Code's own attrs, so generic APM tools
> understand it. Source: <https://code.claude.com/docs/en/monitoring-usage> · snapshot 2026-07-10.

## Enable

Requires **all** of: `CLAUDE_CODE_ENABLE_TELEMETRY=1` + `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1` +
`OTEL_TRACES_EXPORTER=<otlp|console>`. The `claude_code.hook` span additionally needs
`ENABLE_BETA_TRACING_DETAILED=1` + `BETA_TRACING_ENDPOINT` (and an allowlist in interactive CLI).

## Span hierarchy

```
claude_code.interaction
├── claude_code.llm_request
├── claude_code.hook                    (detailed beta tracing only)
└── claude_code.tool
    ├── claude_code.tool.blocked_on_user
    ├── claude_code.tool.execution
    └── (Agent tool) subagent claude_code.llm_request / claude_code.tool spans
```

Each span carries a `span.type` matching its name. In Agent SDK / `claude -p` sessions,
`claude_code.interaction` becomes a **child of the caller's span** when `TRACEPARENT` is set.

## `claude_code.interaction`

| Attr                      | Meaning                               | Gate                    |
|---------------------------|---------------------------------------|-------------------------|
| `user_prompt`             | prompt text; `<REDACTED>` unless gate | `OTEL_LOG_USER_PROMPTS` |
| `user_prompt_length`      | chars                                 |                         |
| `interaction.sequence`    | 1-based counter within session        |                         |
| `interaction.duration_ms` | turn wall-clock                       |                         |

## `claude_code.llm_request`

| Attr                                          | Meaning                                                                             | Gate                    |
|-----------------------------------------------|-------------------------------------------------------------------------------------|-------------------------|
| `model`                                       | model id                                                                            |                         |
| `gen_ai.system`                               | always `anthropic` (GenAI convention)                                               |                         |
| `gen_ai.request.model`                        | = `model` (GenAI convention)                                                        |                         |
| `query_source`                                | e.g. `repl_main_thread`, subagent                                                   |                         |
| `agent_id`                                    | subagent/teammate id (absent on main)                                               |                         |
| `parent_agent_id`                             | spawning agent id (absent for main + direct children)                               |                         |
| `workflow.run_id`                             | `wf_`-prefixed (absent if not workflow-spawned)                                     |                         |
| `workflow.name`                               | workflow name (→ `custom` unless gate)                                              | `OTEL_LOG_TOOL_DETAILS` |
| `speed`                                       | `fast` · `normal`                                                                   |                         |
| `llm_request.context`                         | `interaction` · `tool` · `standalone`                                               |                         |
| `duration_ms`                                 | wall-clock incl. retries                                                            |                         |
| `ttft_ms`                                     | time to first token                                                                 |                         |
| `input_tokens` / `output_tokens`              | usage block                                                                         |                         |
| `cache_read_tokens` / `cache_creation_tokens` | cache usage                                                                         |                         |
| `request_id`                                  | Anthropic `request-id` header                                                       |                         |
| `gen_ai.response.id`                          | = `request_id` (GenAI convention)                                                   |                         |
| `client_request_id`                           | `x-client-request-id` of final attempt                                              |                         |
| `attempt`                                     | total attempts                                                                      |                         |
| `success`                                     | `true` · `false`                                                                    |                         |
| `status_code`                                 | on failure                                                                          |                         |
| `error`                                       | on failure                                                                          |                         |
| `response.has_tool_call`                      | `true` if tool-use blocks                                                           |                         |
| `stop_reason`                                 | `end_turn` · `tool_use` · `max_tokens` · `stop_sequence` · `pause_turn` · `refusal` |                         |
| `gen_ai.response.finish_reasons`              | = `stop_reason` in string array (GenAI convention)                                  |                         |

> Each retry also emits a `gen_ai.request.attempt` span event with `attempt` + `client_request_id`.

## `claude_code.tool`

| Attr                                | Meaning                                        | Gate                           |
|-------------------------------------|------------------------------------------------|--------------------------------|
| `tool_name`                         | tool name                                      |                                |
| `duration_ms`                       | incl. permission wait + execution              |                                |
| `result_tokens`                     | approx token size of result                    |                                |
| `agent_id` / `parent_agent_id`      | as llm_request                                 |                                |
| `workflow.run_id` / `workflow.name` | as llm_request                                 | `OTEL_LOG_TOOL_DETAILS` (name) |
| `tool_use_id`                       | model's `tool_use` id (matches events + hooks) |                                |
| `gen_ai.tool.call.id`               | = `tool_use_id` (GenAI convention)             |                                |
| `file_path`                         | Read/Edit/Write target                         | `OTEL_LOG_TOOL_DETAILS`        |
| `full_command`                      | Bash command                                   | `OTEL_LOG_TOOL_DETAILS`        |
| `skill_name`                        | Skill tool                                     | `OTEL_LOG_TOOL_DETAILS`        |
| `subagent_type`                     | Agent/Task tool                                | `OTEL_LOG_TOOL_DETAILS`        |

> With `OTEL_LOG_TOOL_CONTENT=1`, adds a `tool.output` span event carrying input+output bodies (60 KB/attr cap).

## `claude_code.tool.blocked_on_user`

| Attr          | Meaning                                |
|---------------|----------------------------------------|
| `duration_ms` | time waiting for permission            |
| `decision`    | `accept` · `reject`                    |
| `source`      | matches `tool_decision` event `source` |

## `claude_code.tool.execution`

| Attr                  | Meaning                                                                 | Gate                    |
|-----------------------|-------------------------------------------------------------------------|-------------------------|
| `duration_ms`         | tool body runtime                                                       |                         |
| `tool_use_id`         | = parent                                                                |                         |
| `gen_ai.tool.call.id` | = `tool_use_id` (GenAI convention)                                      |                         |
| `success`             | `true` · `false`                                                        |                         |
| `error`               | category string, e.g. `Error:ENOENT`, `ShellError` (full msg with gate) | `OTEL_LOG_TOOL_DETAILS` |

## `claude_code.hook` (detailed beta tracing only)

| Attr                                                                        | Meaning                      | Gate                    |
|-----------------------------------------------------------------------------|------------------------------|-------------------------|
| `hook_event` / `hook_name`                                                  | type / full name             |                         |
| `num_hooks`                                                                 | matching commands run        |                         |
| `hook_definitions`                                                          | JSON config                  | `OTEL_LOG_TOOL_DETAILS` |
| `duration_ms`                                                               | wall-clock of matching hooks |                         |
| `num_success` / `num_blocking` / `num_non_blocking_error` / `num_cancelled` | outcome counts               |                         |

> Content-bearing attrs (`new_context`, `system_prompt_preview`, `user_system_prompt`, `tool_input`,
> `response.model_output`) appear only under detailed beta tracing (not stable schema).
> `user_system_prompt` also needs `OTEL_LOG_USER_PROMPTS=1`.

## Span status

- `llm_request`, `tool.execution`, `hook` → status `ERROR` on failure.
- All other spans → status `UNSET`.

## Trace-context propagation (when tracing active)

- **Bash/PowerShell subprocesses** inherit `TRACEPARENT` of the active tool-execution span.
- **Model requests** carry W3C `traceparent` of the `llm_request` span — only when `ANTHROPIC_BASE_URL`
  is unset/Anthropic; for custom proxies gate with `CLAUDE_CODE_PROPAGATE_TRACEPARENT=1`.
- **Outbound HTTP MCP** requests carry `traceparent` likewise.
- API `traceresponse` header recorded as a **span link**. Header never sent to third-party providers.
- Agent SDK / `-p` sessions read inbound `TRACEPARENT`/`TRACESTATE`; **interactive sessions ignore
  inbound `TRACEPARENT`** (avoids inheriting CI/container context).
