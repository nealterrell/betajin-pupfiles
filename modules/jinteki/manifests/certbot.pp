class jinteki::certbot {
  ensure_packages([
    'certbot',
    'certbot-nginx',
  ])

  $jinteki_domains.each |String $domain| {
    exec {"certbot-obtain-$domain":
      command => "/usr/bin/certbot run -n --agree-tos --nginx --redirect --email ${admin_email} -d ${domain}",
      require => [Package['certbot'], Package['certbot-nginx'], Service['jinteki-game'], Service['nginx']],

      #creates => "/etc/letsencrypt/live/${domain}/fullchain.pem",
    }
  }

  cron {'certbot_renew':
    ensure => 'present',
    command => '/usr/bin/certbot renew --quiet --agree-tos',
    user => 'root',
    hour => 10,
    minute => 42,
  }
}
