site :opscode

# note apt 1.7.0 is required for chef clients prior to 10.16.4
cookbook 'swift',               :path => '.'
cookbook 'apt',                 :git => 'git://github.com/opscode-cookbooks/apt.git', :tag => '1.7.0'
cookbook 'memcached'
cookbook 'sysctl'
cookbook 'statsd',              :git => 'git@github.com:att-cloud/cookbook-statsd.git'
