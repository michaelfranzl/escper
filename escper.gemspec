# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "escper/version"

Gem::Specification.new do |s|
  s.name        = "escper"
  s.version     = Escper::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Red (E) Tools Ltd."]
  s.email       = ["office@red-e.eu"]
  s.homepage    = "http://red-e.eu"
  s.summary     = %q{Collection of essential tools that make printing of plain text and images to one or many serial thermal printers easy.}
  s.description = %q{Collection of essential tools that make printing of plain text and images to one or many serial thermal printers easy. Both USB and serial (RS232) printers are supported and detected automatically. Escper is useful for Ruby based Point of Sale systems that want to print receipts or tickets.}

  #s.rubyforge_project = "escper"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_dependency('rmagick')
  s.add_dependency('serialport')
end
