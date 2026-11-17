# Removes embedded metadata from an image before it is stored, without re-encoding the picture.
# The reason is privacy: phone photos carry GPS position, device and time. JPEG keeps only its
# orientation, so photos still display the right way up.
module ImageMetadata
  class Malformed < StandardError; end

  PNG_DROP = %w[eXIf tEXt zTXt iTXt tIME].freeze
  WEBP_DROP = [ "EXIF", "XMP " ].freeze

  def self.strip(ext, data)
    case ext
    when "jpg"  then jpeg(data)
    when "png"  then png(data)
    when "webp" then webp(data)
    else data
    end
  end

  # Walk the segments before the image data. Drop EXIF/XMP (APP1), Photoshop/IPTC (APP13) and comments.
  def self.jpeg(d)
    segs, orientation, i = [], nil, 2
    loop do
      raise Malformed if i + 4 > d.bytesize || d.getbyte(i) != 0xFF
      marker = d.getbyte(i + 1)
      (i += 1; next) if marker == 0xFF
      break if marker == 0xDA
      len = d.byteslice(i + 2, 2).unpack1("n")
      raise Malformed if len < 2 || i + 2 + len > d.bytesize
      seg = d.byteslice(i, 2 + len)
      if marker == 0xE1
        orientation ||= exif_orientation(seg.byteslice(4..))
      elsif marker != 0xED && marker != 0xFE
        segs << seg
      end
      i += 2 + len
    end
    if orientation && orientation != 1
      at = segs.first&.getbyte(1) == 0xE0 ? 1 : 0
      segs.insert(at, orientation_segment(orientation))
    end
    d.byteslice(0, 2) + segs.join + d.byteslice(i..)
  end

  def self.exif_orientation(payload)
    return nil unless payload&.start_with?("Exif\x00\x00".b)
    tiff = payload.byteslice(6..)
    s, l = case tiff.byteslice(0, 2) when "II".b then %w[v V] when "MM".b then %w[n N] else return nil end
    off = tiff.byteslice(4, 4).unpack1(l)
    count = tiff.byteslice(off, 2).unpack1(s)
    count.times do |k|
      entry = tiff.byteslice(off + 2 + 12 * k, 12)
      next unless entry.byteslice(0, 2).unpack1(s) == 0x0112
      value = entry.byteslice(8, 2).unpack1(s)
      return (1..8).cover?(value) ? value : nil
    end
    nil
  rescue NoMethodError, TypeError, ArgumentError
    nil
  end

  def self.orientation_segment(value)
    tiff = "MM\x00\x2A".b + [ 8 ].pack("N") + [ 1 ].pack("n") + [ 0x0112, 3, 1 ].pack("nnN") + [ value, 0 ].pack("nn") + [ 0 ].pack("N")
    payload = "Exif\x00\x00".b + tiff
    "\xFF\xE1".b + [ payload.bytesize + 2 ].pack("n") + payload
  end

  def self.png(d)
    out, i = d.byteslice(0, 8), 8
    loop do
      raise Malformed if i + 12 > d.bytesize
      len = d.byteslice(i, 4).unpack1("N")
      type = d.byteslice(i + 4, 4)
      raise Malformed if i + 12 + len > d.bytesize
      out << d.byteslice(i, 12 + len) unless PNG_DROP.include?(type)
      i += 12 + len
      return out if type == "IEND".b
    end
  end

  def self.webp(d)
    body, i = "WEBP".b, 12
    while i + 8 <= d.bytesize
      type = d.byteslice(i, 4)
      len = d.byteslice(i + 4, 4).unpack1("V")
      padded = len + (len & 1)
      raise Malformed if i + 8 + len > d.bytesize
      chunk = d.byteslice(i, 8 + padded)
      chunk << "\x00".b if chunk.bytesize < 8 + padded
      if type == "VP8X".b && len >= 1
        chunk.setbyte(8, chunk.getbyte(8) & ~0x0C)
      end
      body << chunk unless WEBP_DROP.include?(type)
      i += 8 + padded
    end
    raise Malformed if body.bytesize <= 4
    "RIFF".b + [ body.bytesize ].pack("V") + body
  end
end
