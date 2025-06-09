#!/bin/sh
################################################################################
# Copyright (c) 2020 Plyint, LLC <contact@plyint.com>. All Rights Reserved.
# This file is licensed under the MIT License (MIT). 
# Please see LICENSE.txt for more information.
# 
# DESCRIPTION: 
# This script allows a user to encrypt a password (or any other secret) at 
# runtime and then use it, decrypted, within a script.  This prevents shoulder 
# surfing passwords and avoids storing the password in plain text, which could 
# inadvertently be sent to or discovered by an individual at a later date.
#
# This script generates an AES 256 bit symmetric key for each script (or user-
# defined bucket) that stores secrets.  This key will then be used to encrypt 
# all secrets for that script or bucket.  encpass.sh sets up a directory 
# (.encpass) under the user's home directory where keys and secrets will be 
# stored.
#
# For further details, see README.md or run "./encpass ?" from the command line.
#
################################################################################

ENCPASS_VERSION="v4.1.4"

encpass_checks() {
	[ -n "$ENCPASS_CHECKS" ] && return

	if [ -z "$ENCPASS_HOME_DIR" ]; then
		ENCPASS_HOME_DIR="$HOME/.encpass"
	fi
	[ ! -d "$ENCPASS_HOME_DIR" ] && mkdir -m 700 "$ENCPASS_HOME_DIR"

	if [ -f "$ENCPASS_HOME_DIR/.extension" ]; then
		# Extension enabled, load it...
		ENCPASS_EXTENSION="$(cat "$ENCPASS_HOME_DIR/.extension")"
		ENCPASS_EXT_FILE="encpass-$ENCPASS_EXTENSION.sh"
		if [ -f "./extensions/$ENCPASS_EXTENSION/$ENCPASS_EXT_FILE" ]; then
			# shellcheck source=/dev/null
		  . "./extensions/$ENCPASS_EXTENSION/$ENCPASS_EXT_FILE"
		elif [ ! -z "$(command -v encpass-"$ENCPASS_EXTENSION".sh)" ]; then 
			# shellcheck source=/dev/null
			. "$(command -v encpass-$ENCPASS_EXTENSION.sh)"
		else
			encpass_die "Error: Extension $ENCPASS_EXTENSION could not be found."
		fi

		# Extension specific checks, mandatory function for extensions
		encpass_"${ENCPASS_EXTENSION}"_checks
	else
		# Use default OpenSSL implementation
		if [ ! -x "$(command -v openssl)" ]; then
			echo "Error: OpenSSL is not installed or not accessible in the current path." \
				"Please install it and try again." >&2
			exit 1
		fi

		[ ! -d "$ENCPASS_HOME_DIR/keys" ] && mkdir -m 700 "$ENCPASS_HOME_DIR/keys"
		[ ! -d "$ENCPASS_HOME_DIR/secrets" ] && mkdir -m 700 "$ENCPASS_HOME_DIR/secrets"
		[ ! -d "$ENCPASS_HOME_DIR/exports" ] && mkdir -m 700 "$ENCPASS_HOME_DIR/exports"

	fi

	# Name of shell script or shell that called encpass.sh
	# Remove any preceding hyphens, so that ENCPASS_SNAME is not interpretted later
	# as a command line parameter to basename or any other command.
	ENCPASS_SNAME="$(echo "$0" | sed 's/^-*//g')"

	ENCPASS_CHECKS=1
}

# Checks if the enabled extension has implented the passed function and if so calls it
encpass_ext_func() {
  [ ! -z "$ENCPASS_EXTENSION" ] && ENCPASS_EXT_FUNC="$(command -v "encpass_${ENCPASS_EXTENSION}_$1")" || return
	[ ! -z "$ENCPASS_EXT_FUNC" ] && shift && $ENCPASS_EXT_FUNC "$@" 
}

# Initializations performed when the script is included by another script
encpass_include_init() {
	encpass_ext_func "include_init" "$@"
	[ ! -z "$ENCPASS_EXT_FUNC" ] && return

	if [ -n "$1" ] && [ -n "$2" ]; then
		ENCPASS_BUCKET=$1
		ENCPASS_SECRET_NAME=$2
	elif [ -n "$1" ]; then
		if [ -z "$ENCPASS_BUCKET" ]; then
		  ENCPASS_BUCKET=$(basename "$ENCPASS_SNAME")
		fi
		ENCPASS_SECRET_NAME=$1
	else
		ENCPASS_BUCKET=$(basename "$ENCPASS_SNAME")
		ENCPASS_SECRET_NAME="password"
	fi
}

encpass_generate_private_key() {
	ENCPASS_KEY_DIR="$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET"

	[ ! -d "$ENCPASS_KEY_DIR" ] && mkdir -m 700 "$ENCPASS_KEY_DIR"

	if [ ! -f "$ENCPASS_KEY_DIR/private.key" ]; then
		(umask 0377 && printf "%s" "$(openssl rand -hex 32)" >"$ENCPASS_KEY_DIR/private.key")
	fi
}

