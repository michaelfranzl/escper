module Escper
  class Asciifier
    def initialize(codepage=0)
      @codepage = codepage
      @codepage_lookup_yaml = YAML::load(File.read(Escper.codepage_file))
    end
    
    def self.all_chars
      out = "\e@" # Initialize Printer
      out.encode!('ASCII-8BIT')
      33.upto(255) { |i| out += i.to_s(16) + i.chr + ' ' }
      return out
    end
    
    def process(text)
      output = ''
      output.encode 'ASCII-8BIT'
      0.upto(text.length - 1) do |i|
        char_utf8 = text[i]
        char_ascii = text[i].force_encoding('ASCII-8BIT')
        if char_ascii.length == 1
          output += char_ascii
        else
          output += codepage_lookup(char_utf8)
        end      
      end
      return output
    end
    
    def codepage_lookup(char)
      return '*'.force_encoding('ASCII-8BIT') unless @codepage_lookup_yaml[@codepage]
      
      output = @codepage_lookup_yaml[@codepage][char]
      if output
        output = output.chr
      else
        output = '?'
      end
      return output.force_encoding('ASCII-8BIT')
    end
    
  end
end