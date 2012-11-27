module Escper
  class Printer
    # mode can be local or sass
    # vendor_printers can either be a single VendorPrinter object, or an Array of VendorPrinter objects, or an ActiveRecord Relation containing VendorPrinter objects.
    def initialize(mode, vendor_printers = nil)
      @mode = mode
      @open_printers = Hash.new
      @codepages_lookup = YAML::load(File.read(Escper.codepage_file))
      if vendor_printers.kind_of?(ActiveRecord::Relation) or vendor_printers.kind_of?(Array)
        @vendor_printers = vendor_printers
      elsif vendor_printers.kind_of? VendorPrinter
        @vendor_printers = [vendor_printers]
      else
        # If no available VendorPrinters are initialized, create a set of temporary VendorPrinters with usual device paths.
        puts "No VendorPrinters specified. Creating a set of temporary printers with usual device paths"
        paths = ['/dev/ttyUSB0', '/dev/ttyUSB1', '/dev/ttyUSB2', '/dev/usb/lp0', '/dev/usb/lp1', '/dev/usb/lp2', '/dev/salor-hospitality-front', '/dev/salor-hospitality-top', '/dev/salor-hospitality-back-top-left', '/dev/salor-hospitality-back-top-right', '/dev/salor-hospitality-back-bottom-left', '/dev/salor-hospitality-back-bottom-right']
        @vendor_printers = Array.new
        paths.size.times do |i|
          @vendor_printers << VendorPrinter.new(:name => paths[i].gsub(/^.*\//,''), :path => paths[i], :copies => 1, :codepage => 0)
        end
      end
    end

    def print(printer_id, text, raw_text_insertations={})
      return if @open_printers == {}
      ActiveRecord::Base.logger.info "[PRINTING]============"
      ActiveRecord::Base.logger.info "[PRINTING]PRINTING..."
      printer = @open_printers[printer_id]
      raise 'Mismatch between open_printers and printer_id' if printer.nil?

      codepage = printer[:codepage]
      codepage ||= 0
      output_text = Printer.merge_texts(text, raw_text_insertations, codepage)
      
      ActiveRecord::Base.logger.info "[PRINTING]  Printing on #{ printer[:name] } @ #{ printer[:device].inspect }."
      bytes_written = nil
      printer[:copies].times do |i|
        # The method .write works both for SerialPort object and File object, so we don't have to distinguish here.
        bytes_written = @open_printers[printer_id][:device].write output_text
        ActiveRecord::Base.logger.info "[PRINTING]ERROR: Byte count mismatch: sent #{text.length} written #{bytes_written}" unless output_text.length == bytes_written
      end
      # The method .flush works both for SerialPort object and File object, so we don't have to distinguish here. It is not really neccessary, since the close method will theoretically flush also.
      @open_printers[printer_id][:device].flush
      return bytes_written, output_text
    end
    
    def self.merge_texts(text, raw_text_insertations, codepage = 0)
      asciifier = Escper::Asciifier.new(codepage)
      asciified_text = asciifier.process(text)
      raw_text_insertations.each do |key, value|
        markup = "{::escper}#{key.to_s}{:/}".encode('ASCII-8BIT')
        asciified_text.gsub!(markup, value)
      end
      return asciified_text
    end

    def identify(chartest=nil)
      ActiveRecord::Base.logger.info "[PRINTING]============"
      ActiveRecord::Base.logger.info "[PRINTING]TESTING Printers..."
      open
      @open_printers.each do |id, value|
        init = "\e@"
        cut = "\n\n\n\n\n\n" + "\x1D\x56\x00"
        testtext =
        "\e!\x38" +  # double tall, double wide, bold
        "#{ I18n.t :printing_test }\r\n" +
        "\e!\x00" +  # Font A
        "#{ value[:name] }\r\n" +
        "#{ value[:device].inspect }"
        
        ActiveRecord::Base.logger.info "[PRINTING]  Testing #{value[:device].inspect }"
        if chartest
          print(id, init + Escper::Asciifier.all_chars + cut)
        else
          ascifiier = Escper::Asciifier.new(value[:codepage])
          print(id, init + ascifiier.process(testtext) + cut)
        end
      end
      close
    end

    def open
      ActiveRecord::Base.logger.info "[PRINTING]============"
      ActiveRecord::Base.logger.info "[PRINTING]OPEN Printers..."
      @vendor_printers.size.times do |i|
        p = @vendor_printers[i]
        name = p.name
        path = p.path
        codepage = p.codepage

        if Escper.use_safe_device_path == true
          sanitized_path = path.gsub(/[\/\s'"\&\^\$\#\!;\*]/,'_').gsub(/[^\w\/\.\-@]/,'')
          path = File.join(Escper.safe_device_path, "#{sanitized_path}.salor") 
        end

        ActiveRecord::Base.logger.info "[PRINTING]  Trying to open #{ name } @ #{ path } ..."
        pid = p.id ? p.id : i
        begin
          printer = SerialPort.new path, 9600
          @open_printers.merge! pid => { :name => name, :path => path, :copies => p.copies, :device => printer, :codepage => codepage }
          ActiveRecord::Base.logger.info "[PRINTING]    Success for SerialPort: #{ printer.inspect }"
          next
        rescue Exception => e
          ActiveRecord::Base.logger.info "[PRINTING]    Failed to open as SerialPort: #{ e.inspect }"
        end

        begin
          printer = File.open path, 'wb'
          @open_printers.merge! pid => { :name => name, :path => path, :copies => p.copies, :device => printer, :codepage => codepage }
          ActiveRecord::Base.logger.info "[PRINTING]    Success for File: #{ printer.inspect }"
          next
        rescue Errno::EBUSY
          ActiveRecord::Base.logger.info "[PRINTING]    The File #{ path } is already open."
          ActiveRecord::Base.logger.info "[PRINTING]      Trying to reuse already opened printers."
          previously_opened_printers = @open_printers.clone
          previously_opened_printers.each do |key, val|
            ActiveRecord::Base.logger.info "[PRINTING]      Trying to reuse already opened File #{ key }: #{ val.inspect }"
            if val[:path] == p[:path] and val[:device].class == File
              ActiveRecord::Base.logger.info "[PRINTING]      Reused."
              @open_printers.merge! pid => { :name => name, :path => path, :copies => p.copies, :device => val[:device], :codepage => codepage }
              break
            end
          end
          unless @open_printers.has_key? p.id
            path = File.join(Rails.root, 'tmp')
            printer = File.open(File.join(path, "#{ p.id }-#{ name }-fallback-busy.salor"), 'wb')
            @open_printers.merge! pid => { :name => name, :path => path, :copies => p.copies, :device => printer, :codepage => codepage }
            ActiveRecord::Base.logger.info "[PRINTING]      Failed to open as either SerialPort or USB File and resource IS busy. This should not have happened. Created #{ printer.inspect } instead."
          end
          next
        rescue Exception => e
          path = File.join(Rails.root, 'tmp')
          printer = File.open(File.join(path, "#{ p.id }-#{ name }-fallback-notbusy.salor"), 'wb')
          @open_printers.merge! pid => { :name => name, :path => path, :copies => p.copies, :device => printer, :codepage => codepage }
          ActiveRecord::Base.logger.info "[PRINTING]    Failed to open as either SerialPort or USB File and resource is NOT busy. Created #{ printer.inspect } instead."
        end
      end
    end

    def close
      ActiveRecord::Base.logger.info "[PRINTING]============"
      ActiveRecord::Base.logger.info "[PRINTING]CLOSING Printers..."
      @open_printers.each do |key, value|
        begin
          value[:device].close
          ActiveRecord::Base.logger.info "[PRINTING]  Closing  #{ value[:name] } @ #{ value[:device].inspect }"
          @open_printers.delete(key)
        rescue Exception => e
          ActiveRecord::Base.logger.info "[PRINTING]  Error during closing of #{ value[:device] }: #{ e.inspect }"
        end
      end
    end
  end
end