---
name: crownos-secrets
description: Use the user's stored passwords, API keys and tokens on CrownOS by name, through the crownos-secrets MCP server, without seeing a value - list the names, ask the user for a missing secret, type a password into a login form through computer use, call an API through the HTTPS proxy, or run a registered command. Use whenever a task needs a password, a key, a token or a login.
---

# Secrets on CrownOS

## What a secret is

A secret is a password, an API key, a token, a user name or a note that the user stored in the
CrownOS vault. Each secret has a name, for example `github_token`. Its rules tell which agents can
use it, and where: app ids, web origins, HTTP hosts.

You use a secret by its name. CrownOS puts the value where it must go. No tool gives you the
value, and no tool can.

## Rules

- Never ask the user to paste a password, a key or a token into the chat.
- Never ask the user to type a secret into a terminal or a file for you.
- Never put a value in a command line, a file, an environment variable or a message. You do not
  have the value, so do not guess it and do not search for it.
- Do not try to read a value back. Do not read a filled password field, a process environment or
  the vault file.
- If CrownOS refuses a use, stop. Tell the user why. Do not try another way.

## Tools

The `crownos-secrets` MCP server has these tools:

| Tool | Use |
|---|---|
| `secrets_list` | The names, kinds and rules of the stored secrets. Call it first. |
| `secrets_status` | Whether the vault is locked, and your open requests. |
| `secrets_request {name, kind, purpose}` | Ask the user to add a secret that is missing. `kind` is `password`, `api-key`, `token`, `env`, `note` or `username`. Say why in `purpose`. |
| `secrets_http_session {names, ttl_minutes}` | Start an HTTPS proxy. Requests to a secret's bound host get the key in a header. The result gives the proxy URL and the CA file to trust. Responses come back with the secrets removed. |
| `secrets_templates` | The command templates that the user registered. |
| `secrets_run {template, arguments, cwd}` | Run a registered template in a sandbox, with secrets in its environment. The output comes back with the secrets removed. |

## Typing a password or a login

Only the `crownos-computer-use` MCP server types secrets:

- `type_secret {ref, name}` types one secret into a password element (one marked `secure`).
- `fill_login {username_ref, password_ref, username_name, password_name}` types a user name, then
  Tab, then the password.

Get the refs from a `snapshot` of the window first. The user confirms each typing in a dialog that
the compositor shows. The result gives the outcome and the page origin, never the value.

## Steps

1. Call `secrets_list`. Find the name that the task needs.
2. If the name is not there, call `secrets_request`. Tell the user to add it with
   `crownos-secrets add <name>` and to set its rules with `crownos-secrets bind`. Then wait.
3. If the vault is locked (`secrets_status`), tell the user to run `crownos-secrets unlock`.
4. Use the secret:
   - for a login form: `type_secret` or `fill_login`;
   - for an HTTPS API: `secrets_http_session`, then send the requests through the proxy;
   - for a command line tool: `secrets_run` with a registered template.
5. Tell the user which secret you used and where. Do not show a value.

## Results

A use that worked gives `{"ok": true}`. `type_secret` and `fill_login` also give `page_origin`.
Make sure that the origin is the site that you meant. Each other result is an error text that
starts with one of these words:

| Start | Meaning | What to do |
|---|---|---|
| `no stored secret has this name` | The name is wrong or missing. | Look at `secrets_list`. If it is missing, call `secrets_request`. |
| `the vault is locked` | The vault is locked. | Ask the user to run `crownos-secrets unlock`. |
| `denied:` | The rules of the secret do not allow you, this app or this page. | Stop. Tell the user. |
| `refused:` | The target is wrong: not a password field, another app, another origin, or a locked session. | Take a new snapshot and use the correct ref. If it stays refused, stop and tell the user. |
| `stopped:` | The user said no, did not answer, or the focus moved. | Do not try again at once. Ask the user. |
| `slow down:` | Too many uses. | Wait, then try one time. |
| `not available` | `crownos-secretsd` does not run, or this release cannot do this use. | Tell the user. |
