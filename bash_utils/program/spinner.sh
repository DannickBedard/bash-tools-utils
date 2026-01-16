#!/usr/bin/env bash
#
# Run a command with an animated spinner.
#
# Spinners taken from:
# https://github.com/sindresorhus/cli-spinners

SPINNER_PID=
DEBUG=false
THEME=default
CHARS=

spinner_usage() {
	local prog=${0##*/}
	cat <<-EOF
	Usage: $prog [options] <cmd>

	Run a command with an animated spinner.

	Options
	  -d          enable debug output
	  -t <theme>  theme to use, default is $THEME
	  -h          print this message and exit
	EOF
}

spinner_spin() {
	local c
	while true; do
		for c in "${CHARS[@]}"; do
			printf ' %s \r' "$c"
			sleep .2
		done
	done
}

spinner_debug() {
	if $DEBUG; then
		echo "[$$] $*" >&2
	fi
}

spinner_cleanup() {
  echo "💀 Cleaning up..."
	if [[ -n $SPINNER_PID ]]; then
		spinner_debug "killing spinner ($SPINNER_PID)"
		kill "$SPINNER_PID"
	fi

	spinner_debug 'finished spinner'
}

spinner_load_theme() {
	local theme=$1

	case "$theme" in
		default) CHARS=('\' '|' '/' '-');;
		dots) CHARS=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏);;
		pong) CHARS=(
			  "▐⠂       ▌"
			  "▐⠈       ▌"
			  "▐ ⠂      ▌"
			  "▐ ⠠      ▌"
			  "▐  ⡀     ▌"
			  "▐  ⠠     ▌"
			  "▐   ⠂    ▌"
			  "▐   ⠈    ▌"
			  "▐    ⠂   ▌"
			  "▐    ⠠   ▌"
			  "▐     ⡀  ▌"
			  "▐     ⠠  ▌"
			  "▐      ⠂ ▌"
			  "▐      ⠈ ▌"
			  "▐       ⠂▌"
			  "▐       ⠠▌"
			  "▐       ⡀▌"
			  "▐      ⠠ ▌"
			  "▐      ⠂ ▌"
			  "▐     ⠈  ▌"
			  "▐     ⠂  ▌"
			  "▐    ⠠   ▌"
			  "▐    ⡀   ▌"
			  "▐   ⠠    ▌"
			  "▐   ⠂    ▌"
			  "▐  ⠈     ▌"
			  "▐  ⠂     ▌"
			  "▐ ⠠      ▌"
			  "▐ ⡀      ▌"
			  "▐⠠       ▌"
			  );;
		*)
			echo "invalid theme: $THEME" >&2;
			spinner_usage >&2;
			exit 1
			;;
	esac
}

spinner_main() {
	local opt OPTIND OPTARG
	while getopts 'dht:' opt; do
		case "$opt" in
			d) DEBUG=true;;
			h) spinner_usage; return 0;;
			t) THEME=$OPTARG;;
			*) spinner_usage >&2; return 1;;
		esac
	done
	shift "$((OPTIND - 1))"

	spinner_load_theme "$THEME"

	if (($# == 0)); then
		spinner_usage >&2
		return 1
	fi

	trap spinner_cleanup EXIT

	spinner_debug 'starting spinner'
	spinner_spin &
	SPINNER_PID=$!

	spinner_debug "SPINNER_PID=$SPINNER_PID"

	"$@"

  # make sur to cleanup the spinner
  # spinner_cleanup
}


spinner_main "$@"
