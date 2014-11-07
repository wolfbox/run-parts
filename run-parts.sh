#!/bin/sh
set -e

COMMAND="${0}"
VERSION="0.0"

DEFAULT_REGEX="[a-z0-9_\-]"

# One of "run", "list", and "report"
mode="run"

verbose="off"
reverse="off"
exit_on_error="off"
new_session="off"
regex=""
umask="022"
dir=""

# Starts with a comma to ease searching
ignore_suffixes=",.rpmsave,.rpmorig,.rpmnew,.swp,.cfsaved,"

# One of "run", "directory", "umask", or "arg"
parsemode="run"

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
	local name="${1}"
	local input="${2}"
	echo $(echo "${input}" | sed "s:${name}=::" -)
}

dispatch_parse() {
	if [ ${arg} = "--test" ]; then
		mode="test"
	elif [ ${arg} = "--list" ]; then
		mode="list"
	elif [ ${arg} = "--report" ]; then
		verbose="report"
	elif [ ${arg} = "-v" ] || [ ${arg} = "--verbose" ]; then
		verbose="verbose"
	elif [ ${arg} = "--reverse" ]; then
		reverse="on"
	elif [ ${arg} = "--exit-on-error" ]; then
		exit_on_error="on"
	elif [ ${arg} = "--new-session" ]; then
		_new_session="on"
	elif [ ${arg} = "-h" ] || [ ${arg} = "--help" ]; then
		show_help
		exit 0
	elif [ ${arg} = "-V" ] || [ ${arg} = "--version" ]; then
		show_version
		exit 0
	elif [ ${arg} = "--" ]; then
		parsemode="directory"
	fi
	
	regex=$(parse_long_argument "--regex" "${arg}")
}

gotarg="no"
for arg in $@; do
	gotarg="yes"

	if [ ${parsemode} = "directory" ]; then
		dir="${arg}"
	else
		dispatch_parse "${arg}"
	fi

	shift 1
done

if [ ${gotarg} = "no" ]; then
	show_help
	exit 0
fi

if [ "${dir}" = "" ]; then
	echo "No directory provided"
	show_help
	exit 1
fi

if [ ! -d "${dir}" ] || [ ! -x "${dir}" ]; then
	echo "Could not list contents of ${dir}"
	exit 1
fi

for file in ${dir}/*; do
	if [ ! -x "${file}" ] || [ -d "${file}" ]; then
		continue
	fi

	# Check our suffix ignore list
	filename=$(basename "${file}")
	extension="${filename##*.}"
	if echo "${ignore_suffixes}" | grep -qF ",.${extension},"; then
		continue
	fi
	
	if [ "${mode}" = "run" ]; then
		may_fail "${file}" result

		if [ ${result} -ne 0 ]; then
			if [ ${exit_on_error} = "on" ]; then
				echo "Script ${file} failed"
				exit 1
			else
				continue
			fi
		fi
	fi
done
