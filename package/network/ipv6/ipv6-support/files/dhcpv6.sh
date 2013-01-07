#!/bin/sh
# Copyright (c) 2012 OpenWrt.org
. /lib/ipv6/support.sh
. /lib/netifd/netifd-proto.sh

local device="$1"
local state="$2"
local network=""

resolve_network network "$device"

# Unknown network
[ -z "$network" ] && exit 0

if [ "$state" == "started" ]; then
	# Start border
	set_forward_border "$network" "$device" enable

	# Configure device
	conf_set "$device" accept_ra 2
	conf_set "$device" forwarding 2

	# Trigger RS
	conf_set "$device" disable_ipv6 1
	conf_set "$device" disable_ipv6 0

	exit 0
elif [ "$state" == "stopped" ]; then
	# Deconfigure device
	conf_set "$device" accept_ra 1
	conf_set "$device" forwarding 1

	# Disable border
	set_forward_border "$network" "$device" disable

	exit 0
fi

# Announce prefixes
for prefix in $PREFIXES; do
	announce_prefix "$prefix" "$network" "$device"
done

for prefix in $PREFIXES_LOST; do
	announce_prefix "$prefix" "$network" "$device" delprefix
done


# Enable relaying if requested and we didn't get a prefix, disable otherwise
local fallback="stop"
[ -z "$PREFIXES" -a "$state" != "unbound" ] && fallback="start"
setup_prefix_fallback "$fallback" "$network" "$device"


# Operations in case of success
[ "$state" == "timeout" -o "$state" == "unbound" ] && exit 0

# Handshake completed, disable forwarding border
set_forward_border "$network" "$device" disable

local peerdns
config_get_bool peerdns "$network" peerdns 1
[ "$peerdns" -eq "1" ] && {
	proto_init_update "*" 1
	proto_set_keep 1
	for server in $RDNSS; do
		proto_add_dns_server "$server"
	done
	for domain in $DOMAINS; do
		proto_add_dns_search "$domain"
	done
	proto_send_update "$network"
}

