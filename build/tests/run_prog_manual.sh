#! /bin/sh
#
# run_prog_manual.sh gnucobol/tests
#
# Copyright (C) 2014-2022 Free Software Foundation, Inc.
# Written by Edward Hart, Simon Sobisch
#
# This file is part of GnuCOBOL.
#
# The GnuCOBOL compiler is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# GnuCOBOL is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GnuCOBOL.  If not, see <https://www.gnu.org/licenses/>.

# Running test program "prog" in a detached terminal and pass its return
# code to the testsuite after the terminal ends.

# You may change run_prog_manual.sh according to you needs, especially
# if you want to use a different terminal/terminal manager than xterm/screen
# or different options for these.

abs_top_builddir="/home/a7medmaher/Github/gnucobol/build"

TIMEOUT=30        # timeout in seconds

if test ! -z "$MSYSTEM"; then
  SLEEP_SCALE=1     # always possible, done in MSYS to reduce number of spawned processes
else
  SLEEP_SCALE=0.1   # needs a "modern" sleep implementation
fi

# Note: DESC is passed by the caller
TITLE="GnuCOBOL Manual Test Run - $DESC"

_test_with_xterm () {
   xterm -T "$TITLE" \
        -fa 'Liberation Mono' -fs 14 \
        -e "bash -c \"(\$COBCRUN_DIRECT $1 2>./syserr.log && echo \$? > ./result) || echo 1 > ./result\""
}


# Note: when using screen manager you have to
#       run `screen -r "GCTESTS"` in a separate terminal
#       within 5 seconds after starting the tests
_test_with_screen () {
  # check if screen session already exists, setup if not 
  screen -S "GCTESTS" -X select . 2>/dev/null 1>&2
  if test $? -ne 0; then
     # Note: you may need to adjust screen's terminal to get an output matching the actual running code later
     screen -dmS "GCTESTS" -t "$TITLE"
     # we have a fresh environment there - source the test config once
     screen -S "GCTESTS" -X stuff ". \"${abs_top_builddir}/tests/atconfig\" && . \"${abs_top_builddir}/tests/atlocal\"
"
     sleep 5
  fi
  # run actual test in screen session
  screen -S "GCTESTS" -X title $"TITLE"
  screen -S "GCTESTS" -X exec ... bash -c "cd \"$PWD\" && ($COBCRUN_DIRECT $* 2>./syserr.log && echo $? > ./result) || echo 1 > ./result"
}


_test_with_cmd () {
  # run cmd to start a detached cmd (via cmd's start), and execute the tests there
  cmd.exe /c "start \"$TITLE\" /wait cmd /v:on /c \"$COBCRUN_DIRECT $(echo $* | tr '/' '\\') 2>syserr.log & echo !errorlevel! >result\""
  #if test -f ./syserr.log; then
  #  dos2unix -q ./syserr.log
  #fi
}

# wait TIMEOUT seconds for the result file to be available
_wait_result () {
  local wait_time=$TIMEOUT
  if test "x$SLEEP_SCALE" = "x0.1"; then
    wait_time=$(expr $((wait_time)) \* 10)
  fi
  until test $((wait_time)) -eq 0 -o -f "./result"; do
    sleep "$SLEEP_SCALE"
    wait_time=$(expr $((wait_time)) - 1)
  done
  test ! $((wait_time)) -eq 0
}


# actual test

rm -f ./result ./syserr.log
if test ! -z "$DISPLAY"; then
  _test_with_xterm  $* || echo $? > ./result
elif test ! -z "$MSYSTEM"; then
  _test_with_cmd    $* || echo $? > ./result
else
  _test_with_screen $* || echo $? > ./result
fi

_wait_result || {
  (>&2 echo "No result file after waiting for $TIMEOUT seconds!")
  if test ! -z "$DISPLAY"; then
    screen -S "GCTESTS" -X kill
  fi
  echo 124 > ./result
}
if test -f ./syserr.log; then
  (>&2 cat ./syserr.log)
fi
exit "$(cat ./result)"
