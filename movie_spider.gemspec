# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'movie_spider/version'

Gem::Specification.new do |spec|
  spec.name          = "movie_spider"
  spec.version       = MovieSpider::VERSION
  spec.authors       = ["Davis Gao"]
  spec.email         = ["naitnix@126.com"]


  spec.summary       = %q{a spider for crawling info from youku tudou qq iqiyi and baidu}
  spec.description   = %q{a spider for crawling info from youku tudou qq iqiyi and baidu}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"

  spec.add_dependency "rspec"
  spec.add_dependency "micro_spider"
  spec.add_dependency "spreadsheet"
end
