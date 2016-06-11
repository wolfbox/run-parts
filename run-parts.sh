#!/bin/sh
set -eu

COMMAND="${0}"
VERSION="0.2pre"

DEFAULT_REGEX='^[a-zA-Z0-9_\.-]+$'
LANANA_REGEX='^[a-z0-9]+$'

# One of "run", "list", and "report"
mode="run"

verbose="off"
exit_on_error="off"
new_session="off"
regex="${DEFAULT_REGEX}"
umask="022"
dir=""
args=""

# Starts with a comma to ease searching
ignore_suffixes=",.rpmsave,.rpmorig,.rpmnew,.swp,.cfsaved,"

# One of "run", "directory", "umask", "regex", "arg", "suffixes", or "done"
parsemode="run"

# Avoid killing a child script if run-parts is killed
run_isolation() {
	local command="${1}"
	shift 1

	( "${command}" "$@" ) &
	local child_pid=$!
	wait "${child_pid}"
	return $?
}

# If a command fails, avoid letting run-parts die. Store the return status
# of command in outvar
may_fail() {
	local outvar="${1}"
	shift 1

	set +e
	"$@"
	eval "${outvar}"=$?
	set -e
}

add_argument() {
	args="${args} ${1}"
}

set_ignore_suffixes() {
	ignore_suffixes=",${1},"
}

show_version() {
	echo "run-parts ${VERSION}"
}

show_help() {
	echo "Usage: ${COMMAND} [OPTIONS] [--] DIRECTORY"
	echo "    --test"
	echo "    --list"
	echo "    -v, --verbose"
	echo "    --exit-on-error"
	echo "    --new-session"
	echo "    --regex=RE"
	echo "    -u, --umask=UMASK"
	echo "    -a, --arg=ARGUMENT"
	echo "    --ignore-suffixes=SUFFIX1[,SUFFIX2,...]"
	echo "    -h, --help"
	echo "    -V, --version"
}

parse_long_argument() {
	local input="${1}"
	echo "${input}" | sed -Ee 's:--[a-z_\-]+=::'
}

dispatch_parse() {
	case ${arg} in
		--test )
			mode="test"
			;;
		--list )
			mode="list"
			;;
		-v | --verbose )
			verbose="verbose"
			;;
		--exit-on-error )
			exit_on_error="on"
			;;
		--new-session )
			new_session="on"
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
		-a | --arg )
			parsemode="arg"
			;;
		--arg=* )
			add_argument "$(parse_long_argument "${arg}")"
			;;
		--ignore-suffixes )
			parsemode="suffixes"
			;;
		--ignore-suffixes=* )
			set_ignore_suffixes "$(parse_long_argument "${arg}")"
			;;
		-- )
			parsemode="directory"
			;;
		-* )
			echo "Unknown argument ${arg}"
			show_help
			exit 1
			;;
		* )
			dir="${arg}"
			parsemode="done"
			;;
	esac
}

gotarg="no"
for arg in "$@"; do
	gotarg="yes"

	case "${parsemode}" in
		"directory" )
			dir="${arg}"
			parsemode="done"
			;;
		"arg" )
			add_argument "${arg}"
			parsemode="run"
			;;
		"umask" )
			umask="${arg}"
			parsemode="run"
			;;
		"suffixes" )
			ignore_suffixes="$(set_ignore_suffixes "${arg}")"
			parsemode="run"
			;;
		"regex" )
			regex="${arg}"
			parsemode="run"
			;;
		"run" )
			dispatch_parse "${arg}"
			;;
		"done" )
			echo "No arguments allowed after directory name ${dir}"
			show_help
			exit 1
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
	# If the directory contains no contents, the glob will fail and our file
	# will be unexpanded. Detect this.
	if [ ! -e "${file}" ]; then
		continue
	fi

	if [ ! "${mode}" = "list" ]; then
		if [ ! -x "${file}" ] || [ -d "${file}" ]; then
			continue
		fi
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
		if [ "${verbose}" = "verbose" ]; then
			echo "${filename}" 1>&2
		fi

		if [ "${new_session}" = "on" ]; then
			may_fail result run_isolation "${file}" ${args}
		else
			may_fail result "${file}" ${args}
		fi

		if [ "${result}" -ne 0 ]; then
			if [ "${exit_on_error}" = "on" ]; then
				echo "Script ${file} failed"
				exit 1
			else
				continue
			fi
		fi
	elif [ "${mode}" = "test" ] || [ "${mode}" = "list" ]; then
		echo "${filename}"
	fi
done
