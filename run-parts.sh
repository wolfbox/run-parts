#!/bin/sh
set -e

COMMAND="${0}"
VERSION="0.0"

DEFAULT_REGEX='^[a-zA-Z0-9_\-\.]+$'
LANANA_REGEX='^[a-z0-9]+$'

# One of "run", "list", and "report"
mode="run"

verbose="off"
reverse="off"
exit_on_error="off"
new_session="off"
regex="${DEFAULT_REGEX}"
umask="022"
dir=""

# Starts with a comma to ease searching
ignore_suffixes=",.rpmsave,.rpmorig,.rpmnew,.swp,.cfsaved,"

# One of "run", "directory", "umask", "regex", or "arg"
parsemode="run"

may_fail() {
	local command="${1}"
	local outvar="${2}"

	set +e
	"${command}"
	eval "${outvar}"=$?
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
	local input="${1}"
	echo $(echo "${input}" | sed "s:--[a-z_\-]\+=::" -)
}

dispatch_parse() {
	case ${arg} in
		--test )
			mode="test"
			;;
		--list )
			mode="list"
			;;
		--report )
			verbose="report"
			;;
		-v | --verbose )
			verbose="verbose"
			;;
		--reverse )
			reverse="on"
			;;
		--exit-on-error )
			exit_on_error="on"
			;;
		-h | --help )
			show_help
			exit 0
			;;
		-V | --version )
			show_version
			exit 0
			;;
		--regex )
			parsemode="regex"
			;;
		--regex=* )
			regex=$(parse_long_argument "${arg}")
			;;
		-u | --umask )
			parsemode="umask"
			;;
		--umask=* )
			umask=$(parse_long_argument "${arg}")
			;;
		-- )
			parsemode="directory"
			;;
		* )
			echo "Unknown argument ${arg}"
			show_help
			exit 1
			;;
	esac
}

gotarg="no"
for arg in $@; do
	gotarg="yes"

	case "${parsemode}" in
		"directory" )
			dir="${arg}"
			;;
		"umask" )
			umask="${arg}"
			parsemode="run"
			;;
		"regex" )
			regex="${arg}"
			parsemode="run"
			;;
		"run" )
			dispatch_parse "${arg}"
			;;
		* )
			echo "Unknown state ${parsemode}"
			exit 1
			;;
	esac

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

umask "${umask}"

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

	# Match our filter regex, if we have one
	if [ ! -z "${regex}" ]; then
		if echo "${filename}" | grep -qvE "${regex}"; then
			continue
		fi
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
