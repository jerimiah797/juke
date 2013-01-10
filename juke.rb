=begin
This program is an attempt to interface with the Rhapsody APIs for basic playback from the command shell.
I have no idea what I'm doing.

=end

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

$developerKey = "4B8C5B7B5B7B5I4H"
$cobrandId = "40134"
$client_type = "sonos"
$localhost = "127.0.0.1"


class Member
  @logged_in = false
  def set_logon(aLogon)
    @logon = aLogon
  end
  def get_logon
    @logon
  end
  def set_password(aPassword)
    @password = aPassword
  end
  def get_password
    @password
  end
  def login_member ()
    auth_url = "http://rds-accountmgmt.internal.rhapsody.com/rhapsodydirectaccountmgmt/data/methods/authenticateMember.js?developerKey=#{$developerKey}&cobrandId=#{$cobrandId}&logon=#{encode(@logon)}&password=#{encode(@password)}"
    token_url = "http://rds-accountmgmt.internal.rhapsody.com/rhapsodydirectaccountmgmt/data/methods/getLogonToken.js?developerKey=#{$developerKey}&cobrandId=#{$cobrandId}&logon=#{encode(@logon)}&password=#{encode(@password)}"
    @auth_hash = JSON.parse(RestClient.get(auth_url))
    @token_hash = JSON.parse(RestClient.get(token_url))
    if @auth_hash["emailAddress"]==@logon
      @logged_in=true
      puts "Data returned for "+@auth_hash["emailAddress"]
      print "Login Successful. "
      puts "Welcome to Rhapsody!"
      @token = @token_hash["value"]
    else
      puts "Login Error: "+@auth_hash["localizedMessage"]
    end
  end
  def get_token
    @token
  end
  def sign_in
    puts 'Welcome to Juke, the Rhapsody shell client'
    print 'Enter your username: '
    set_logon(gets().chomp)
    print 'Enter your password: '
    set_password(ask("") { |q| q.echo = false })
    login_member()
  end
end
class Song
  def initialize( token, song_id )
    @token = token
    @song_id = song_id
  end
  def get_track_mediaurl
    url = "https://playback.rhapsody.com/getContent.json?token=#{encode(@token)}&trackId=#{@song_id}&pcode=rn&nimdax=true&mid=123"    
    @track_hash = JSON.parse(RestClient.get(url))
    @mediaUrl = @track_hash["data"]["mediaUrl"]
    @playbackSessionId = @track_hash["data"]["playbackSessionId"]
  end
  def get_track_metadata
    url = "http://direct.rhapsody.com/metadata/data/methods/getLiteTrack.js?developerKey=4B8C5B7B5B7B5I4H&cobrandId=40134&filterRightsKey=0&trackId=#{@song_id}"
    @metadata_hash = JSON.parse(RestClient.get(url))
  end
  def put_track_metadata
    Mp3Info.open("testfile3.mp3") do |mp3|
    	mp3.tag.title = @metadata_hash["name"]
    	mp3.tag.artist = @metadata_hash["displayArtistName"]
    	mp3.tag.album = @metadata_hash["displayAlbumName"]
    	mp3.tag.tracknum = @metadata_hash["trackIndex"]
    end
  end
  def fetch_flv
    platform = "WIN 11,4,402,287"
    mpswf = "http://www.rhapsody.com/assets/flash/MiniPlayer.swf"
    filename = "testfile3.flv"
    uri = Addressable::URI.parse(@mediaUrl)
    pathsub1 = uri.path[1..8]
    pathsub2 = uri.path[10..-1]
    seg1 = "#{uri.scheme}://#{uri.host}/#{pathsub1}"
    seg2 = pathsub1
    seg3 = "mp3:#{pathsub2}?#{uri.query}"
    cmdstring = %Q(rtmpdump -r "#{seg1}" -a "#{seg2}" -f "#{platform}" -W "#{mpswf}" -y "#{seg3}" -o "#{filename}")
    system cmdstring
  end
  def strip_mp3
    movie = FFMPEG::Movie.new("testfile3.flv")
    transcoded_audio = movie.transcode("testfile3.mp3", "-vn -acodec copy")
  end
  def process
    get_track_mediaurl
    get_track_metadata
    fetch_flv
    strip_mp3
    put_track_metadata
  end
end

def encode(thing)
  URI.escape(thing,Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
end

  
def play_mp3
  the_command = %Q(/Applications/VLC.app/Contents/MacOS/VLC -I rc testfile3.mp3)
  system the_command
end



song_id = "Tra.67752792"
user = Member.new
user.sign_in
song = Song.new(user.get_token, song_id)
song.process

play_mp3






