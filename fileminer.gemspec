require_relative 'lib/fileminer/version'

Gem::Specification.new do |spec|
  spec.name          = 'fileminer'
  spec.version       = FileMiner::VERSION
  spec.authors       = ['Fang MinJie']
  spec.email         = ['fmjsjx@163.com']

  spec.summary       = 'A simple file/log transfer tool coding by ruby.'
  spec.description   = 'A simple file/log transfer tool coding by ruby.'
  spec.homepage      = 'https://github.com/fmjsjx/fileminer'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 2.3.0'

  spec.files         = Dir['LICENSE', 'README.md', 'lib/**/*', 'bin/*', 'conf/*.yml']
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
