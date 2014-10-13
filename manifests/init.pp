include stdlib

class cassandra ($cluster = 'dev', 
	$seeds, 
	$broadcast_address, 
	$rpc_address="0.0.0.0", 
	$listen_address = "", 
	$cassyVersion, 
	$downloadUrl, 
	$downloadDir="/cassandra", 
	$dc, 
	$rack,
	$backup_root="",
	$backup_hour=[3],
	$user='',
	$password='') {
	
	group { "cassandra":  }

	user { "cassandra":
		home => "/home/cassandra",
		shell => "/bin/bash",
		require => Group["cassandra"]
	}

	file { ["/var/lib/cassandra",
		"/var/log/cassandra",
		"/var/lib/cassandra/data",
		"/var/lib/cassandra/commitlog",
		"/var/lib/cassandra/saved_caches"
		]:
		ensure => directory,
    	owner => cassandra,
    	group => cassandra,
    	mode => 755,
    	require => User["cassandra"],
	}

	file { "$downloadDir/":
		ensure => directory,
		require => [ 
			File["/var/lib/cassandra"],
			File["/var/log/cassandra"],
			File["/var/lib/cassandra/data"],
			File["/var/lib/cassandra/commitlog"],
			File["/var/lib/cassandra/saved_caches"]
			],
	}

	exec {'download-cassy' :
		command => "/usr/bin/wget -O $downloadDir/apache-cassandra-$cassyVersion-bin.tar.gz $downloadUrl",
		creates => "$downloadDir/apache-cassandra-$cassyVersion-bin.tar.gz",
		require => File["$downloadDir/"],
		notify 	=> Exec['extract-cassy'],
	}

	exec { 'extract-cassy' :
		command => "/bin/chmod a+x $downloadDir/apache-cassandra-$cassyVersion-bin.tar.gz && /bin/tar -xzf $downloadDir/apache-cassandra-$cassyVersion-bin.tar.gz -C /usr/local/",
		creates => "/usr/local/apache-cassandra-$cassyVersion",
	}

	file { "/usr/local/apache-cassandra-$cassyVersion/bin":
		mode => 755,
    	path => "/usr/local/apache-cassandra-$cassyVersion/bin",
    	recurse => true,
    	require => Exec["extract-cassy"]
	}

	file { "/usr/local/apache-cassandra":
    	ensure => link,
    	target => "/usr/local/apache-cassandra-$cassyVersion",
    	require => File[ "/usr/local/apache-cassandra-$cassyVersion/bin" ]
  	}

	#bin/apache-cassandra-$cassyVersion/conf/cassandra.yaml 
	file_line { 'seeds' :
		require => File['/usr/local/apache-cassandra'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "          - seeds: '$seeds'", #figure out a better indent?!?
		match => '- seeds:',
	}

	file_line { 'cluster-name' :
		require => File_line['seeds'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "cluster_name: $cluster",
		match => 'cluster_name:',
	}

	file_line { 'listen_address':
		require => File_line['cluster-name'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "listen_address: $listen_address",
		match => '^listen_address:',
	}

	file_line { 'rpc_address':
		require => File_line['listen_address'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "rpc_address: $rpc_address",
		match => '^rpc_address:',
	}

	file_line { 'broadcast_rpc_address':
		require => File_line['rpc_address'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "broadcast_rpc_address: $broadcast_address",
		match => '^broadcast_rpc_address:',
	}

	file_line { 'authenticator':
		require => File_line['broadcast_rpc_address'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "authenticator: PasswordAuthenticator",
		match => '^authenticator:',
	}

	file_line { 'authorizer':
		require => File_line['authenticator'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "authorizer: CassandraAuthorizer",
		match => '^authorizer:',
	}

	file_line { 'commitlog_directory':
		require => File_line['authorizer'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "commitlog_directory: /var/lib/cassandra/commitlog",
		match => '^commitlog_directory:',
	}

	file_line { 'datafile_directory':
		require => File_line['commitlog_directory'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "data_file_directories: ['/var/lib/cassandra/data']",
		match => '^data_file_directories:',
	}

	file_line { 'saved_caches_directory':
		require => File_line['datafile_directory'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "saved_caches_directory: /var/lib/cassandra/saved_caches",
		match => '^saved_caches_directory:',
	}

	file_line { 'log_file':
		require => File_line['saved_caches_directory'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/logback.xml",
		line => "    <file>/var/log/cassandra/system.log</file>",
		match => "<file>",	
	}

	file_line { 'log_file_pattern':
		require => File_line['log_file'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/logback.xml",
		line => '      <fileNamePattern>/var/log/cassandra/system.log.%i.zip</fileNamePattern>',
		match => '<fileNamePattern>',	
	}

	file_line { 'snitch':
		require => File_line['log_file_pattern'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra.yaml",
		line => "endpoint_snitch: GossipingPropertyFileSnitch ",
		match => 'endpoint_snitch:',
	}

	file_line { 'dc':
		require => File_line['snitch'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra-rackdc.properties",
		line => "dc=$dc",
		match => '^dc=',
	}	

	file_line { 'rack':
		require => File_line['dc'],
		path => "/usr/local/apache-cassandra-$cassyVersion/conf/cassandra-rackdc.properties",
		line => "rack=$rack",
		match => '^rack=',
	}	

	file { '/etc/init.d/cassandra' :
		require => File_line['rack'],
		ensure => present,
		source => "puppet:///modules/cassandra/cassandra.initd",
		mode => 744,
	}

	file { "/etc/profile.d/cassandra.sh" :
	    require => File["/etc/init.d/cassandra"],
    	content => "export CASSANDRA_HOME=/usr/local/apache-cassandra/\nexport PATH=\$PATH:\$CASSANDRA_HOME/bin/:\$CASSANDRA_HOME/tools/bin/\n",
  	}

  	file_line {"bashrc":
  		require => File['/etc/profile.d/cassandra.sh'],
		path => "/etc/bash.bashrc",
		line => 'source /etc/profile.d/cassandra.sh',
  	}

	service { 'cassandra' :
		require => File_line['bashrc'],
		ensure => running,
		enable => true,
	}

	file { '/usr/local/bin/cassandra_backup.sh':
		require => Service["cassandra"],
		source => "puppet:///modules/cassandra/cassandra_backup.sh",
		mode => 744,
	}	

	if($backup_root != ''){
		exec {'backup_dir':
			command => "/bin/mkdir -p $backup_root > /dev/null 2>&1",
			creates => $backup_root,
			subscribe => File["/usr/local/bin/cassandra_backup.sh"],
		}

		file { [
			"$backup_root/logs"]:
			ensure => directory,
    	   	mode => 644,
    	   	require => Exec["backup_dir"],
		}

		cron { 'cassandra_backup':
			subscribe => File["$backup_root/logs"],
			command => ". /etc/profile.d/cassandra.sh && /usr/local/bin/cassandra_backup.sh -br $backup_root -d /var/lib/cassandra/data -u '$user' -pw '$password' >> $backup_root/logs/\$(uname -n)_cassandra_backup_log",
			hour => 3,
			minute => 45,
		}
	}

	$ip_parts = split($listen_address, "[.]")
	$total_minutes = (($ip_parts[-1]) + 0) * 15
	$repair_day = $total_minutes / (60 * 24)
	$repair_hour = ($total_minutes - ($repair_day * 60 * 24)) / 60
	$repair_minute = $total_minutes - ($repair_day * 60 * 24) - ($repair_hour * 60)

	cron { 'cassandra_repair':
		subscribe => File["/usr/local/bin/cassandra_backup.sh"],
		command => ". /etc/profile.d/cassandra.sh && nodetool repair -pr",
		weekday => $repair_day,
		hour => $repair_hour,
		minute => $repair_minute,
	}
}
