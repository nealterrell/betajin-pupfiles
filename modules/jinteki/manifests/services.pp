class jinteki::services {
  ensure_packages([
    'cronie',
    'python',
    'syslog-ng',
  ])

  cron {'rebuild':
    command => '/usr/local/bin/rebuild.sh',
    user => 'jinteki',
    hour => [0, 6, 12, 18],
    minute => 0,
    require => [File['/usr/local/bin/rebuild.sh']],
    notify => Service['cronie'],
  }

  # Clean up logs older than X days
  cron {'clean-logdir':
    command => "find ${jinteki::logdir} -mtime +30 -delete",
    user => 'jinteki',
    hour => 2,
    minute => 0,
    notify => Service['cronie'],
  }

  file {'/etc/systemd/system/jinteki-game.service':
    content => epp('jinteki/systemd/jinteki-game.service.epp'),
    owner => 'root',
    group => 'root',
    mode => '0644',
  }

  service {'jinteki-game':
    ensure => running,
    enable => true,
    hasrestart => true,
    hasstatus => true,
    require => File['/etc/systemd/system/jinteki-game.service'],
  }

  service {'cronie':
    ensure => running,
    enable => true,
    hasstatus => true,
    hasrestart => true,
    require => Package['cronie'],
  }

  file {'/etc/syslog-ng/syslog-ng.conf':
    content => epp('jinteki/syslog-ng.conf.epp'),
    owner => 'root',
    group => 'root',
    mode => '0644',
    require => Package['syslog-ng'],
    notify => Service['syslog-ng'],
  }

  service {'syslog-ng':
    ensure => running,
    enable => true,
    hasstatus => true,
    hasrestart => true,
    require => [Package['syslog-ng'], File['/etc/syslog-ng/syslog-ng.conf']],
  }
}
