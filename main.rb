require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'rest-client'
require 'rmagick'

IMG_MAX_SIZE = 128
CONFIG = YAML.load_file(File.expand_path('../config.yml', __FILE__))
URL = "https://#{CONFIG["team"]}.slack.com/customize/emoji"
COOKIES = Hash[*CONFIG["cookies"].split(/\s*;\s*/).map do |pair|
  pair.split('=')
end.flatten]

def fetch_crumb
  res = RestClient.get(URL, cookies: COOKIES)
  crumb = res.to_str.match(/name="crumb"\svalue="([^"]+)"/)[1]
end

def process_img(path)
  resized = false
  emoji_name = File.basename(path, ".*")
  img = Magick::Image.read(path).first

  if img.columns > IMG_MAX_SIZE || img.rows > IMG_MAX_SIZE
    img.resize_to_fit!(IMG_MAX_SIZE, IMG_MAX_SIZE)
    path = "#{path}.resized#{File.extname(path)}"
    img.write(path)
    resized = true
  end

  {
    name: emoji_name,
    file: File.new(path),
    resized: resized
  }
end

def upload_img(path)
  img = process_img(path)

  data = {
    multipart: true,
    add: 1,
    mode: :data,
    crumb: fetch_crumb,
    name: img[:name],
    img: img[:file]
  }

  RestClient.post(URL, data, cookies: COOKIES) rescue RestClient::Found

  File.delete(img[:file]) if img[:resized]
end

img_dir = ARGV[0]
Dir.foreach(img_dir) do |x|
  next if x.match(/^\./)
  puts "uploading #{x}"
  upload_img("#{img_dir}/#{x}")
end
