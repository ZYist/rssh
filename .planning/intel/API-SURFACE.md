# API Surface

> Generated from `.planning/intel/api-map.json`. Do not edit by hand.

## `list_profiles`

- **method:** TAURI
- **path:** list_profiles
- **params:** 
- **file:** src-tauri/src/commands/profile.rs
- **description:** List all SSH profiles

## `get_profile`

- **method:** TAURI
- **path:** get_profile
- **params:** id
- **file:** src-tauri/src/commands/profile.rs
- **description:** Get a single SSH profile by id

## `create_profile`

- **method:** TAURI
- **path:** create_profile
- **params:** profile
- **file:** src-tauri/src/commands/profile.rs
- **description:** Create a new SSH profile

## `update_profile`

- **method:** TAURI
- **path:** update_profile
- **params:** profile
- **file:** src-tauri/src/commands/profile.rs
- **description:** Update an existing SSH profile

## `delete_profile`

- **method:** TAURI
- **path:** delete_profile
- **params:** id
- **file:** src-tauri/src/commands/profile.rs
- **description:** Delete an SSH profile

## `list_credentials`

- **method:** TAURI
- **path:** list_credentials
- **params:** 
- **file:** src-tauri/src/commands/profile.rs
- **description:** List all credentials

## `create_credential`

- **method:** TAURI
- **path:** create_credential
- **params:** credential
- **file:** src-tauri/src/commands/profile.rs
- **description:** Create a credential

## `update_credential`

- **method:** TAURI
- **path:** update_credential
- **params:** credential
- **file:** src-tauri/src/commands/profile.rs
- **description:** Update a credential

## `delete_credential`

- **method:** TAURI
- **path:** delete_credential
- **params:** id
- **file:** src-tauri/src/commands/profile.rs
- **description:** Delete a credential

## `import_ssh_config`

- **method:** TAURI
- **path:** import_ssh_config
- **params:** path
- **file:** src-tauri/src/commands/profile.rs
- **description:** Import profiles from an ssh config file (Include glob expansion)

## `import_ssh_entries`

- **method:** TAURI
- **path:** import_ssh_entries
- **params:** entries
- **file:** src-tauri/src/commands/profile.rs
- **description:** Import parsed ssh entries as profiles+credentials

## `ssh_connect`

- **method:** TAURI
- **path:** ssh_connect
- **params:** profile_id, tab_id
- **file:** src-tauri/src/commands/session.rs
- **description:** Open an SSH session to a profile

## `ssh_write`

- **method:** TAURI
- **path:** ssh_write
- **params:** tab_id, data
- **file:** src-tauri/src/commands/session.rs
- **description:** Write bytes to an SSH channel

## `ssh_resize`

- **method:** TAURI
- **path:** ssh_resize
- **params:** tab_id, cols, rows
- **file:** src-tauri/src/commands/session.rs
- **description:** Resize an SSH pty

## `ssh_disconnect`

- **method:** TAURI
- **path:** ssh_disconnect
- **params:** tab_id
- **file:** src-tauri/src/commands/session.rs
- **description:** Close an SSH session

## `ssh_auth_respond`

- **method:** TAURI
- **path:** ssh_auth_respond
- **params:** tab_id, answers
- **file:** src-tauri/src/commands/session.rs
- **description:** Respond to an interactive keyboard-auth challenge

## `ssh_passphrase_respond`

- **method:** TAURI
- **path:** ssh_passphrase_respond
- **params:** tab_id, passphrase
- **file:** src-tauri/src/commands/session.rs
- **description:** Respond to a private-key passphrase prompt

## `ssh_host_key_respond`

- **method:** TAURI
- **path:** ssh_host_key_respond
- **params:** tab_id, answer
- **file:** src-tauri/src/commands/session.rs
- **description:** Respond to an unknown-host-key TOFU prompt

## `pty_spawn`

- **method:** TAURI
- **path:** pty_spawn
- **params:** tab_id, shell, cols, rows
- **file:** src-tauri/src/commands/pty.rs
- **description:** Spawn a local PTY shell (desktop only)

## `pty_write`

- **method:** TAURI
- **path:** pty_write
- **params:** tab_id, data
- **file:** src-tauri/src/commands/pty.rs
- **description:** Write to a local PTY

## `pty_resize`

- **method:** TAURI
- **path:** pty_resize
- **params:** tab_id, cols, rows
- **file:** src-tauri/src/commands/pty.rs
- **description:** Resize a local PTY

## `pty_close`

- **method:** TAURI
- **path:** pty_close
- **params:** tab_id
- **file:** src-tauri/src/commands/pty.rs
- **description:** Close a local PTY

## `list_shells`

