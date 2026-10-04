# lib/normalize/agy.jq
# Normalizes Google Antigravity (agy) stream-json or single-json into Common Benchmark Schema v1.0.0

# Ingest all input events into an array
[inputs] as $events
| ($events | map(select(. != null))) as $valid_events

# Extract init event
| ($valid_events | map(select(.event == "init")) | last) as $init_event
| ($valid_events | map(select(.event == "result")) | last) as $result_event
| ($valid_events | map(select(.event == "step_update" and .step_update.state == "DONE" and .step_update.usage != null)) | last) as $last_step_done

# Extract conversation id
| (
    ($result_event.result.conversation_id // empty)
    // ($last_step_done.step_update.conversation_id // empty)
    // ($init_event.conversation_id // empty)
    // ($valid_events | map(.conversation_id // empty) | first)
    // ""
  ) as $conv_id

# Extract target repo / cwd
| (
    ($init_event.init.cwd // empty)
    // ($valid_events | map(.init.cwd // empty) | first)
    // ($ARGS.named.target_repo // "")
  ) as $cwd

# Extract elapsed seconds
| (
    ($result_event.result.duration_seconds // empty)
    // ($last_step_done.step_update.duration_seconds // empty)
    // 0.0
  ) as $elapsed_sec

# Extract response text
| (
    ($result_event.result.response // empty)
    // (
        [ $valid_events[] | select(.step_update.text_delta != null) | .step_update.text_delta ]
        | join("")
       )
    // ""
  ) as $response_text

# Extract thinking text
| (
    [
      $valid_events[]
      | (.thinking // .thought // .step_update.thinking // .step_update.thought // empty)
    ]
    | join("\n")
  ) as $thinking_text

# Extract usage
| (
    ($result_event.result.usage // empty)
    // ($last_step_done.step_update.usage // empty)
    // {}
  ) as $usage

| ($usage.input_tokens // $usage.prompt_tokens // 0) as $in_tokens
| ($usage.output_tokens // $usage.completion_tokens // 0) as $out_tokens
| ($usage.thinking_tokens // $usage.thought_tokens // 0) as $th_tokens
| ($usage.cache_read_tokens // 0) as $cache_read_tokens
| ($usage.cache_write_tokens // 0) as $cache_write_tokens
| ($usage.total_tokens // ($in_tokens + $out_tokens)) as $tot_tokens

# Tools / Commands extraction
| [
    $valid_events[]
    | (
        .tool_calls // .step_update.tool_calls // []
        | if type == "array" then .[] else . end
      ),
      (
        .tool_info // .step_update.tool_info // empty
      )
  ] as $raw_tools

| [
    range(0; $raw_tools | length) as $i
    | $raw_tools[$i] as $t
    | ($t.name // $t.tool_name // "unknown") as $t_name
    | ($t.args // $t.parameters // {}) as $t_args
    | (
        if $t_name == "run_command" then
          ($t_args.CommandLine // $t_args.command // $t_args.cmd // "")
        elif ($t_name | test("view_file|replace_file_content|write_to_file")) then
          ($t_args.AbsolutePath // $t_args.TargetFile // $t_args.path // "")
          | split("/") | last // ""
          | ($t_name + " " + .)
        elif $t_name == "grep_search" then
          ("grep '" + ($t_args.query // "") + "'")
        else
          ($t_name + " " + (($t_args | tostring)[0:60]))
        end
      ) as $cmd_str
    | ($t.output // "") as $t_out
    | ($t_out | length) as $t_chars
    | (if $t_chars == 0 then 0 else [1, (($t_chars / 2.5) | floor)] | max end) as $t_tokens
    | {
        step: ($i + 1),
        tool: $t_name,
        command: (if $cmd_str == "" then $t_name else $cmd_str end),
        args: $t_args,
        output_chars: $t_chars,
        consumed_tokens: $t_tokens,
        output_preview: (if $t_chars > 160 then ($t_out[0:160] + "...") else $t_out end)
      }
  ] as $tools

| ($tools | map(.consumed_tokens) | add // 0) as $cmd_tokens

# Breakdown calculation and fallbacks
| ($ARGS.named.prompt // "") as $prompt_str
| (if ($prompt_str | length) == 0 then 0 else [1, ((($prompt_str | length) / 2.5) | floor)] | max end) as $prompt_tokens

| (
    if $th_tokens > 0 then
      $th_tokens
    elif ($thinking_text | length) > 0 then
      [1, ((($thinking_text | length) / 2.5) | floor)] | max
    else
      0
    end
  ) as $final_thought_tokens

| (
    if $out_tokens > $final_thought_tokens then
      $out_tokens - $final_thought_tokens
    elif $out_tokens > 0 then
      0
    elif ($response_text | length) > 0 then
      [1, ((($response_text | length) / 2.5) | floor)] | max
    else
      0
    end
  ) as $final_resp_tokens

| (
    if $in_tokens > 0 then
      $in_tokens
    else
      $prompt_tokens + $cmd_tokens
    end
  ) as $final_in_tokens

| (
    if $out_tokens > 0 then
      $out_tokens
    else
      $final_thought_tokens + $final_resp_tokens
    end
  ) as $final_out_tokens

| (
    if $tot_tokens > 0 then
      $tot_tokens
    else
      $final_in_tokens + $final_out_tokens
    end
  ) as $final_total_tokens

| (
    [0, ($final_in_tokens - $prompt_tokens - $cache_read_tokens - $cmd_tokens)] | max
  ) as $base_context_tokens

# Build Common Schema v1.0.0 object
| {
    version: "1.0.0",
    metadata: {
      agent: "agy",
      timestamp: ($ARGS.named.timestamp // (now | todateiso8601)),
      target_repo: (if $cwd != "" then $cwd else ($ARGS.named.target_repo // null) end),
      run_id: (if $conv_id != "" then $conv_id else ($ARGS.named.run_id // null) end)
    },
    benchmark: {
      id: ($ARGS.named.id // "P1"),
      title: ($ARGS.named.title // "Benchmark Prompt"),
      prompt: $prompt_str,
      model: ($ARGS.named.model // "default"),
      effort: ($ARGS.named.effort // "default"),
      elapsed_sec: ($elapsed_sec | (if type == "number" then (. * 100 | round / 100) else 0.0 end)),
      exit_code: 0
    },
    tokens: {
      input_tokens: $final_in_tokens,
      output_tokens: $final_out_tokens,
      total_tokens: $final_total_tokens,
      cache_read_tokens: $cache_read_tokens,
      cache_write_tokens: $cache_write_tokens,
      breakdown: {
        prompt_tokens: $prompt_tokens,
        cmd_tokens: $cmd_tokens,
        base_context_tokens: $base_context_tokens,
        cache_read_tokens: $cache_read_tokens,
        thought_tokens: $final_thought_tokens,
        response_tokens: $final_resp_tokens
      }
    },
    cost: {
      currency: "USD",
      estimated_cost_usd: 0.0
    },
    tools: $tools,
    tool_calls_count: ($tools | length),
    thinking: $thinking_text,
    response: $response_text
  }
