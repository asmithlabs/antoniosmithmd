# Images for posts. Files live on the storage volume (storage/uploads) and are served at /uploads/<name>.
# No database table: the name is a hash of the stored bytes, so the same image uploaded twice is one file.
# Raster formats only. SVG is refused on purpose: served from this site's own origin it could carry script.
class ImageUpload
  class Rejected < StandardError; end

  MAX_BYTES = 5.megabytes
  TYPES = { "png" => "image/png", "jpg" => "image/jpeg", "gif" => "image/gif", "webp" => "image/webp" }.freeze
  NAME = /\A([0-9a-f]{32})\.(png|jpg|gif|webp)\z/

  def self.dir = Pathname.new(ENV["UPLOADS_DIR"].presence || Rails.root.join("storage/uploads").to_s)

  # Takes anything with #read (an uploaded file). Returns the stored file name. Raises Rejected with a
  # message that is safe to show the user.
  def self.store(io)
    raise Rejected, "no file was sent" unless io.respond_to?(:read)
    data = io.read(MAX_BYTES + 1).to_s.b
    raise Rejected, "the file is empty" if data.empty?
    raise Rejected, "the file is larger than 5 MB" if data.bytesize > MAX_BYTES
    ext = sniff(data) or raise Rejected, "only PNG, JPEG, GIF and WebP images are accepted"
    data = begin
      ImageMetadata.strip(ext, data)
    rescue ImageMetadata::Malformed
      raise Rejected, "the file is not a readable #{ext.upcase} image"
    end
    name = "#{Digest::SHA256.hexdigest(data)[0, 32]}.#{ext}"
    path = dir.join(name)
    unless path.exist?
      FileUtils.mkdir_p(dir)
      tmp = dir.join(".#{name}.#{SecureRandom.hex(4)}.tmp")
      File.binwrite(tmp, data)
      File.rename(tmp, path)
    end
    name
  end

  # [path, content_type] for a stored name, or nil. The name is rebuilt from the pattern's own captures,
  # so nothing from the request reaches the file system except 32 hex characters and a known extension.
  def self.find(name)
    m = NAME.match(name.to_s) or return nil
    path = dir.join("#{m[1]}.#{m[2]}")
    path.file? ? [ path, TYPES.fetch(m[2]) ] : nil
  end

  # The type comes from the file's first bytes, never from the name or the browser's Content-Type.
  def self.sniff(d)
    return "png"  if d.start_with?("\x89PNG\r\n\x1A\n".b)
    return "jpg"  if d.start_with?("\xFF\xD8\xFF".b)
    return "gif"  if d.start_with?("GIF87a".b, "GIF89a".b)
    return "webp" if d.byteslice(0, 4) == "RIFF".b && d.byteslice(8, 4) == "WEBP".b
    nil
  end
end
