#!/usr/bin/env bash
# ABOUT kv-bash: 
#    key/value dabatase
#    database store in HOME directory
#    each user has 1 database
#    imports 5 bash functions via ```$ source kv-bash```
#
# Author: damphat
# Version: 0.1
# Requirements: unix-like environement, no dependencies
#
# USAGE:
#    source ./kv-bash        # import kv-bash functions
#    kvset <key> <value>     # assign value to key
#    kvget <key>             # get value of key
#    kvdel <key>             # kvdelete by key
#    kvlist                  # list all current key/value pairs
#    kvclear                 # clear database
#
# EXAMPLES: 
#    $ source ./kv-bash
#    $ kvset user mr.bob
#    $ kvset pass abc@123
#    $ kvlist
#      user mr.bob
#      pass abc@123
#    $ kvget user
#      mr.bob
#    $ kvget pass
#      abc@123
#    $ kvdel pass
#    $ kvget pass
#
#    $ kvclear

########################
# CONSTANTS
########################

default_kv_user_dir="$HOME/.kv-bash"

########################
# LOCAL FUNCTIONS
########################

# print to stderr, red color
kv_echo_err() {
	echo -e "\e[01;31m$@\e[0m" >&2
}

# Usage: kv_echo_err_box <err-msg> <function-name>
kv_echo_err_box() {
	kv_user_dir=${KV_USER_DIR:-$default_kv_user_dir}
	kv_echo_err "  +-------------------------------+"
	kv_echo_err "  | ERROR: $1"
	kv_echo_err "  | function: $2"
	kv_echo_err "  | dir: $kv_user_dir"
	kv_echo_err "  +-------------------------------+"
}

# Usage: kv_validate_key <key>
kv_validate_key() {
	[[ "$1" =~ ^[0-9a-zA-Z._:-]+$  ]]
}

########################
# ENSURE THIS-FILE IS CALL BY 'source ./kv-bash'
########################

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || {
	kv_echo_err "  +------------------------------------------------+"
	kv_echo_err "  | FATAL ERROR: wrong usage :(                    |"
	kv_echo_err "  | You should use this via source                 |"
	kv_echo_err "  |     $ source ./kv-bash                         |"	
	kv_echo_err "  |                                                |"
	kv_echo_err "  | Examples:                                      |"
	kv_echo_err "  |     $ source ./kv-bash                         |"
	kv_echo_err "  |     $ kvset user mr.bob                        |"
	kv_echo_err "  |     $ kvset pass abc@123                       |"
	kv_echo_err "  |     $ kvlist                                   |"
	kv_echo_err "  |       user mr.bob                              |"
	kv_echo_err "  |       pass abc@123                             |"
	kv_echo_err "  |     $ kvget user                               |"
	kv_echo_err "  |       mr.bob                                   |"
	kv_echo_err "  |     $ kvget pass                               |"
	kv_echo_err "  |       abc@123                                  |"
	kv_echo_err "  |     $ kvdel pass                               |"
	kv_echo_err "  |     $ kvget pass                               |"
	kv_echo_err "  |                                                |"
	kv_echo_err "  |     $ kvclear                                  |"
	kv_echo_err "  +------------------------------------------------+"
	exit 1
}

########################
# PUBLIC FUNCTIONS
########################

# Usage: kvget <key>
kvget() {
	key="$1"
	kv_validate_key "$key" || {
		kv_echo_err_box 'invalid param "key"' 'kvget()'
		return 1
	}
	kv_user_dir=${KV_USER_DIR:-$default_kv_user_dir}
	VALUE="$([ -f "$kv_user_dir/$key" ] && cat "$kv_user_dir/$key")"
	echo "$VALUE"
	
	[ "$VALUE" != "" ]
}

# Usage: kvset <key> [value] 
kvset() {
	key="$1"
	value="$2"
	kv_validate_key "$key" || {
		kv_echo_err_box 'invalid param "key"' 'kvset()'
		return 1
	}
	kv_user_dir=${KV_USER_DIR:-$default_kv_user_dir}
	test -d "$kv_user_dir" || mkdir "$kv_user_dir"
	echo "$value" > "$kv_user_dir/$key"
}

# Usage: kvdel <key>
kvdel() {
	key="$1"
	kv_validate_key "$key" || {
		kv_echo_err_box 'invalid param "key"' 'kvdel()'
		return 1
	}
	kv_user_dir=${KV_USER_DIR:-$default_kv_user_dir}
	test -f "$kv_user_dir/$key" && rm -f "$kv_user_dir/$key"
}

# list all key/value pairs to stdout
# Usage: kvlist
kvlist() {
	kv_user_dir=${KV_USER_DIR:-$default_kv_user_dir}
	for i in "$kv_user_dir/"*; do
		if [ -f "$i" ]; then
			key="$(basename "$i")"
			echo "$key" "$(kvget "$key")"
		fi
	done 
}

# clear all key/value pairs in database
# Usage: kvclear
kvclear() {
  kv_user_dir=${KV_USER_DIR:-$default_kv_user_dir}
	rm -rf "$kv_user_dir"
}