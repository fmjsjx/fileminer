# fileminer
[![Gem Version](https://d25lcipzij17d.cloudfront.net/badge.svg?id=rb&type=6&v=1.0.0&x2=0)](https://rubygems.org/gems/fileminer)
[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/fmjsjx/fileminer/blob/master/LICENSE)


A simple line based file/log transfer tool coding by ruby.

# quick start
1. installation

Install fileminer from RubyGems:
```
$ gem install fileminer
Fetching fileminer-1.0.0.gem
Successfully installed fileminer-1.0.0
Parsing documentation for fileminer-1.0.0
Installing ri documentation for fileminer-1.0.0
Done installing documentation for fileminer after 0 seconds
1 gem installed
$ _
```

2. setting up fileminer

+generate configuration file

At first, we should generate the fileminer configuration file.

We provide a command tool 'fileminer-genconf' to generate configurations:
```
$ fileminer-genconf -h
Usage: fileminer-genconf [options]

Options:
    -t, --type fileminer|supervisor  Type of the config file to be generated
                                     Default is fileminer
    -o, --out [path]                 Output content to a file
                                     For type fileminer, default is /etc/fileminer/fileminer.yml
                                     For type supervisor, default is ./fileminer.ini
    -h, --help                       Print help
$ _
```

Generation with default options:
```
$ fileminer-genconf -o
generated config file: /etc/fileminer/fileminer.yml
$ _
```

+config input on fileminer.yml

Edit fileminer.inputs on fileminer.yml:
```yaml
fileminer.inputs:
  paths:
    - /path/to/*.log
```

+configure output on fileminer.yml

In current version, fileminer provides three output plugins: redis, kafka & mysql. One process can only choose one of them.

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

3. runnning fileminer

Run in command line:
```
$ fileminer

```
or
```
$ fileminer /path/to/fileminer.yml

```
