# Escper -- Convert an image to ESCPOS commands for thermal printers
# Copyright (C) 2011-2012  Michael Franzl <michael@billgastro.com>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'RMagick'

module Escper
  class Image
    def initialize(data, type)
      if type == :file
        @image = convert(Magick::Image.read(data).first)
      elsif type == :blob
        @image = convert(Magick::Image.from_blob(data).first)
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
      result = bits.collect{ |b| b.chr }.join
      escpos = "\x1D\x76\x30\x00#{@x.chr}\x00#{(@y*8).chr}\x00#{ result }"
      escpos.force_encoding('ISO-8859-15')
      return escpos
    end
  end
end
