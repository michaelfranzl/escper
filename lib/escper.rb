require 'rmagick'
require 'yaml'
require 'timeout'

dir = File.dirname(__FILE__)
Dir[File.expand_path("#{dir}/escper/*.rb")].uniq.each do |file|
  require file
end

module Escper
  #mattr_accessor :codepage_file, :use_safe_device_path, :safe_device_path
  
  def self.codepage_file
    @@codepage_file
  end
  
  def self.codepage_file=(codepage_file)
    @@codepage_file = codepage_file
  end
  
  def self.use_safe_device_path
    @@use_safe_device_path
  end
  
  def self.use_safe_device_path=(use_safe_device_path)
    @@use_safe_device_path = use_safe_device_path
  end
  
  def self.safe_device_path
    @@safe_device_path
  end
  
  def self.safe_device_path=(safe_device_path)
    @@safe_device_path = safe_device_path
  end

  @@codepage_file = File.join(File.dirname(__FILE__), 'escper', 'codepages.yml')
  @@use_safe_device_path = false
  @@safe_device_path = File.join('/','tmp')
  
  def self.setup
    yield self
  end
end
