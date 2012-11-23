require 'RMagick'

dir = File.dirname(__FILE__)
Dir[File.expand_path("#{dir}/escper/*.rb")].uniq.each do |file|
  require file
end

module Escper
  mattr_accessor :codepage_file, :use_safe_device_path, :safe_device_path

  @@codepage_file = File.join(File.dirname(__FILE__), 'escper', 'codepages.yml')
  @@use_safe_device_path = false
  @@safe_device_path = File.join('/','tmp')
  
  def self.setup
    yield self
  end
end
