# fileminer
[![Gem Version](https://d25lcipzij17d.cloudfront.net/badge.svg?id=rb&type=6&v=1.2.1&x2=0)](https://rubygems.org/gems/fileminer)
[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/fmjsjx/fileminer/blob/master/LICENSE)


A simple line based file/log transfer tool coding by ruby.

# quick start
1. installation

Install fileminer from RubyGems:
```
$ gem install fileminer
Fetching fileminer-1.2.1.gem
Successfully installed fileminer-1.2.1
Parsing documentation for fileminer-1.2.1
Installing ri documentation for fileminer-1.2.1
Done installing documentation for fileminer after 0 seconds
1 gem installed
$ _
```

*Note: This tool now only support cruby.*


2. setting up fileminer

* generate configuration file

At first, we should generate the fileminer configuration file.

We provide a command tool 'fileminer-genconf' to generate configurations:
```
$ fileminer-genconf -h
Usage:
    fileminer-genconf [options]

Samples:
    fileminer-genconf -t fileminer -o      Generate config on /etc/fileminer/fileminer.yml
    fileminer-genconf -t supervisor -o -l  Generate ./fileminer.ini with logfile on
                                           /var/log/fileminer/stderr.log
    fileminer-genconf -t systemd -o        Generate systemd config on
                                           /usr/lib/systemd/system/fileminer.service

Options:
    -t fileminer|supervisor|systemd, Type of the config file to be generated
        --type                       Default is fileminer
    -o, --out [path]                 Output content to a file
                                     For type fileminer, default is /etc/fileminer/fileminer.yml
                                     For type supervisor, default is ./fileminer.ini
    -l, --logfile [path]             Logfile configured on supervisor config file
                                     Default is /var/log/fileminer/stderr.log
    -h, --help                       Print help

$ _
```

Generation with default options:
```
$ fileminer-genconf -o
generated config file: /etc/fileminer/fileminer.yml
$ _
```

* config input on fileminer.yml

Edit fileminer.inputs on fileminer.yml:
```yaml
fileminer.inputs:
  paths:
    - /path/to/*.log
```

* configure output on fileminer.yml

In current version, fileminer provides three prefab output plugins: redis, kafka & mysql. One process can only choose one of them.

**Output to redis:**

Redis output plugin now using LPUSH to send messages for each line.

Install redis client, fileminer use hiredis by default:
```
$ gem install redis hiredis
Fetching redis-4.1.0.gem
Successfully installed redis-4.1.0
Parsing documentation for redis-4.1.0
Installing ri documentation for redis-4.1.0
Done installing documentation for redis after 0 seconds
Fetching hiredis-0.6.3.gem
Building native extensions. This could take a while...
Successfully installed hiredis-0.6.3
Parsing documentation for hiredis-0.6.3
Installing ri documentation for hiredis-0.6.3
Done installing documentation for hiredis after 0 seconds
2 gems installed
$ _
```

Edit fileminer.yml:
```yaml
output.redis:
  # target redis server URI
  uri: redis://localhost:6379/0
  # target redis key, type must be LIST
  key: fileminer
```


**Output to kafka:**

Install kafka ruby client:
```
$ gem install ruby-kafka
Successfully installed ruby-kafka-0.7.5
Parsing documentation for ruby-kafka-0.7.5
Done installing documentation for ruby-kafka after 0 seconds
1 gem installed
$ _
```

Edit fileminer.yml
```yaml
output.kafka:
  brokers: ['host1:9092','host2:9092','host3:9092']
  client_id: fileminer
  topic: fileminer
```


**Output to MySQL:**

Install mysql2:
```
$ gem install mysql2
Building native extensions. This could take a while...
Successfully installed mysql2-0.5.2
Parsing documentation for mysql2-0.5.2
Done installing documentation for mysql2 after 0 seconds
1 gem installed
$ _
```

Edit fileminer.yml
```yaml
output.mysql:
  host: hostname
  port: 3306
  username: someuser
  password: somepwd
  database: somedb
  table: sometable
```


*Since 1.1.0, you can also use customized output plugin.*

**Output using customized output plugin:**

Get your script ready:
```ruby
require 'fileminer/plugins'

class YourPlugin < Output::OutputPlugin
  def initialize options
    ...
  end
  ...
  public
  def send_all(lines, &listener)
    ...
  end
  ...
end
```

Edit fileminer.yml
```yaml
output.script:
  script: /path/to/your_script.rb
  plugin_class: YourPlugin
  init_options:
    some_field: some value
```

3. runnning fileminer

Run in command line:
```
$ fileminer

```
or
```
$ fileminer /path/to/fileminer.yml

```
