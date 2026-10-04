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

---

## License

MIT
