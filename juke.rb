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
$track_id = "Tra.67752792"

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
      #puts @auth_hash
      #puts "*****************"
      @token = @token_hash["value"]
      #puts "token = #{@token}"
      #puts "encoded token = #{encode(@token)}"
    else
      puts "Login Error: "+@auth_hash["localizedMessage"]
    end
  end
  def get_track
    get_track_url = "https://playback.rhapsody.com/getContent.json?token=#{encode(@token)}&trackId=#{$track_id}&pcode=rn&nimdax=true&mid=123"    
    @track_hash = JSON.parse(RestClient.get(get_track_url))
    @mediaUrl = @track_hash["data"]["mediaUrl"]
    @playbackSessionId = @track_hash["data"]["playbackSessionId"]
  end
  def get_track_metadata
    track_metadata_url = "http://direct.rhapsody.com/metadata/data/methods/getLiteTrack.js?developerKey=4B8C5B7B5B7B5I4H&cobrandId=40134&filterRightsKey=0&trackId=#{$track_id}"
    @metadata_hash = JSON.parse(RestClient.get(track_metadata_url))
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
    #puts cmdstring
    
    system cmdstring
  end
end

def encode(thing)
  URI.escape(thing,Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
end

def strip_mp3
  movie = FFMPEG::Movie.new("testfile3.flv")
  transcoded_audio = movie.transcode("testfile3.mp3", "-vn -acodec copy")
end
  
def play_mp3
  the_command = %Q(/Applications/VLC.app/Contents/MacOS/VLC -I rc testfile3.mp3)
  system the_command
end

def initializeUser
  puts 'Welcome to Juke, the Rhapsody shell client'
  print 'Enter your username: '
  @user.set_logon(gets().chomp)
  print 'Enter your password: '
  @user.set_password(ask("") { |q| q.echo = false })
  @user.login_member()
end


@user = Member.new
#initializeUser
#@user.get_track
@user.get_track_metadata
#@user.fetch_flv
#strip_mp3
@user.put_track_metadata
#play_mp3






