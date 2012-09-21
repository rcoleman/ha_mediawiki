class ha_mediawiki::haproxy(
  $lb_external_ip,
  $web_external_ip,
) {

  haproxy::config { 'puppet00':
    order                  => '20',
    virtual_ip             => $lb_external_ip,
    virtual_ip_port        => '80',
    haproxy_config_options => { 'option' => ['tcplog', 'ssl-hello-chk'], 'balance' => 'roundrobin' },
  }

  haproxy::balancermember { $web_external_ip:
    order                  => '21',
    listening_service      => 'mediawiki00',
    server_name            => $web_external_ip,
    balancer_ip            => $web_external_ip,
    balancer_port          => '80',
    balancermember_options => 'check'
  }


}