- **method:** TAURI
- **path:** list_shells
- **params:** 
- **file:** src-tauri/src/commands/pty.rs
- **description:** List detected local shells (cached at startup)

## `serial_open`

- **method:** TAURI
- **path:** serial_open
- **params:** profile, tab_id
- **file:** src-tauri/src/commands/serial.rs
- **description:** Open a serial port console (desktop only)

## `serial_list_ports`

- **method:** TAURI
- **path:** serial_list_ports
- **params:** 
- **file:** src-tauri/src/commands/serial.rs
- **description:** Enumerate available serial ports

## `telnet_open`

- **method:** TAURI
- **path:** telnet_open
- **params:** profile, tab_id
- **file:** src-tauri/src/commands/telnet.rs
- **description:** Open a telnet TCP session (all platforms)

## `telnet_write`

- **method:** TAURI
- **path:** telnet_write
- **params:** tab_id, data
- **file:** src-tauri/src/commands/telnet.rs
- **description:** Write to a telnet session

## `telnet_close`

- **method:** TAURI
- **path:** telnet_close
- **params:** tab_id
- **file:** src-tauri/src/commands/telnet.rs
- **description:** Close a telnet session

## `sftp_connect`

- **method:** TAURI
- **path:** sftp_connect
- **params:** profile_id
- **file:** src-tauri/src/commands/sftp.rs
- **description:** Open an SFTP channel over a new SSH connection

## `sftp_connect_session`

- **method:** TAURI
- **path:** sftp_connect_session
- **params:** tab_id
- **file:** src-tauri/src/commands/sftp.rs
- **description:** Open SFTP over an existing SSH session tab

## `sftp_list`

- **method:** TAURI
- **path:** sftp_list
- **params:** handle_id, path
- **file:** src-tauri/src/commands/sftp.rs
- **description:** List remote directory entries

## `sftp_download`

- **method:** TAURI
- **path:** sftp_download
- **params:** handle_id, remote, local
- **file:** src-tauri/src/commands/sftp.rs
- **description:** Download a remote file to local

## `sftp_upload`

- **method:** TAURI
- **path:** sftp_upload
- **params:** handle_id, local, remote
- **file:** src-tauri/src/commands/sftp.rs
- **description:** Upload a local file to remote

## `sftp_download_to`

- **method:** TAURI
- **path:** sftp_download_to
- **params:** handle_id, remote, stream_to
- **file:** src-tauri/src/commands/sftp.rs
- **description:** Stream a remote file to a path (desktop) or content URI (mobile)

## `sftp_upload_from`

- **method:** TAURI
- **path:** sftp_upload_from
- **params:** handle_id, remote, stream_from
- **file:** src-tauri/src/commands/sftp.rs
- **description:** Stream a path/content URI to remote

## `sftp_cancel_transfer`

- **method:** TAURI
- **path:** sftp_cancel_transfer
- **params:** transfer_id
- **file:** src-tauri/src/commands/sftp.rs
- **description:** Cancel an in-progress SFTP transfer

## `forward_start`

- **method:** TAURI
- **path:** forward_start
- **params:** id
- **file:** src-tauri/src/commands/forward.rs
- **description:** Start an SSH port forward (local/remote/dynamic)

## `forward_stop`

- **method:** TAURI
- **path:** forward_stop
- **params:** id
- **file:** src-tauri/src/commands/forward.rs
- **description:** Stop an active port forward

## `forward_stats`

- **method:** TAURI
- **path:** forward_stats
- **params:** id
- **file:** src-tauri/src/commands/forward.rs
- **description:** Byte counters for an active forward

## `get_setting`

- **method:** TAURI
- **path:** get_setting
- **params:** key
- **file:** src-tauri/src/commands/settings.rs
- **description:** Read a setting from the settings table

## `set_setting`

- **method:** TAURI
- **path:** set_setting
- **params:** key, value
- **file:** src-tauri/src/commands/settings.rs
- **description:** Write a setting to the settings table

## `list_recordings`

- **method:** TAURI
- **path:** list_recordings
- **params:** 
- **file:** src-tauri/src/commands/settings.rs
- **description:** List saved asciicast session recordings

## `read_recording`

- **method:** TAURI
- **path:** read_recording
- **params:** name
- **file:** src-tauri/src/commands/settings.rs
- **description:** Read a recording file for playback

## `list_fonts`

- **method:** TAURI
- **path:** list_fonts
- **params:** 
- **file:** src-tauri/src/commands/settings.rs
- **description:** Enumerate system fonts via fontdb

## `export_config`

- **method:** TAURI
- **path:** export_config
- **params:** passphrase
- **file:** src-tauri/src/commands/sync.rs
- **description:** Export encrypted config backup (Argon2id KDF + ChaCha20-Poly1305)

