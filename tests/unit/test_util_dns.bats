#!/usr/bin/env bats
###############################################################################
# test_util_dns.bats - Unit tests for lib/utils/util_dns.sh (+ net::cidr_expand)
# Network-independent cases only (parsing + CIDR math).
###############################################################################

setup() {
    load "${BATS_TEST_DIRNAME}/../helpers/load_lib.bash"
}

#===============================================================================
# dns::root_domain
#===============================================================================

@test "dns::root_domain reduces a subdomain to the last two labels" {
    run dns::root_domain sub.host.example.com
    [ "$status" -eq 0 ]
    [ "$output" = "example.com" ]
}

@test "dns::root_domain is a no-op on an apex domain" {
    run dns::root_domain example.com
    [ "$status" -eq 0 ]
    [ "$output" = "example.com" ]
}

@test "dns::root_domain fails with no argument" {
    run dns::root_domain
    [ "$status" -ne 0 ]
}

#===============================================================================
# dns::spf_includes
#===============================================================================

@test "dns::spf_includes extracts include hosts from an argument" {
    run dns::spf_includes "v=spf1 include:a.com include:b.net -all"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "a.com" ]
    [ "${lines[1]}" = "b.net" ]
}

@test "dns::spf_includes reads from stdin when no argument" {
    run bash -c 'source lib/util.sh >/dev/null 2>&1; printf "v=spf1 include:x.io -all" | dns::spf_includes'
    [ "$status" -eq 0 ]
    [ "$output" = "x.io" ]
}

#===============================================================================
# net::cidr_expand
#===============================================================================

@test "net::cidr_expand expands a /30 to four addresses" {
    run net::cidr_expand 10.0.0.0/30
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [[ "$output" == *"10.0.0.1"* ]]
    [[ "$output" == *"10.0.0.2"* ]]
}

@test "net::cidr_expand echoes a bare IP as a single host" {
    run net::cidr_expand 192.168.1.5
    [ "$status" -eq 0 ]
    [ "$output" = "192.168.1.5" ]
}

@test "net::cidr_expand fails with no argument" {
    run net::cidr_expand
    [ "$status" -ne 0 ]
}
