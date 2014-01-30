module Escper
  class Printer
    
    # Creates a new Printer object.
    # +mode+:: can be either "local" or any other string. Currently only "local" is recognized. If set to anything else than "local", printing to TCP/IP based  printers will be disabled.
    # +vendor_printers+:: can either be a single object of class VendorPrinter, or an Array of objects of class VendorPrinter, or an ActiveRecord Relation containing objects which respond to the methods +id+, +path+, +name+, +copies+ and +codepage+.
    # +subdirectory+:: If the Escper module variable +use_safe_device_path+ is other than nil, it will not be printed to the path gived by the +path+ attribute of the printers, but +subdirectory+ will be the prefix for the path. This way, printing data are saved to regular files in a regular directory. This is useful if this printing data is processed and served by a webserver rather than being sent to a real printer immmediately.
    def initialize(mode="local", vendor_printers=nil, subdirectory=nil)
      @mode = mode
      @subdirectory = subdirectory
      @open_printers = {}
      @codepages_lookup = YAML::load(File.read(Escper.codepage_file))
      @file_mode = 'wb'
      
      if defined?(Rails)
        @fallback_root_path = Rails.root
      else
        @fallback_root_path = '/'
      end
      
      if vendor_printers.kind_of?(Array) or (defined?(ActiveRecord) == 'constant' and vendor_printers.kind_of?(ActiveRecord::Relation))
        @vendor_printers = vendor_printers
      elsif vendor_printers.kind_of?(VendorPrinter) or vendor_printers.kind_of?(::VendorPrinter)
        @vendor_printers = [vendor_printers]
      else
        # If no available VendorPrinters are initialized, create a set of temporary VendorPrinters with usual device paths.
        Escper.log "[initialize] No VendorPrinters specified. Creating a set of temporary printers with common device paths"
        paths = ['/dev/ttyUSB0', '/dev/ttyUSB1', '/dev/ttyUSB2', '/dev/usb/lp0', '/dev/usb/lp1', '/dev/usb/lp2']
        @vendor_printers = Array.new
        paths.size.times do |i|
          vp = VendorPrinter.new
          vp.name = paths[i].gsub(/^.*\//,'')
          vp.path = paths[i]
          vp.copies = 1
          vp.codepage = 0
        end
      end
    end

    # Outputs text to the printing device (File, SerialPort or TCPSocket)
    # +printer_id+:: The id of the printer which was passed to +new()+
    # +text+:: UTF-8 encoded string. UTF-8 will be converted to ASCII-8BIT encoding according to the +codepage+ attribute of a specified printer. Codepage lookup tables are in the file +codepages.yml+, included in this gem. +text+ may include tags in the format {::escper}my_tag{:/}.For example, this tag "my_tag" will be replaced by the value of the key "my_tag" in the +raw_text_insertations+ hash. No character conversion will be done for these insertations.
    # +raw_text_insertations+:: A hash specifying ASCII-8BIT encoded text for the keys given in the {::escper}{:/} tags. This is useful to send binary data to the printer (e.g. ESCPOS-encoded bitmaps), without being 'damaged' by the UTF-8 to ASCII-8BIT conversion.
    def print(printer_id, text, raw_text_insertations={})
      if @open_printers == {}
        Escper.log "[print] No printers have been opened. Not printing anything"
        return 0, ""
      end
      
      printer = @open_printers[printer_id]
      if printer.nil?
        Escper.log "[print] No printer with id #{ printer_id } has been opened."
        return 0, ""
      end

      codepage = printer[:codepage]
      codepage ||= 0
      
      output_text = Printer.merge_texts(text, raw_text_insertations, codepage)
      
      Escper.log "[print] Printing on #{ printer[:name] } @ #{ printer[:device].inspect }."
      
      bytes_written = nil
      printer[:copies].times do |i|
        # The method .write works for SerialPort, File and TCPSocket, so we don't have to distinguish here.
        bytes_written = @open_printers[printer_id][:device].write output_text
        if output_text.length != bytes_written
          Escper.log "[print] WARN: Byte count mismatch: sent #{text.length} bytes, actually written #{bytes_written} bytes"
        end
      end
      
      # The method .flush works for SerialPort, File and TCPSocket, so we don't have to distinguish here. It is not really neccessary, since the close method will theoretically flush also.
      @open_printers[printer_id][:device].flush
      
      Escper.log "[print] Written text: #{ output_text[0..60] }"
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

    # Open a set of usual printer device paths, print example text, then close the printers.
    # +chartest+:: Can be +true+ or +nil+. If true, a character test will be sent to the printer. If false, a test page containing the printer name and printer path will be sent to the printer.
    def identify(chartest=nil)
      Escper.log "[identify] ============"
      self.open
      @open_printers.each do |id, value|
        init = "\e@"
        cut = "\n\n\n\n\n\n" + "\x1D\x56\x00"
        
        testtext =
        "\e!\x38" +  # double tall, double wide, bold
        "#{ I18n.t :printing_test }\r\n" +
        "\e!\x00" +  # Font A
        "#{ value[:name] }\r\n" +
        "#{ value[:device].inspect }"
        
        if chartest
          Escper.log "[identify] Printing all possible characters"
          print(id, init + Escper::Asciifier.all_chars + cut)
        else
          Escper.log "[identify] Printing infos about this printer"
          ascifiier = Escper::Asciifier.new(value[:codepage])
          print(id, init + ascifiier.process(testtext) + cut)
        end
      end
      self.close
    end

    # Opens all printers as passed to +new+
    def open
      Escper.log "[open] ============"
      @vendor_printers.size.times do |i|
        p = @vendor_printers[i]
        name = p.name
        path = p.path
        codepage = p.codepage
        baudrate = p.baudrate

        if Escper.use_safe_device_path == true
          sanitized_path = path.gsub(/[\/\s'"\&\^\$\#\!;\*]/,'_').gsub(/[^\w\/\.\-@]/,'')
          path = File.join(Escper.safe_device_path, @subdirectory, "escpos", "#{sanitized_path}.bill")
          FileUtils.mkdir_p(File.dirname(path)) unless File.exists?(File.dirname(path))
          @file_mode = 'ab'
        end

        Escper.log "[open] Trying to open #{ name }@#{ path }@#{ baudrate }bps ..."
        pid = p.id ? p.id : i # assign incrementing id if none given
        
        # ================ TCPSOCKET PRINTERS =============================
        if @mode == "local"
          # Writing to IP Addresses is only supported in local mode
          if /\d+\.\d+\.\d+\.\d+:\d+/.match(path)
            ip_addr = /(\d+\.\d+\.\d+\.\d+)/.match(path)[1]
            port = /\d+\.\d+\.\d+\.\d+:(\d+)/.match(path)[1]
            Escper.log "[open]   Parsed IP #{ ip_addr} on port #{ port }"
            
            begin
              printer = nil
              Escper.log "[open]   Attempting to open TCPSocket at #{ ip_addr} on port #{ port } ... "
              Timeout.timeout(2) do
                printer = TCPSocket.new ip_addr, port
              end
              Escper.log "[open]   Success for TCPSocket: #{ printer.inspect }"
              @open_printers.merge! pid => {
                :name => name,
                :path => path,
                :copies => p.copies,
                :device => printer,
                :codepage => codepage
              }
              next
            rescue Errno::ECONNREFUSED
              Escper.log "[open]   TCPSocket ERROR: Connection refused at IP #{ ip_addr} on port #{ port }. Skipping this printer."
              next
            rescue Timeout::Error
              Escper.log "[open]   TCPSocket ERROR: Timeout #{ ip_addr} on port #{ port }. Skipping this printer."
              next
            rescue => e
              Escper.log "[open]   TCPSocket ERROR: Failed to open: #{ e.inspect }"
              next
            end
          else
            Escper.log "[open]   Path #{ path } is not in IP:port format. Not trying to open printer as TCPSocket."
          end
        else
          Escper.log "[open]   Mode is #{ @mode }. Not trying to open printer as TCPSocket."
        end
        
        # ================ SERIALPORT PRINTERS =============================
        begin
          printer = SerialPort.new path, baudrate
          @open_printers.merge! pid => {
            :name => name,
            :path => path,
            :copies => p.copies,
            :device => printer,
            :codepage => codepage
          }
          Escper.log "[open]   Success for SerialPort: #{ printer.inspect }"
          next
        rescue => e
          Escper.log "[open]   Failed to open as SerialPort: #{ e.inspect }"
        end

        
        # ================ FILE PRINTERS =============================
        begin
          printer = File.open path, @file_mode
          @open_printers.merge! pid => {
            :name => name,
            :path => path,
            :copies => p.copies,
            :device => printer,
            :codepage => codepage
          }
          Escper.log "[open]   Success for File: #{ printer.inspect }"
          next
        rescue Errno::EBUSY
          # This happens when there are 2 printes with the same path
          Escper.log "[open]   The File #{ path } is already open."
          Escper.log "[open]      Trying to reuse already opened printers."
          previously_opened_printers = @open_printers.clone
          previously_opened_printers.each do |key, val|
            Escper.log "[open]      Trying to reuse already opened File #{ key }: #{ val.inspect }"
            if val[:path] == p[:path] and val[:device].class == File
              Escper.log "[open]      Reused."
              @open_printers.merge! pid => {
                :name => name,
                :path => path,
                :copies => p.copies,
                :device => val[:device],
                :codepage => codepage
              }
              break
            end
          end
          unless @open_printers.has_key? p.id
            path = File.join(@fallback_root_path, 'tmp')
            printer = File.open(File.join(path, "#{ p.id }-#{ name }-fallback-busy.salor"), @file_mode)
            @open_printers.merge! pid => {
              :name => name,
              :path => path,
              :copies => p.copies,
              :device => printer,
              :codepage => codepage
            }
            Escper.log "[open]      Failed to open as either SerialPort or USB File and resource IS busy. This should not have happened. Created #{ printer.inspect } instead."
          end
          next
        rescue => e
          path = File.join(@fallback_root_path, 'tmp')
          printer = File.open(File.join(path, "#{ p.id }-#{ name }-fallback-notbusy.salor"), @file_mode)
          @open_printers.merge! pid => {
            :name => name,
            :path => path,
            :copies => p.copies,
            :device => printer,
            :codepage => codepage
          }
          Escper.log "[open]    Failed to open as either SerialPort or USB File and resource is NOT busy. Created #{ printer.inspect } instead."
        end
      end
    end

    # Closes all opened printers
    def close
      Escper.log "[close] ============"
      @open_printers.each do |key, value|
        begin
          # File, SerialPort, and TCPSocket all have the close method
          value[:device].close
          Escper.log "[close]  Closing  #{ value[:name] } @ #{ value[:device].inspect }"
          @open_printers.delete(key)
        rescue => e
          Escper.log "[close]  Error during closing of #{ value[:device] }: #{ e.inspect }"
        end
      end
    end
  end
end