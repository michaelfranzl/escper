module Escper
  class VendorPrinter

    def initialize(attrs)
      @name = attrs[:name]
      @path = attrs[:path]
      @copies = attrs[:copies]
      @codepage = attrs[:codepage]
      @baudrate = attrs[:baudrate]
      @baudrate ||= 9600
      @id = attrs[:id]
    end
    
    def name
      @name
    end
    
    def name=(name)
      @name = name
    end
    
    def path
      @path
    end
    
    def path=(path)
      @path = path
    end
    
    def copies
      @copies
    end
    
    def copies=(copies)
      @copies = copies
    end
    
    def codepage
      @codepage
    end
    
    def codepage=(codepage)
      @codepage = codepage
    end
    
    def baudrate
      @baudrate
    end
    
    def baudrate=(baudrate)
      @baudrate = baudrate
    end
    
    def id
      @id
    end
    
    def id=(id)
      @id = id
    end
  end
end