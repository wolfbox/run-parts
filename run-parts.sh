#!/bin/sh
set -e

COMMAND="${0}"
VERSION="0.0"

DEFAULT_REGEX="[a-z0-9_\-]"

# One of "run", "list", and "report"
_mode="run"

_verbose="off"
_reverse="off"
_exit_on_error="off"
_new_session="off"
_regex=""
_umask="022"
_dir=""

# Starts with a comma to ease searching
_ignore_suffixes=",.rpmsave,.rpmorig,.rpmnew,.swp,.cfsaved,"

# One of "run", "directory", "umask", or "arg"
_parse_mode="run"

may_fail() {
	set +e
	"${1}"
	eval "${2}"=$?
	set -e
}

show_version() {
	echo "run-parts ${VERSION}"
}

show_help() {
	echo "Usage: ${COMMAND} [OPTIONS] [--] DIRECTORY"
	echo "    --test"
	echo "    --list"
	echo "    -v, --verbose"
	echo "    --report"
	echo "    --reverse"
	echo "    --exit-on-error"
	echo "    --new-session"
	echo "    --regex=RE"
	echo "    -u, --umask=UMASK"
	echo "    --ignore-suffixes=SUFFIX1[,SUFFIX2,...]"
	echo "    -h, --help"
	echo "    -V, --version"
}

parse_long_argument() {
	local _name="${1}"
	local _input="${2}"
	echo $(echo "${_input}" | sed "s:${_name}=::" -)
}

dispatch_parse() {
	if [ ${arg} = "--test" ]; then
		_mode="test"
	elif [ ${arg} = "--list" ]; then
		_mode="list"
	elif [ ${arg} = "--report" ]; then
		_verbose="report"
	elif [ ${arg} = "-v" ] || [ ${arg} = "--verbose" ]; then
		_verbose="verbose"
	elif [ ${arg} = "--reverse" ]; then
		_reverse="on"
	elif [ ${arg} = "--exit-on-error" ]; then
		_exit_on_error="on"
	elif [ ${arg} = "--new-session" ]; then
		_new_session="on"
	elif [ ${arg} = "-h" ] || [ ${arg} = "--help" ]; then
		show_help
		exit 0
	elif [ ${arg} = "-V" ] || [ ${arg} = "--version" ]; then
		show_version
		exit 0
	elif [ ${arg} = "--" ]; then
		_parse_mode="directory"
	fi
	
	_regex=$(parse_long_argument "--regex" "${arg}")
}

_gotarg="no"
for arg in $@; do
	_gotarg="yes"

	if [ ${_parse_mode} = "directory" ]; then
		_dir="${arg}"
	else
		dispatch_parse "${arg}"
	fi

	shift 1
done

if [ ${_gotarg} = "no" ]; then
	show_help
	exit 0
fi

if [ "${_dir}" = "" ]; then
	echo "No directory provided"
	show_help
	exit 1
fi

if [ ! -d "${_dir}" ] || [ ! -x "${_dir}" ]; then
	echo "Could not list contents of ${_dir}"
	exit 1
fi

for file in ${_dir}/*; do
	if [ ! -x "${file}" ] || [ -d "${file}" ]; then
		continue
	fi

	# Check our suffix ignore list
	_filename=$(basename "${file}")
	_extension="${_filename##*.}"
	if echo "${_ignore_suffixes}" | grep -qF ",.${_extension},"; then
		continue
	fi
	
	if [ "${_mode}" = "run" ]; then
		may_fail "${file}" result

		if [ ${result} -ne 0 ]; then
			if [ ${_exit_on_error} = "on" ]; then
				echo "Script ${file} failed"
				exit 1
			else
				continue
			fi
		fi
	fi
done