## `import_config`

- **method:** TAURI
- **path:** import_config
- **params:** data, passphrase
- **file:** src-tauri/src/commands/sync.rs
- **description:** Import encrypted config backup

## `github_push`

- **method:** TAURI
- **path:** github_push
- **params:** repo, token, gist
- **file:** src-tauri/src/commands/sync.rs
- **description:** Push encrypted config to a GitHub gist

## `github_pull`

- **method:** TAURI
- **path:** github_pull
- **params:** repo, token, gist
- **file:** src-tauri/src/commands/sync.rs
- **description:** Pull encrypted config from a GitHub gist

## `webdav_push`

- **method:** TAURI
- **path:** webdav_push
- **params:** url, user, password
- **file:** src-tauri/src/commands/sync.rs
- **description:** Push encrypted config to a WebDAV server

## `webdav_pull`

- **method:** TAURI
- **path:** webdav_pull
- **params:** url, user, password
- **file:** src-tauri/src/commands/sync.rs
- **description:** Pull encrypted config from a WebDAV server

## `ai_session_start`

- **method:** TAURI
- **path:** ai_session_start
- **params:** tab_id, kind, target
- **file:** src-tauri/src/ai/commands.rs
- **description:** Start an AI diagnose session bound to a terminal tab

## `ai_user_message`

- **method:** TAURI
- **path:** ai_user_message
- **params:** session_id, text
- **file:** src-tauri/src/ai/commands.rs
- **description:** Send a user message to an AI session (streams response)

## `ai_command_result`

- **method:** TAURI
- **path:** ai_command_result
- **params:** session_id, approved, output
- **file:** src-tauri/src/ai/commands.rs
- **description:** Report approved-command execution result to AI

## `ai_cancel_stream`

- **method:** TAURI
- **path:** ai_cancel_stream
- **params:** session_id
- **file:** src-tauri/src/ai/commands.rs
- **description:** Cancel an in-flight AI LLM stream

## `ai_settings_get`

- **method:** TAURI
- **path:** ai_settings_get
- **params:** 
- **file:** src-tauri/src/ai/commands.rs
- **description:** Read AI BYOK preferences (provider/model/endpoint) and api_key presence

## `ai_settings_set`

- **method:** TAURI
- **path:** ai_settings_set
- **params:** settings
- **file:** src-tauri/src/ai/commands.rs
- **description:** Write AI BYOK preferences (api_key goes to secret_store)

## `ai_list_models`

- **method:** TAURI
- **path:** ai_list_models
- **params:** provider
- **file:** src-tauri/src/ai/commands.rs
- **description:** List available models for a provider/endpoint

## `ai_audit_get`

- **method:** TAURI
- **path:** ai_audit_get
- **params:** session_id
- **file:** src-tauri/src/ai/commands.rs
- **description:** Retrieve the saved audit log for an AI session

## `ai_conversation_timeline`

- **method:** TAURI
- **path:** ai_conversation_timeline
- **params:** id
- **file:** src-tauri/src/ai/commands.rs
- **description:** Load a saved AI conversation timeline

## `cli_status`

- **method:** TAURI
- **path:** cli_status
- **params:** 
- **file:** src-tauri/src/commands/cli.rs
- **description:** Check whether the rssh CLI binary is installed

## `cli_install`

- **method:** TAURI
- **path:** cli_install
- **params:** 
- **file:** src-tauri/src/commands/cli.rs
- **description:** Install the rssh CLI binary to PATH

## `open_tab_in_new_window`

- **method:** TAURI
- **path:** open_tab_in_new_window
- **params:** clone
- **file:** src-tauri/src/commands/window.rs
- **description:** Open a tab in a new native window (desktop); binds windows to move together

## `clipboard_read`

- **method:** TAURI
- **path:** clipboard_read
- **params:** 
- **file:** src-tauri/src/commands/window.rs
- **description:** Read system clipboard (arboard, desktop only)

## `clipboard_write`

- **method:** TAURI
- **path:** clipboard_write
- **params:** text
- **file:** src-tauri/src/commands/window.rs
- **description:** Write system clipboard (arboard, desktop only)

## `open_external_url`

- **method:** TAURI
- **path:** open_external_url
- **params:** url
- **file:** src-tauri/src/commands/external.rs
- **description:** Open an external http(s) URL via tauri-plugin-opener

## `fetch_latest_release_tag`

- **method:** TAURI
- **path:** fetch_latest_release_tag
- **params:** 
- **file:** src-tauri/src/commands/update.rs
- **description:** Check GitHub for the latest release tag (background update polling)
