require 'RMagick'

dir = File.dirname(__FILE__)
Dir[File.expand_path("#{dir}/escper/*.rb")].uniq.each do |file|
  require file
end

module Escper
  mattr_accessor :codepage_file

  @@codepage_file = File.join(File.dirname(__FILE__), 'escper', 'codepages.yml')
  
  def self.setup
    yield self
  end
end
