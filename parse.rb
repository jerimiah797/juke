require 'json'
require 'rest-client'
require 'uri'
require 'highline/import'
require 'addressable/uri'
require "addressable/template"
require 'librtmp'

mediaUrl = "rtmpte://rhapsodyev-507.fcod.llnwd.net/a4376/v1/s/7/0/5/3/3/136733507?e=1357255269&h=5bd1b78db9f983b9a16fce19b8736d2b"

=begin
This is what I need to make:

./rtmpdump -r "rtmpte://rhapsodyev-507.fcod.llnwd.net/a4376/v1" -a "a4376/v1" -f "WIN 11,4,402,287" 
-W "http://www.rhapsody.com/assets/flash/MiniPlayer.swf" -y "mp3:s/7/0/5/3/3/136733507?e=1357177177&h=150d691c99c999a7ea41f599e930fe20" 
-o testfile3.flv

=end


platform = "WIN 11,4,402,287"
mpswf = "http://www.rhapsody.com/assets/flash/MiniPlayer.swf"
filename = "testfile3.flv"

uri = Addressable::URI.parse(mediaUrl)

pathsub1 = uri.path[1..8]
pathsub2 = uri.path[10..-1]


seg1 = "#{uri.scheme}://#{uri.host}/#{pathsub1}"
seg2 = pathsub1
seg3 = "mp3:#{pathsub2}?#{uri.query}"


cmdstring = %Q(rtmpdump -r "#{seg1}" -a "#{seg2}" -f "#{platform}" -W "#{mpswf}" -y "#{seg3}" -o "#{filename}")
puts cmdstring
teststr = %Q(echo "hello $HOSTNAME")

system teststr

