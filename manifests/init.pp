define ha_mediawiki($ensure) {

  # need to delete everything the revers order its created in
  if ($ensure == 'absent') {
    Gce_instance["${name}db"] -> Gce_network["${name}"]
    Gce_instance["${name}wiki"] -> Gce_network["${name}"]
    Gce_instance["${name}db"] -> Gce_disk["${name}disk"]
    Gce_firewall["${name}ssh"] -> Gce_network["${name}"]
    Gce_firewall["${name}http"] -> Gce_network["${name}"]
    Gce_firewall["${name}mysql"] -> Gce_network["${name}"]
    Gce_firewall["${name}icmp"] -> Gce_network["${name}"]
  }

  Gce_instance {
    zone                     => 'us-central1-a',
    machine                  => 'n1-standard-1',
    image                    => 'projects/google/images/ubuntu-12-04-v20120621',
    network                  => "${name}",
    block_for_startup_script => true,
    startup_script_timeout   => 300,
  }

  Gce_disk {
    zone    => 'us-central1-a',
  }

  Gce_firewall {
    network     => "${name}",
  }


  gce_network { "${name}":
    ensure      => $ensure,
    description => 'test network',
    gateway     => '10.0.1.1',
    range       => '10.0.1.0/24',
    # reserve =>
  }

  gce_disk { "${name}disk":
    ensure      => $ensure,
    description => 'small test disk',
    size_gb     => '2',
  }

  # TODO understand how to do this properly
  gce_firewall { "${name}ssh":
    ensure      => $ensure,
    description => 'allows incoming tcp traffic on 22',
    allowed     => 'tcp:22',
  }

  gce_firewall { "${name}http":
    ensure      => $ensure,
    description => 'allows incoming tcp traffic on 80',
    allowed     => 'tcp:80',
  }

  gce_firewall { "${name}mysql":
    ensure      => $ensure,
    description => 'allows incoming tcp traffic on 3306',
    allowed     => 'tcp:3306',
  }

  gce_firewall { "${name}icmp":
    ensure      => $ensure,
    description => 'allows incoming icmp traffic on 3306',
    allowed     => 'icmp',
  }

  gce_instance { "${name}db":
    ensure      => $ensure,
    description => 'DB instance',
    disk        => "${name}disk",
    modules     => ['puppetlabs-mysql'],
    module_repos => {
      'git://github.com/bodepd/puppet-mediawiki'      => 'mediawiki',
    },
    classes     => {
      'mysql::server' => {
        'config_hash' => { 'bind_address' => '0.0.0.0', 'root_password' => 'root_password' }
      },
      'mediawiki::db::access' => { 'host' => '10.0.1.%', 'password' => 'root_password' }
    },
  }

  gce_instance { "${name}wiki":
    ensure       => $ensure,
    description  => 'Mediawiki instnace',
    modules      => ['puppetlabs-apache', 'saz-memcached', 'puppetlabs-stdlib', 'puppetlabs-firewall', 'glarizza-haproxy'],
    module_repos => {
      'git://github.com/bodepd/puppet-mediawiki'        => 'mediawiki',
    },
    classes      => {
      'mediawiki' => {
        # we are passing in this value to tell the classification bash script to replace this with the real value
        'server_name'      => '$gce_external_ip',
        'admin_email'      => 'admin_email@domain.com',
        'install_db'       => false,
        'db_root_password' => 'root_password',
        'instances'        => {
          'dans_wiki' =>
            { 'db_password'        => 'db_pw',
            # this is magical!
              'db_server'          => "Gce_instance[${name}db][internal_ip_address]",
            }
        }
      }
    },
    require      => Gce_instance["${name}db"],
  }

  gce_instance { "${name}lb":
    ensure      => $ensure,
    description => 'LB instance',
    modules     => ['glarizza-haproxy'],
    module_repos => {
      'http://github.com/rcoleman/ha_mediawiki.git' => 'ha_mediawiki',
    },
    classes     => {
      'haproxy' => { 'enable' => true, },
      'ha_mediawiki::haproxy' => { 'lb_external_ip' => '$gce_external_ip', 'web_external_ip' => "Gce_instance[${name}wiki][external_ip_address]" }
    },
    require => Gce_instance["${name}wiki"],
  }

}

ha_mediawiki { 'forge':
  ensure => $::ensure,
}
