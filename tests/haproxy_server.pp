      class { 'haproxy':
        enable                   => true,
        haproxy_global_options   => ...
        ...
      }

      haproxy::config { 'puppet00':
        order                  => '20',
        virtual_ip             => $::ipaddress,
        virtual_ip_port        => '18140',
        haproxy_config_options => { 'option' => ['tcplog', 'ssl-hello-chk'], 'balance' => 'roundrobin' },
      }
