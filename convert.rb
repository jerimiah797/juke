require 'rubygems'
require 'streamio-ffmpeg'
require 'mp3info'


movie = FFMPEG::Movie.new("testfile3.flv")

puts ("movie.duration: "+movie.duration.to_s)
puts ("movie.bitrate: "+movie.bitrate.to_s)
puts ("movie.size :"+movie.size.to_s)
puts ("movie.audio_stream :"+movie.audio_stream)
puts ("movie.audio_codec :"+movie.audio_codec)
puts ("movie.audio_sample_rate :"+movie.audio_sample_rate.to_s)
puts ("movie.audio_channels :"+movie.audio_channels.to_s)
puts ("movie.valid? :"+movie.valid?.to_s)
puts " "
puts "File is valid. Extracting mp3 audio track"
transcoded_audio = movie.transcode("media/testfile3.mp3", "-vn -acodec copy") #{
#  |progress| puts progress
#}
puts " "
puts "Done!"