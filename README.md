# yojitsu.zsh

`yojitsu.zsh` is a lightweight benchmark and reporting tool written in `zsh` and `jq` to evaluate the cost-performance and token efficiency of AI coding agents (Claude Code, GitHub Copilot CLI, Google Antigravity, etc.) using their execution logs.

---

## Requirements

- `zsh`
- `jq`

---

## Installation

TBD

---

## Usage

Execute benchmarks against an AI coding agent, print a terminal summary, and generate an HTML report:

```zsh
# Run a single prompt
yojitsu run --agent agy --prompt "Find where callbacks are defined"

# Run multiple prompts from a JSON file
yojitsu run --prompts-json prompts.json
```

### Example

```zsh
$ ./bin/yojitsu run --agent agy --prompt "how to create zsh one liner"
============================================================
yojitsu Benchmark Dashboard
  Target Workspace : /Users/yasuhiroki/yojitsu
  Target Agent     : agy
  Prompts to run   : 1
  Output Directory : /Users/yasuhiroki/yojitsu/reports/20261005_010420_001
============================================================
[INFO] Executing [1/1] [P1] Prompt 1...

============================================================================================================================
Execution Summary
============================================================================================================================
Variant / Title            | Agent   | Model            | Effort | Time    | Total    | In (Cmd/Base)    | Out (Think/Resp) | Commands
----------------------------------------------------------------------------------------------------------------------------
Prompt 1                   | agy     | default          | default | 9.75s   | 18,546   | 0 / 16,464       | 1,049 / 1,027    | 0 cmds
----------------------------------------------------------------------------------------------------------------------------
Total Runs: 1 | Total Elapsed: 9.75s
============================================================================================================================

[SUCCESS] HTML report generated: file:///Users/yasuhiroki/yojitsu/reports/20261005_010420_001/index.html
[Done] Benchmark complete. Outputs saved to: /Users/yasuhiroki/yojitsu/reports/20261005_010420_001
```

---

## License

MIT
