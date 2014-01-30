module Escper
  def self.log(text)
    if defined?(ActiveRecord)
      ActiveRecord::Base.logger.info "[ESCPER] #{ text }"
    else
      puts "[ESCPER] #{ text }"
    end
  end
end