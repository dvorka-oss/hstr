# TIOCSTI Configuration Warning - Implementation Plan (Updated)

## Problem Statement

Users are experiencing issues after Linux kernel upgrades (6.2+) or HSTR upgrades where HSTR appears to "not work". The root cause is that:

1. **TIOCSTI is disabled** in modern Linux kernels (>=6.2.0) for security reasons
2. **HSTR requires configuration** when TIOCSTI is not available - specifically, shell functions must be added to `.bashrc` or `.zshrc`
3. **Users are unaware** that configuration is needed because HSTR silently degrades functionality

### Current Behavior

When TIOCSTI is not supported:
- HSTR runs normally and allows user to select a command from history
- Selected command is written to `stderr` instead of being injected into the terminal
- User sees the command printed but it's NOT in the prompt for execution
- This appears as if HSTR "doesn't work"

### Expected Behavior (Updated)

When TIOCSTI is not supported AND shell configuration is missing:
- HSTR should detect this condition BEFORE starting the interactive UI
- Display a clear warning message explaining the issue
- Show exact steps needed to configure HSTR properly
- **Give user choice to continue anyway or exit**
- Allow suppressing the warning via environment variable for advanced users/scripts

## Analysis

### Current Code Flow

1. **`hstr_main()` in `hstr.c`** (line 1766-1788):
   - Calls `is_tiocsti_supported()` to detect kernel support
   - Sets global `is_tiocsti` variable
   - Does NOT check for `HSTR_TIOCSTI` environment variable
   - Proceeds to interactive mode regardless

2. **`is_tiocsti_supported()` in `hstr_utils.c`** (line 114-144):
   - Probes kernel TIOCSTI support using `/dev/tty` and `ioctl()`
   - Returns `true` if supported, `false` otherwise
   - Already works correctly

3. **`fill_terminal_input()` in `hstr_utils.c`** (line 160-179):
   - If `is_tiocsti` is true: uses `ioctl()` to inject command
   - If `is_tiocsti` is false: writes to `stderr` (degraded mode)
   - This is where the "silent failure" occurs

4. **Configuration generation** in `hstr.c`:
   - `print_bash_install_code()` (line 347-384): Generates different config based on `is_tiocsti`
   - `print_zsh_install_code()` (line 386-427): Generates different config based on `is_tiocsti`
   - Both set `export HSTR_TIOCSTI=y` or `export HSTR_TIOCSTI=n`

### Key Insight

The `HSTR_TIOCSTI` environment variable is **generated** by the configuration scripts but **never checked** by HSTR! This is the missing piece.

## Solution Design (Updated)

### Detection Logic

HSTR should check this condition at startup:

```
IF (TIOCSTI is NOT supported by kernel) AND 
   (HSTR_TIOCSTI env var is NOT set OR != "n") AND
   (HSTR_SUPPRESS_TIOCSTI_WARNING is NOT set)
THEN
    Show configuration warning
    Prompt user: Continue anyway (c) or Exit (e)?
    IF user chooses 'e' OR timeout/no input
        Exit with instructions
    ELSE IF user chooses 'c'
        Continue to HSTR (degraded mode - commands printed but not executed)
    END IF
END IF
```

### Rationale

