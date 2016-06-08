lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'testributor/version'

Gem::Specification.new do |s|
  s.name             = 'testributor'
  s.version          = Testributor::VERSION
  s.date             = '2015-09-24'
  s.summary          = 'testributor'
  s.description      = 'Worker gem for testributor.com'
  s.authors          = ["Dimitris Karakasilis"]
  s.email            = ["dk@testributor.com"]
  s.files            = Dir.glob("{bin,lib}/**/*")
  s.homepage         = 'http://rubygems.org/gems/testributor'
  s.license          = 'all rights reserved' # TODO
  s.require_path     = 'lib'
  s.executables      << 'testributor'

  %w(oauth2 rugged minitest redis safe_yaml).each { |gem|  s.add_runtime_dependency gem  }
  %w(pry pry-nav minitest-stub_any_instance timecop minitest-stub-const).each { |gem| s.add_development_dependency gem }
end