encpass_set_private_key_abs_name() {
	ENCPASS_PRIVATE_KEY_ABS_NAME="$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.key"
	[ ! -n "$1" ] && [ ! -f "$ENCPASS_PRIVATE_KEY_ABS_NAME" ] && encpass_generate_private_key
}

encpass_set_secret_abs_name() {
	ENCPASS_SECRET_ABS_NAME="$ENCPASS_HOME_DIR/secrets/$ENCPASS_BUCKET/$ENCPASS_SECRET_NAME.enc"
	[ ! -n "$1" ] && [ ! -f "$ENCPASS_SECRET_ABS_NAME" ] && set_secret
}

encpass_rmfifo() {
	trap - EXIT
	kill "$1" 2>/dev/null
	rm -f "$2"
}

encpass_mkfifo() {
	ENCPASS_FIFO="$ENCPASS_HOME_DIR/$1.$$"
	if [ ! -p "$ENCPASS_FIFO" ]; then
		mkfifo -m 600 "$ENCPASS_FIFO" || encpass_die "Error: unable to create named pipe"
	fi
	printf '%s\n' "$ENCPASS_FIFO"
}

get_secret() {
	encpass_checks
	encpass_ext_func "get_secret" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	[ "$(basename "$ENCPASS_SNAME")" != "encpass.sh" ] && encpass_include_init "$1" "$2"

	encpass_set_private_key_abs_name
	encpass_set_secret_abs_name
	encpass_decrypt_secret "$@"
}

set_secret() {
	encpass_checks

	encpass_ext_func "set_secret" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	if [ "$1" != "reuse" ] || { [ -z "$ENCPASS_SECRET_INPUT" ] && [ -z "$ENCPASS_CSECRET_INPUT" ]; }; then
		echo "Enter $ENCPASS_SECRET_NAME:" >&2
		stty -echo
		read -r ENCPASS_SECRET_INPUT
		stty echo
		echo "Confirm $ENCPASS_SECRET_NAME:" >&2
		stty -echo
		read -r ENCPASS_CSECRET_INPUT
		stty echo

		# Use named pipe to securely pass secret to openssl
		ENCPASS_FIFO="$(encpass_mkfifo set_secret_fifo)"
	fi

	if [ "$ENCPASS_SECRET_INPUT" = "$ENCPASS_CSECRET_INPUT" ]; then
		encpass_set_private_key_abs_name
		ENCPASS_SECRET_DIR="$ENCPASS_HOME_DIR/secrets/$ENCPASS_BUCKET"

		[ ! -d "$ENCPASS_SECRET_DIR" ] && mkdir -m 700 "$ENCPASS_SECRET_DIR"

		# Generate IV and create secret file
		printf "%s" "$(openssl rand -hex 16)" > "$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc"
		ENCPASS_OPENSSL_IV="$(cat "$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc")"

		echo "$ENCPASS_SECRET_INPUT" > "$ENCPASS_FIFO" &
		# Allow expansion now so PID is set
		# shellcheck disable=SC2064
		trap "encpass_rmfifo $! $ENCPASS_FIFO" EXIT HUP TERM INT TSTP

		# Append encrypted secret to IV in the secret file
		openssl enc -aes-256-cbc -e -a -iv "$ENCPASS_OPENSSL_IV" \
			-K "$(cat "$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.key")" \
			-in "$ENCPASS_FIFO" 1>> "$ENCPASS_SECRET_DIR/$ENCPASS_SECRET_NAME.enc"
	else
		encpass_die "Error: secrets do not match.  Please try again."
	fi
}

encpass_decrypt_secret() {
	encpass_ext_func "decrypt_secret" "$@"; [ ! -z "$ENCPASS_EXT_FUNC" ] && return

	if [ -f "$ENCPASS_PRIVATE_KEY_ABS_NAME" ]; then
		ENCPASS_DECRYPT_RESULT="$(dd if="$ENCPASS_SECRET_ABS_NAME" ibs=1 skip=32 2> /dev/null | openssl enc -aes-256-cbc \
			-d -a -iv "$(head -c 32 "$ENCPASS_SECRET_ABS_NAME")" -K "$(cat "$ENCPASS_PRIVATE_KEY_ABS_NAME")" 2> /dev/null)"
		if [ ! -z "$ENCPASS_DECRYPT_RESULT" ]; then
			echo "$ENCPASS_DECRYPT_RESULT"
		else
			# If a failed unlock command occurred and the user tries to show the secret
			# Present either a locked or failed decrypt error.
			if [ -f "$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.lock" ]; then 
		    echo "**Locked**"
			else
				# The locked file wasn't present as expected.  Let's display a failure
		    echo "Error: Failed to decrypt"
			fi
		fi
	elif [ -f "$ENCPASS_HOME_DIR/keys/$ENCPASS_BUCKET/private.lock" ]; then
		echo "**Locked**"
	else
		echo "Error: Unable to decrypt. The key file \"$ENCPASS_PRIVATE_KEY_ABS_NAME\" is not present."
	fi
}

encpass_die() {
  echo "$@" >&2
  exit 1
}
#LITE