- **TIOCSTI supported**: No configuration needed, HSTR works natively
- **TIOCSTI not supported + HSTR_TIOCSTI=n**: User has configured the shell function, HSTR can proceed normally
- **TIOCSTI not supported + HSTR_TIOCSTI not set**: User hasn't configured HSTR, show warning with choice
- **TIOCSTI not supported + HSTR_TIOCSTI=y**: Invalid state (kernel doesn't support but user claims it does), show warning
- **HSTR_SUPPRESS_TIOCSTI_WARNING set**: Skip warning entirely (advanced users, testing, scripts)

### Warning Message Design

The warning should be:
1. **Clear and actionable**: Tell user exactly what to do
2. **Shell-specific**: Detect bash vs zsh and show appropriate command
3. **Helpful**: Include explanation of what changed and why
4. **Non-intrusive**: Only show when actually needed
5. **Interactive**: Give user choice to continue or exit
6. **Suppressible**: Can be disabled via environment variable

Example warning text:

```

=== HSTR CONFIGURATION REQUIRED ===

HSTR cannot inject commands into your shell because:

  • Your Linux kernel (>=6.2.0) has TIOCSTI disabled for security
  • Your shell configuration is missing the required HSTR function

To fix this, run the following command:

  For bash:
    hstr --show-bash-configuration >> ~/.bashrc && source ~/.bashrc

  For zsh:
    hstr --show-zsh-configuration >> ~/.zshrc && source ~/.zshrc

What this does:
  • Adds a shell function that replaces TIOCSTI functionality
  • Sets HSTR_TIOCSTI=n to indicate configuration is complete
  • Binds Ctrl-R to invoke HSTR with the new function

After configuration, HSTR will work as expected!

For more information, see: https://github.com/dvorka/hstr#configuration

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Choose an option:
  [e] Exit and configure HSTR (recommended)
  [c] Continue anyway

To suppress this warning: export HSTR_SUPPRESS_TIOCSTI_WARNING=1

Your choice [E/c]: _
```

## Implementation Plan

### Phase 1: Add Environment Variable Checks

**File**: `src/hstr.c`

**Location**: In `hstr_main()` function, after TIOCSTI detection (line ~1775)

**Changes**:
1. After setting `is_tiocsti` variable
2. Check if `is_tiocsti == false`
3. If true, check `getenv("HSTR_TIOCSTI")` and `getenv("HSTR_SUPPRESS_TIOCSTI_WARNING")`
4. If TIOCSTI env var is NULL or != "n" AND suppress flag is NOT set, call warning function
5. Warning function displays message and prompts user for choice
6. Based on user choice, either continue or exit

### Phase 2: Implement Interactive Warning Function

**File**: `src/hstr.c`

**New function**: `bool show_tiocsti_configuration_warning(void)`

**Returns**: `true` to continue, `false` to exit

**Implementation**:
1. Detect shell (bash vs zsh) using existing `is_zsh_parent_shell()`
2. Print formatted warning message to stderr
3. Show shell-specific configuration command
4. Prompt user: "Continue anyway [c] or Exit [e]?"
5. Read single character input (with timeout for safety)
6. Return true for 'c', false for 'e' or timeout
7. Mention suppression env var in the warning

### Phase 3: Add Suppression Support

**Purpose**: Allow advanced users to bypass the warning entirely

**Environment Variable**: `HSTR_SUPPRESS_TIOCSTI_WARNING`

**Implementation**:
- Check for `HSTR_SUPPRESS_TIOCSTI_WARNING` environment variable
- If set (to any value), skip warning completely
- Useful for:
  - Scripts that call HSTR programmatically
  - Advanced users who understand the limitation
  - Testing and debugging
  - Non-interactive usage where prompt would hang
  - CI/CD environments

### Phase 4: Update Documentation

**Files to update**:
1. `README.md` - Add note about TIOCSTI, configuration, and suppression
2. `CONFIGURATION.md` - Add section explaining TIOCSTI warning and options
3. `man/hstr.1` - Update man page with TIOCSTI information
4. `INSTALLATION.md` - Add post-install configuration note

## Detailed Implementation Checklist

### Code Changes

- [ ] Add `show_tiocsti_configuration_warning()` function in `src/hstr.c`
- [ ] Add TIOCSTI environment variable check in `hstr_main()` 
- [ ] Define `HSTR_ENV_VAR_TIOCSTI` constant (e.g., "HSTR_TIOCSTI")
- [ ] Define `HSTR_ENV_VAR_SUPPRESS_WARNING` constant (e.g., "HSTR_SUPPRESS_TIOCSTI_WARNING")
- [ ] Implement shell detection logic for warning message
- [ ] Add helper function to format and display warning box
- [ ] Add interactive prompt with user input (c/e choice)
- [ ] Add input timeout handling (default to exit after 30 seconds for safety)
- [ ] Return boolean from warning function (true=continue, false=exit)
- [ ] Update exit code documentation (0=success, 1=failure, 2=user chose exit)

### Warning Function Implementation

```c
#define HSTR_ENV_VAR_TIOCSTI "HSTR_TIOCSTI"
#define HSTR_ENV_VAR_SUPPRESS_WARNING "HSTR_SUPPRESS_TIOCSTI_WARNING"
#define HSTR_EXIT_CONFIG_REQUIRED 2

bool show_tiocsti_configuration_warning(void)
{
    bool is_zsh = is_zsh_parent_shell();
    const char *shell_name = is_zsh ? "zsh" : "bash";
    const char *config_cmd = is_zsh ? 
        "hstr --show-zsh-configuration >> ~/.zshrc && source ~/.zshrc" :
        "hstr --show-bash-configuration >> ~/.bashrc && source ~/.bashrc";
    
    fprintf(stderr,
        "\n"
        "╔══════════════════════════════════════════════════════════════════════╗\n"
        "║                    HSTR Configuration Required                       ║\n"
        "╚══════════════════════════════════════════════════════════════════════╝\n"
        "\n"
        "HSTR cannot inject commands into your shell because:\n"
        "\n"
        "  • Your Linux kernel has TIOCSTI disabled (kernel >= 6.2.0)\n"
        "  • Your %s configuration is missing the required HSTR function\n"
        "\n"
        "To fix this, run:\n"
        "\n"
        "  %s\n"
        "\n"
        "What this does:\n"
        "  • Adds a shell function that replaces TIOCSTI functionality\n"
        "  • Sets HSTR_TIOCSTI=n to indicate configuration is complete\n"
        "  • Binds Ctrl-R to invoke HSTR properly\n"
        "\n"
        "After configuration, HSTR will work normally!\n"
        "\n"
        "For more information:\n"
        "  https://github.com/dvorka/hstr/blob/master/CONFIGURATION.md\n"
        "\n"
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        "\n"
        "Choose an option:\n"
        "  [c] Continue anyway (commands will be printed, not executed)\n"
        "  [e] Exit and configure HSTR first (recommended)\n"
        "\n"
        "To suppress this warning: export HSTR_SUPPRESS_TIOCSTI_WARNING=1\n"
        "\n"
        "Your choice [c/e]: ",
        shell_name, config_cmd
    );
    fflush(stderr);
    
    // Read user input with timeout
    char choice = '\0';
    fd_set readfds;
    struct timeval timeout;
    
    FD_ZERO(&readfds);
    FD_SET(STDIN_FILENO, &readfds);
    
    timeout.tv_sec = 30;  // 30 second timeout
    timeout.tv_usec = 0;
    
    int ret = select(STDIN_FILENO + 1, &readfds, NULL, NULL, &timeout);
    
    if (ret > 0) {
        // Input available
        char input[10];
        if (fgets(input, sizeof(input), stdin) != NULL) {
            choice = tolower(input[0]);
        }
    } else if (ret == 0) {
        // Timeout - default to exit for safety
        fprintf(stderr, "\n\nTimeout - exiting. Run with HSTR_SUPPRESS_TIOCSTI_WARNING=1 to skip.\n");
        choice = 'e';
    } else {
        // Error - default to exit
        choice = 'e';
    }
    
    if (choice == 'c') {
        fprintf(stderr, "\nContinuing in degraded mode (commands will be printed only)...\n\n");
        return true;  // Continue
    } else {
        fprintf(stderr, "\nExiting. Please configure HSTR first.\n\n");
        return false;  // Exit
    }
}
```

### Integration Points

- [ ] Call warning function from `hstr_main()` before `hstr_interactive()`
- [ ] Only call if `is_tiocsti == false` AND env var check fails AND suppress flag not set
- [ ] Handle return value: continue to HSTR if true, exit if false
- [ ] Ensure proper exit code is used when exiting (HSTR_EXIT_CONFIG_REQUIRED)
- [ ] Test with all command-line modes (interactive, non-interactive, etc.)
- [ ] Ensure stdin is available (not closed or redirected) before prompting

### Edge Cases to Handle

- [ ] User has `HSTR_TIOCSTI=y` but kernel doesn't support (warn anyway)
- [ ] User has `HSTR_TIOCSTI=n` but kernel DOES support (allow, no warning)
- [ ] User sets `HSTR_SUPPRESS_TIOCSTI_WARNING` (skip warning entirely)
- [ ] Non-interactive mode (`--non-interactive`) - skip warning (no terminal interaction needed)
- [ ] Other command-line options (`--version`, `--help`, etc.) - skip check
- [ ] When run from within a script vs interactive terminal (check if stdin is a tty)
- [ ] Stdin redirected or closed (skip warning or default to continue)
- [ ] User interrupts prompt with Ctrl-C (handle gracefully - treat as exit)
- [ ] Timeout on prompt input (default to exit with helpful message)
- [ ] Cygwin and WSL environments (already have `is_tiocsti = false` hardcoded)

### Testing Checklist

- [ ] Test on Linux kernel < 6.2 (TIOCSTI supported) - no warning
- [ ] Test on Linux kernel >= 6.2 (TIOCSTI disabled) - warning shows with prompt
- [ ] Test with `HSTR_TIOCSTI=n` set - no warning
- [ ] Test with `HSTR_TIOCSTI=y` set on kernel >=6.2 - warning shows
- [ ] Test with `HSTR_SUPPRESS_TIOCSTI_WARNING=1` - no warning, continues silently
- [ ] Test user choosing 'c' - HSTR continues in degraded mode
- [ ] Test user choosing 'e' - HSTR exits cleanly with exit code 2
- [ ] Test prompt timeout (wait 30+ seconds) - exits with message
- [ ] Test Ctrl-C during prompt - handles gracefully (exit)
- [ ] Test invalid input (e.g., 'x', 'abc') - re-prompt or default to exit
- [ ] Test bash shell configuration flow
- [ ] Test zsh shell configuration flow
- [ ] Test non-interactive mode behavior (should skip warning)
- [ ] Test all command-line flags (`--version`, `--help`, `-k`, etc.)
- [ ] Test with stdin redirected (e.g., `echo "" | hstr`)
- [ ] Test with configuration already in `.bashrc`/`.zshrc`
- [ ] Test with partial/incorrect configuration

## Main Check in `hstr_main()`

```c
int hstr_main(int argc, char* argv[])
{
    setlocale(LC_ALL, "");

    // initialize global TIOCSTI indicator
#ifdef DEBUG_NO_TIOCSTI
    is_tiocsti = false;
#else
    is_tiocsti = is_tiocsti_supported();
#endif

    // Check if configuration warning is needed
    if (!is_tiocsti) {
        char *tiocsti_env = getenv(HSTR_ENV_VAR_TIOCSTI);
        char *suppress_warning = getenv(HSTR_ENV_VAR_SUPPRESS_WARNING);
        
        // If env var is not set, or is set to anything other than "n", show warning
        // unless suppression flag is set
        if ((!tiocsti_env || strcmp(tiocsti_env, "n") != 0) && !suppress_warning) {
            // Skip warning for certain command-line operations
            // (allow --version, --help, --show-configuration, --non-interactive etc.)
            bool skip_check = false;
            int i;
            for (i = 1; i < argc; i++) {
                if (strcmp(argv[i], "--version") == 0 || strcmp(argv[i], "-V") == 0 ||
                    strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0 ||
                    strcmp(argv[i], "--show-configuration") == 0 || strcmp(argv[i], "-s") == 0 ||
                    strcmp(argv[i], "--show-bash-configuration") == 0 || strcmp(argv[i], "-B") == 0 ||
                    strcmp(argv[i], "--show-zsh-configuration") == 0 || strcmp(argv[i], "-Z") == 0 ||
                    strcmp(argv[i], "--is-tiocsti") == 0 || strcmp(argv[i], "-t") == 0 ||
                    strcmp(argv[i], "--non-interactive") == 0 || strcmp(argv[i], "-n") == 0 ||
                    strcmp(argv[i], "--kill-last-command") == 0 || strcmp(argv[i], "-k") == 0 ||
                    strcmp(argv[i], "--show-blacklist") == 0 || strcmp(argv[i], "-b") == 0) {
                    skip_check = true;
                    break;
                }
            }
            
            // Also skip if stdin is not a tty (running in script/pipe)
            if (!skip_check && !isatty(STDIN_FILENO)) {
                skip_check = true;
            }
            
            if (!skip_check) {
                // Show warning and get user choice
                bool continue_anyway = show_tiocsti_configuration_warning();
                if (!continue_anyway) {
                    // User chose to exit
                    exit(HSTR_EXIT_CONFIG_REQUIRED);
                }
                // If user chose to continue, proceed to HSTR (degraded mode)
            }
        }
    }

    hstr=malloc(sizeof(Hstr));
    hstr_init();

    hstr_get_env_configuration();
    hstr_getopt(argc, argv);
    favorites_get(hstr->favorites);
    blacklist_load(&hstr->blacklist);
    hstr_interactive();

    return EXIT_SUCCESS;
}
```

## Exit Codes

Define clear exit codes for different scenarios:

- `0` (EXIT_SUCCESS) - Normal operation (or user chose to continue in degraded mode)
- `1` (EXIT_FAILURE) - Error occurred
- `2` (HSTR_EXIT_CONFIG_REQUIRED) - User chose to exit from configuration warning

This allows scripts to detect the configuration requirement programmatically.

**Note**: If user chooses to continue anyway, HSTR runs in degraded mode and still exits with code 0.

## Backward Compatibility

**Breaking Changes**: None

**Behavior Changes**:
- HSTR will now show interactive warning before running in degraded mode
- Users can choose to continue anyway or exit to configure
- Only affects users on kernel >=6.2 who haven't configured HSTR
- Users who already configured HSTR are unaffected
- Warning can be completely suppressed with environment variable

**Migration Path**:
- Existing users with configuration: No action needed
- New users: See warning on first run, can configure or choose to continue
- Users upgrading kernel: See warning on first run, choose configure or continue
- Scripts/automation: Set `HSTR_SUPPRESS_TIOCSTI_WARNING=1` to bypass warning

## Documentation Updates Required

### README.md
Add prominent section about TIOCSTI and configuration:
```markdown
## Important: Configuration Recommended on Modern Linux

If you're using Linux kernel 6.2.0 or newer, we **strongly recommend** 
configuring HSTR for full functionality:

# For bash
hstr --show-bash-configuration >> ~/.bashrc && source ~/.bashrc

# For zsh  
hstr --show-zsh-configuration >> ~/.zshrc && source ~/.zshrc

Why? Modern kernels disable TIOCSTI for security. Without configuration, 
HSTR will show selected commands but won't execute them.

HSTR will prompt you on first run if not configured. You can:
- Exit and configure (recommended)
- Continue in degraded mode
- Suppress the warning: `export HSTR_SUPPRESS_TIOCSTI_WARNING=1`
```

### CONFIGURATION.md
Add section explaining the warning and options:
```markdown
## TIOCSTI and Modern Linux Kernels

Starting with Linux kernel 6.2.0, the TIOCSTI system call is disabled by
default for security. HSTR uses TIOCSTI to inject commands into your shell.

### The Configuration Warning

If you haven't configured HSTR on a kernel >=6.2, you'll see an interactive 
warning with two options:

1. **[e] Exit and configure** (recommended): Configure HSTR properly so 
   selected commands execute in your shell prompt
2. **[c] Continue anyway**: Run HSTR in degraded mode - selected commands 
   will be printed but not executed

### Suppressing the Warning

For scripts, automation, or if you prefer degraded mode:

```bash
export HSTR_SUPPRESS_TIOCSTI_WARNING=1
```

Add this to your shell profile to make it permanent.

### How Configuration Works

The configuration adds a shell function that replaces TIOCSTI and sets 
`HSTR_TIOCSTI=n` to indicate proper configuration. Once configured, the 
warning won't appear.
```

### Man Page (man/hstr.1)
Add sections for:
- TIOCSTI requirement and configuration
- Environment variables (HSTR_TIOCSTI, HSTR_SUPPRESS_TIOCSTI_WARNING)
- Exit codes (0, 1, 2)
- Example usage with suppression

## Timeline

1. **Phase 1** (Day 1-2): Implement core warning functionality with user choice
2. **Phase 2** (Day 3): Add suppression support and edge case handling  
3. **Phase 3** (Day 4): Documentation updates
4. **Phase 4** (Day 5): Testing and refinement

## Success Criteria

1. ✅ Users on kernel >=6.2 without configuration see clear interactive warning
2. ✅ Users can choose to continue or exit from the warning
3. ✅ Users with proper configuration see no warning
4. ✅ Warning can be suppressed via environment variable
5. ✅ Warning message is clear, actionable, and helpful
6. ✅ No false positives (warnings when not needed)
7. ✅ No breaking changes to existing workflows
8. ✅ Documentation clearly explains all options
9. ✅ All command-line modes work correctly
10. ✅ Non-interactive contexts (scripts, pipes) skip the warning automatically

## Risk Assessment

**Low Risk**:
- Non-breaking change
- Only adds optional interactive prompt
- Easy to suppress for automation
- Easy to revert if issues arise
- Well-defined detection logic

**Mitigation**:
- Thorough testing on different kernel versions
- Clear documentation with examples
- Timeout safety (defaults to exit after 30s)
- Auto-skip for non-interactive contexts
- Community feedback during testing phase

## Future Enhancements

Consider for future releases:

1. **Auto-configuration option**: '[a] Auto-configure now' choice in prompt
2. **Function detection**: Actually check if shell function is defined
3. **Per-directory suppression**: Allow `.hstrrc` to suppress warning
4. **Remember user choice**: Store preference in `~/.hstr_config`
5. **Configuration verification**: `hstr --verify-config` command
6. **Systemd notification**: Desktop notification option instead of blocking prompt

## References

- TIOCSTI kernel discussion: https://lwn.net/Articles/884828/
- Linux kernel 6.2 release notes: TIOCSTI disabled by default
- HSTR GitHub issues related to kernel 6.2+ problems
- Security rationale for TIOCSTI removal

---

## Summary

This implementation will:

1. **Detect** when TIOCSTI is unavailable and configuration is missing
2. **Warn** users with clear, actionable instructions via interactive prompt
3. **Give users choice** to continue in degraded mode or exit to configure
4. **Allow suppression** via environment variable for advanced use cases
5. **Guide** users to configure HSTR properly
6. **Prevent** confusion and "HSTR doesn't work" reports
7. **Maintain** backward compatibility
8. **Respect** user autonomy and different use cases
9. **Improve** user experience significantly

### Key Advantages of Interactive + Suppressible Approach

✅ **User Choice**: Users decide whether to configure now or continue
✅ **Non-Blocking**: Advanced users can suppress warning entirely
✅ **Educational**: Warning explains what's happening and why
✅ **Flexible**: Works for interactive users, scripts, and automation
✅ **Smart**: Automatically skips warning in non-interactive contexts
✅ **Safe**: Timeout prevents hanging if prompt goes unnoticed

The solution is minimal, focused, and solves the root cause of user confusion
while maintaining all existing functionality and giving users full control.
