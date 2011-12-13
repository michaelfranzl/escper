# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "escper/version"

Gem::Specification.new do |s|
  s.name        = "escper"
  s.version     = Escper::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Michael Franzl"]
  s.email       = ["office@michaelfranzl.com"]
  s.homepage    = "http://michaelfranzl.com"
  s.summary     = %q{Converts bitmaps to the ESC/POS receipt printer command}
  s.description = %q{}

  s.rubyforge_project = "escper"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
