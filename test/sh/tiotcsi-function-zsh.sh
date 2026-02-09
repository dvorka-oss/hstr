#!/usr/bin/env bash
#
# Copyright (C) 2014-2026 Martin Dvorak <martin.dvorak@mindforger.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# ##################################################################
# EXAMPLE: NOT WORKING version

# Define a function to replace a word in the current line
replace-word() {
  local oldword newword
  zle -I # switch to insert mode
  read -k "oldword?Enter word to replace: "
  read -k "newword?Enter replacement word: "
  BUFFER=${BUFFER//$oldword/$newword} # replace old word with new word
  zle redisplay # update the display
}

# Bind the function to a key sequence
bindkey '^Xr' replace-word

# ##################################################################
#
# EXAMPLE: WORKING version w/ foo HSTR

foohstr() {
    echo "command-by-hstr-${1}"
}

hstrnotiocsti() {
  local word
  # we need the WHOLE buffer, not just 0 to cursor: word=${BUFFER[0,CURSOR]}
  BUFFER="$(foohstr ${BUFFER})"
  CURSOR=${#BUFFER}
  # update the display
  zle redisplay
}

# create ZLE widget ~ readline function
zle -N hstrnotiocsti
# bind widget to keyboard shortcut
bindkey '\C-r' hstrnotiocsti

# ##################################################################
#
# EXAMPLE: WORKING minimal production version w/ foo HSTR
#
# PROBLEM:
# - active ZLE takes over the terminal input & output streams
# - attempt to run HSTR using $(), ``, ... BLOCKS active ZLE progress
# - w/o ZLE it is not possible to insert text into the terminal
#
# SOLUTION:
# - HSTR input: can be enable by reading from </dev/tty
# - HSTR output: is sent to stderr (as stdout is occupied by Curses)

hstr_notiocsti() {
    zle -I
    TMPFILE=$(mktemp)
    </dev/tty hstr ${BUFFER} 2> ${TMPFILE}
    BUFFER="$(cat ${TMPFILE})"
    CURSOR=${#BUFFER}
    zle redisplay
    rm TMPFILE > /dev/null 2>&1
}
zle -N hstr_notiocsti
bindkey '\C-r' hstr_notiocsti

export HSTR_TIOCSTI=n

# ##################################################################
#
# EXAMPLE: WORKING minimal production version w/ foo HSTR
#
# PROBLEM:
# - active ZLE takes over the terminal input & output streams
# - attempt to run HSTR using $(), ``, ... BLOCKS active ZLE progress
# - w/o ZLE it is not possible to insert text into the terminal
#
# SOLUTION:
# - HSTR input: can be enable by reading from </dev/tty
# - HSTR output: we use CUSTOM file handle to get stderr output ONLY
#   1. 2>&1 ... redirect stderr to stdout
#   2. 1>&3 ... redirect stdout to custom file handle
#               (thus ONLY stderr is sent to stdout)
#   3. 3>&- ... close custom file handle
#               (thus close stdout i.e. stdout won't be sent anywhere)
#   { ... } ... to execute in the current shell & set HSTR_OUT
#   3>&1    ... restore stdout to custom file handle

hstr_no_tiocsti() {
    zle -I
    { HSTR_OUT="$( { </dev/tty hstr ${BUFFER}; echo -n x >&2; } 2>&1 1>&3 3>&-; )"; } 3>&1;
    HSTR_OUT="${HSTR_OUT%x}"
    if [[ "${HSTR_OUT}" == *$'\n' ]]; then
        BUFFER="${HSTR_OUT%$'\n'}"
        CURSOR=${#BUFFER}
        zle redisplay
        zle accept-line
    else
        BUFFER="${HSTR_OUT}"
        CURSOR=${#BUFFER}
        zle redisplay
    fi
}
zle -N hstr_no_tiocsti
bindkey '\C-r' hstr_no_tiocsti

# eof
