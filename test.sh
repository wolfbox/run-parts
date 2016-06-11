#!/bin/sh
set -u

SH=${1:-/bin/sh}

assert_eq() {
	if [ ! "${1}" = "${2}" ]; then
		echo "Failed: ${1} != ${2}"
		exit 1
	fi
}

# Test argument handling
val="$(${SH} run-parts.sh -a arg_1 --arg=arg_2 --regex=print_args.sh ./tests)"
assert_eq "${val}" "arg_1
arg_2"

# Test regex reset, and scripts with spaces
val="$(${SH} run-parts.sh --regex="" --list ./tests | sort)"
assert_eq "${val}" "check_umask.sh
denied_by_regex%.sh
fail.sh
foo.sh
have space.sh
not_exec.sh
print_args.sh
with-dash.sh"

# Test the default regex, excluding non-scripts
val="$(${SH} run-parts.sh --test ./tests | sort)"
assert_eq "${val}" "check_umask.sh
fail.sh
foo.sh
print_args.sh
with-dash.sh"

# Test the prohibited suffix setter
val="$(${SH} run-parts.sh --test --ignore-suffixes=.sh ./tests | sort)"
assert_eq "${val}" "foo.rpmsave"

# Test --exit-on-error
${SH} run-parts.sh --exit-on-error -- tests 2>&1 > /dev/null
assert_eq "$?" "1"

# Test verbose mode
val="$(${SH} run-parts.sh -v --regex=foo.sh -- tests 2>&1)"
assert_eq "${val}" "foo.sh
foo"

# Test an empty directory
mkdir tests/empty || true
rm tests/empty/* 2>/dev/null || true
val="$(${SH} run-parts.sh --list --regex="" -- tests/empty)"
assert_eq "${val}" ""
rmdir tests/empty
