require "mp3info"

Mp3Info.open("media/testfile3.mp3") do |mp3|
	mp3.tag.title = "Song Title"
	mp3.tag.artist = "Band Name"
	mp3.tag.album = "Album Name"
	mp3.tag.tracknum = 5
end



# read and display infos & tags
Mp3Info.open("media/testfile3.mp3") do |mp3|
  puts mp3
end

