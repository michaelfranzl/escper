module Escper
  class Img
    def initialize(data, type)
      if type == :file
        @image = convert(Magick::Image.read(data).first)
      elsif type == :blob
        @image = convert(Magick::Image.from_blob(data).first)
      elsif type == :obj
        @image = convert(data)
      end
    end

    def convert(img=nil)
      if img.nil? and @image
        @image = @image.quantize 2, Magick::GRAYColorspace
        @image = crop(@image)
        return @image
      else
        img = img.quantize 2, Magick::GRAYColorspace
        img = crop(img)
        return img
      end
    end

    def crop(image)
      @x = (image.columns / 8.0).round
      @y = (image.rows / 8.0).round
      @x = 1 if @x == 0
      @y = 1 if @y == 0
      image = image.extent @x * 8, @y * 8
      return image
    end

    def to_a
      colorarray = @image.export_pixels
      return colorarray
    end

    def to_s
      colorarray = self.to_a
      bits = []
      mask = 0x80
      i = 0
      temp = 0
      (@x * @y * 8 * 3 * 8).times do |j|
        next unless (j % 3).zero?
        temp |= mask if colorarray[j] == 0 # put 1 in place if black
        mask = mask >> 1 # shift mask
        i += 3
        if i == 24
          bits << temp
          mask = 0x80
          i = 0
          temp = 0
        end
      end
      result = bits.pack("C*")
      p_cmd = "\x1D\x76\x30\x00"
      hdr = [@x, (@y*8)].pack("SS")
      escpos = ''
      escpos.encode! 'ASCII-8BIT'
      escpos += p_cmd + hdr + result
      return escpos
    end
  end
end
