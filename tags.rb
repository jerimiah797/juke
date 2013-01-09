require 'json'
require 'rest-client'
require 'uri'
require 'highline/import'
require 'addressable/uri'
require 'librtmp'
require 'open4'
require 'streamio-ffmpeg'
require 'mp3info'
require 'vlcrc'

#Mp3Info.open("testfile3.mp3") do |mp3|
#	mp3.tag.title = "Song Title"
#	mp3.tag.artist = "Band Name"
#	mp3.tag.album = "Album Name"
#	mp3.tag.tracknum = 5
#end



# read and display infos & tags
#Mp3Info.open("testfile3.mp3") do |mp3|
#  puts mp3
#end
$track_id = "Tra.67752792"
track_metadata_url = "http://direct.rhapsody.com/metadata/data/methods/getLiteTrack.js?developerKey=4B8C5B7B5B7B5I4H&cobrandId=40134&filterRightsKey=0&trackId=#{$track_id}"
@metadata_hash = JSON.parse(RestClient.get(track_metadata_url))

puts @metadata_hash["displayAlbumName"]
puts @metadata_hash["displayArtistName"]
puts @metadata_hash["name"] 
puts @metadata_hash["trackId"]
puts @metadata_hash["trackIndex"]