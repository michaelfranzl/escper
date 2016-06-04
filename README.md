Escper (read: "escaper") -- Easy printing to serial thermal printers
=======================================================================

Escper is a Ruby library that makes printing of plain text and images to one or several serial thermal printers easy. USB, serial (RS232) and TCP/IP based printers are supported. Escper is useful for Ruby-based Point of Sale (POS) systems that want to print receipts, tickets or labels.

Project status
--------------

Escper has been used as the printing 'engine' for my Point of Sale software [Salor Hospitality](https://github.com/michaelfranzl/SalorHospitality). However, since I do no longer develop or maintain Salor Hospitality, I have no plans to develop or maintain this library any further. The [version on Rubygems.org](https://rubygems.org/gems/escper) is [upstream/1.2.2](https://github.com/michaelfranzl/ruby-escper/releases/tag/upstream%2F1.2.2) and was working reliably with Ruby 1.9.3.

The source code in this repository is made available as-is, and you will need to have some Ruby skills to fix issues in your specific application.



Installation
------------

    gem install escper
    
Introduction
------------



While the actual printing is just writing a bytearray to a device node located inside of `/dev`, there is some preprocessing necessary. Thermal printers usually have a narrow and custom character set, do not support UTF-8, only ASCII-8BIT. However, Escper makes it possible to conveniently pass an UTF-8 string to the printing method, and it does all the conversion work under the hood. For special characters, Escper will map UTF-8 characters to the ASCII-8BIT codes that are actually supported by the currently enabled codepage on the printer (have a look at the user manual of your printer). The file `lib/escper/codepages.yml` is an example for matching UTF-8 codes to ASCII codes of the standard codepage of the commonly available Espon and Metapace printers.

Another tricky usecase is where text is mixed with images. Images are transformed into ESCPOS compatible printing data, which is supported by the majority of thermal printers. When mixing text and images in one print 'document', Escper will still transform special UTF-8 characters according to the above mentioned codepages.yml file, but leave the image data raw i.e. unchanged.

Escper only supports printers which support plain data-copy to their device node living under `/dev` or via a TCP socket. Printers for which the Linux Kernel does not create a device node that can be opened as a file or as a Serial Port, or non-plain-TCP printers are not supported. Escper does not care about the formatting of the text; it is up to the user to pass those formatting commands as part of the printing string. An exception are images; those are converted to ESCPOS code always.

Some Point of Sale systems, especially those for restaurants, have to send tickets to several printers/locations at the same time (e.g. kitchen, bar, etc.). Escper makes this easy. Have a look at the usage examples below.

Usecase: Convert image to ESCPOS code
------------

Load Escper:

    require 'escper'
    
The source of the image can be a file:

    escpos_code = Escper::Img.new('/path/to/test.png', :file).to_s

The source of the image can also be data which is uploaded via a HTML form. Here, the variable `data` is a variable containing the image data of a multipart HTML form. The following code would work in Ruby on Rails:

    escpos_code = Escper::Img.new(data.read, :blob).to_s
    
Alternatively, the image source can also be a dynamically created ImageMagick canvas:

    canvas = Magick::Image.new(512, 128)
    gc = Magick::Draw.new
    gc.stroke('black')
    gc.stroke_width(5)
    gc.fill('white')
    gc.fill_opacity(0)
    gc.stroke_antialias(false)
    gc.stroke_linejoin('round')
    gc.translate(-10,-39)
    gc.scale(1.11,0.68)
    gc.path("M 14,57 L 14,56 L 15,58 L 13,58 L 14,57 L 21,59 28,60 34,62 40,65 46,67 52,68 56,70 61,72 66,73 70,74 75,74")
    gc.draw(canvas)
    escpos_code = Escper::Img.new(canvas,:obj).to_s

For optimal visual results, when using a file or a blob, the image should previously be converted to an indexed, black and white 1-bit palette image. In Gimp, click on "Image -> Mode -> Indexed..." and select "Use black and white (1-bit) palette". For dithering, choose "Floyd-Steinberg (reduced color bleeding)". The image size depends on the resolution of the printer.

To print an image directly on a thermal receipt printer, in just one line:

    File.open('/dev/usb/lp0','w') { |f| f.write Escper::Img.new('/path/to/image.png', :file).to_s }
    
    
Usecase: Print UTF-8 text to several printers at the same time
------------

First, in Ruby, create objects of the class named `VendorPrinter` which are simply containers for configuration data about the printer. If you develop your application in a framework like Ruby on Rails, you also can use the models from the Rails application instead of creating them from within Escper. The only requirements are that the objects respond to the methods `id`, `name`, `path`, `copies`, `codepage` and `baudrate`. Here we are creating 3 printers of the types USB, RS232 and TCP/IP:

    vp1 = Escper::VendorPrinter.new :id => 1, :name => 'Printer 1 USB', :path => '/dev/usb/lp0', :copies => 1
    vp2 = Escper::VendorPrinter.new :id => 2, :name => 'Printer 2 RS232', :path => '/dev/ttyUSB0', :copies => 1
    vp3 = Escper::VendorPrinter.new :id => 3, :name => 'Printer 3 TCP/IP', :path => '192.168.0.201:9100', :copies => 1
    
`id` must be unique integers which will be needed later during printing. `name` is an arbitrary string which is only used for logging. `path` is the path to a regular file, serial device node or `IP:port` of the thermal printer (with a colon). Device nodes can be of the type USB, serial port (RS232) or TCP/IP. `copies` are the number of duplications of pages that the printer should print. Optionally, you can pass in the key `codepage` which is a number that must correspond to one of the YAML keys in the file `codepages.yml`. By making the `codepage` a parameter of the printer model, it is possible to use several different printers from different manufacturers with different character sets at the same time. `baudrate` is an optional integer to set the speed of the transmission (the default is 9600, this setting is only effective when using RS232 communication).

Next, initialize the printing engine of Escper by passing it an array of the VendorPrinter instances. It is also possible to pass a single VendorPrinter instance instead of an Array. As mentioned earlier, you also can pass instances or Arrays of instances of a class that is named differently (e.g. ActiveRecord queries), as longs as it responds to the afore mentioned attributes:

    print_engine = Escper::Printer.new 'local', [vp1, vp2, vp3]
    
Now, open all device nodes as specified in `new`:

    print_engine.open
    
After this, you can finally print text and images. Text must be UTF-8 encoded. The fist parameter is the `id` of the printer object that should be printed to. The second parameter is the actual text:

    print_engine.print 1, 'print text to printer 1'
    print_engine.print 2, 'print text to printer 2'
    print_engine.print 3, 'print text to printer 3'
    
The `print` method will return an array which contains the number of bytes actually written to the device node, as well as the raw text that was written to the device node.

After printing is finished, don't forget to close the device nodes which were openened during the `open` call:

    print_engine.close

    
Usecase: Print UTF-8 text mixed with binary images
------------

Create a printer object:

    vp1 = Escper::VendorPrinter.new :id => 1, :name => 'Printer 1 USB', :path => '/dev/usb/lp0', :copies => 1
    
Render images into ESCPOS code, stored in variables:

    image_escpos1 = Escper::Img.new('/path/to/test1.png', :file).to_s
    image_escpos2 = Escper::Img.new('/path/to/test2.png', :file).to_s
    
This raw image data now must be stored in a hash, whith a unique key that gives the image a unique name. This is necessary so that the image code will not be distorted by the codepage transformation.

    raw_images = {:image1 => image_escpos1, :image2 => image_escpos2}
    
Initialize the print engine:

    print_engine = Escper::Printer.new 'local', vp1
    
Open the printer device nodes:

    print_engine.open
    
Print text and image at the same time:

    print_engine.print 1, "print text and image1 {::escper}image1{:/} and image 2 {::escper}image1{:/} to printer 1", raw_images
    
Note that the special tag `{::escper}image_key{:/}` will be replaced with the image that is stored in the hash `raw_images` with the key `image_key`.

After printing is done, close the device nodes again:

    print_engine.close
    

Fallback mode
----------------------

If a device node is busy or not writable, Escper will create fallback files instead and append the print data to that file. The fallback files will have the name of the printers and will by default be saved in `/tmp`, or, when you include Escper from Rails, in the `tmp` folder of the Rails app source. A connection to an IP address (a TCP socket) must succeed within 2 seconds, otherwise the fallback mode becomes enabled.

Configuration
----------------------

You can configure Escper by calling in your project:

    Escper.setup do |config|
      config.codepage_file = File.join('path', 'to', 'codepages.yml')
      config.use_safe_device_path = false
      config.safe_device_path = File.join('path', 'to', 'outputdir')
    end

`codepage_file` specifies the path to `codepages.yml`. (for an explanation see above). If not specified, the file `codepages.yml` that is part of this gem distribution will be used.

`use_safe_device_path` can be set to `true` for security reasons when you are running Escper on a remote server and no actual writes to physical printers should occur. In this case, all print data will always be stored in regular files in the path `safe_device_path` with safe/escaped file names, which can be further processed or served by other programs.
    




License
----------------------

Copyright (C) 2011-2013  Michael Franzl

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.