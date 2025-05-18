/*
 hstr_curses.c   Curses utilities

 Copyright (C) 2014-2025 Martin Dvorak <martin.dvorak@mindforger.com>

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

#include "include/hstr_curses.h"

// http://pueblo.sourceforge.net/doc/manual/ansi_color_codes.html
static bool terminalHasColors=FALSE;

FILE* hstr_curses_start(bool ttyInit) {
    FILE *tty_in = NULL;

    // if HSTR is reading input from pipe, then ncurses must be initialized with /dev/tty
    if(ttyInit) {
        SCREEN *screen;

        tty_in = fopen("/dev/tty", "r");
        if (!tty_in) {
            perror("Could not open /dev/tty prior to curses initialization");
            return NULL;
        }

        screen = newterm(NULL, stdout, tty_in);
        if (!screen) {
            fprintf(stderr, "Error initializing curses when HSTR is reading from pipe");
            fclose(tty_in);
            return NULL;
        }
        set_term(screen);
    } else {
        initscr();
    }

    keypad(stdscr, TRUE);
    noecho();
    nonl(); // prevent carriage return from being mapped to newline
    terminalHasColors=has_colors();
    if(terminalHasColors) {
        start_color();
        use_default_colors();
    }

#if defined(NCURSES_EXT_FUNCS) && NCURSES_EXT_FUNCS >= 20081102
    /*
     * Use ncurses specific function to make delay after pressing escape key
     * unnoticeable. Can be zero, but in some corner cases multiple bytes
     * composing a functional key code might be handled to the application with
     * a delay, so small delay is safer.
     */
    set_escdelay(5);
#endif

    return tty_in;
}

bool terminal_has_colors(void) {
    return terminalHasColors;
}

void hstr_curses_stop(bool keepPage) {
    if(!keepPage) {
        clear();
    }
    refresh();
    doupdate();
    endwin();

    /* On ncurses memory leaks
     *
     * The ncurses configure script has an option, --disable-leaks, which you can
     * use to continue the analysis. It tells ncurses to free memory if possible.
     * However, most of the in-use memory is "permanent".
     *
     * Any implementation of curses must not free the memory associated with a screen,
     * since (even after calling endwin()), it must be available for use in the next
     * call to refresh(). There are also chunks of memory held for performance reasons.
     * That makes it hard to analyze curses applications for memory leaks. To work
     * around this, build a debugging version of the ncurses library which frees those
     * chunks which it can, and provides the _nc_free_and_exit() function to free the
     * remainder on exit. The ncurses utility and test programs use this
     * feature, e.g., via the ExitProgram() macro.
     */
}
