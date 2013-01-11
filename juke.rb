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
      #puts "Data returned for "+@auth_hash["emailAddress"]
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
    #set_logon(gets().chomp)
    set_logon("jham@rhapsody.com") #temp to speed up testing
    print 'Enter your password: '
    #set_password(ask("") { |q| q.echo = false })
    set_password("$ust9*ru") #temp to speed up testing
    login_member()
  end
end


class Song
  def initialize( token, song_id )
    @token = token
    @song_id = song_id
    @success = true
  end
  def get_track_mediaurl
    url = "https://playback.rhapsody.com/getContent.json?token=#{encode(@token)}&trackId=#{@song_id}&pcode=rn&nimdax=true&mid=123"    
    #puts "Trying #{url}"
    @track_hash = JSON.parse(RestClient.get(url))
    #puts @track_hash
    if !@track_hash["data"]["mediaUrl"]
      puts @track_hash["status"]["errorMessage"]
      @success = false
      puts "Setting false for get_track_mediaurl"
      return
    end
    @mediaUrl = @track_hash["data"]["mediaUrl"]
    @playbackSessionId = @track_hash["data"]["playbackSessionId"]
  end
  def get_track_metadata
    url = "http://direct.rhapsody.com/metadata/data/methods/getLiteTrack.js?developerKey=#{$developerKey}&cobrandId=#{$cobrandId}&filterRightsKey=0&trackId=#{@song_id}"
    @metadata_hash = JSON.parse(RestClient.get(url))
  end
  def put_track_metadata
    if !File.exists?("media/#{@song_id}.mp3") 
      puts "Error: No file to add metadata to. Aborting"
      @success = false
      return
    end
    Mp3Info.open("media/#{@song_id}.mp3") do |mp3|
    	mp3.tag.title = @metadata_hash["name"]
    	mp3.tag.artist = @metadata_hash["displayArtistName"]
    	mp3.tag.album = @metadata_hash["displayAlbumName"]
    	mp3.tag.tracknum = @metadata_hash["trackIndex"]
    end
  end
  def fetch_flv
    if @mediaUrl
      platform = "WIN 11,4,402,287"
      mpswf = "http://www.rhapsody.com/assets/flash/MiniPlayer.swf"
      uri = Addressable::URI.parse(@mediaUrl)
      pathsub1 = uri.path[1..8]
      pathsub2 = uri.path[10..-1]
      seg1 = "#{uri.scheme}://#{uri.host}/#{pathsub1}"
      seg2 = pathsub1
      seg3 = "mp3:#{pathsub2}?#{uri.query}"
      cmdstring = %Q(rtmpdump -r "#{seg1}" -a "#{seg2}" -f "#{platform}" -W "#{mpswf}" -y "#{seg3}" -o "media/#{@song_id}.flv")
      #puts cmdstring
      system cmdstring
    else
      puts "Error: Can't fetch track without mediaUrl"
      @success = false
    end
  end
  def strip_mp3
    if File.zero?("media/#{@song_id}.flv") || !File.exists?("media/#{@song_id}.flv")
      puts "Error: Zero length file. Aborting transcode"
      @success = false
      return
    end
    movie = FFMPEG::Movie.new("media/#{@song_id}.flv")
    transcoded_audio = movie.transcode("media/#{@song_id}.mp3", "-vn -acodec copy")
  end
  def process
    get_track_metadata if @success == true
    get_track_mediaurl if @success == true
    fetch_flv if @success == true
    strip_mp3 if @success == true
    put_track_metadata if @success == true
    File.delete("media/#{@song_id}.flv") if File.exists?("media/#{@song_id}.flv")
    return @success
  end
end

def encode(thing)
  URI.escape(thing,Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
end

  
def play_mp3 (song_id)
  system "/Applications/VLC.app/Contents/MacOS/VLC -I rc media/#{song_id}.mp3"
end
=begin 
    Use this for future vlc launching
    # Launch an instance of VLC with the RC interface configured for the
    # specified TCP socket unless there already is one.
    def launch
      return false if connected?
      if RUBY_PLATFORM =~ /(win|w)(32|64)$/
        %x{ start #{@bin} #{@extra_args} --lua-config "rc={host='#{@host}:#{@port}',flatplaylist=0}" >nul 2>&1 }
      elsif RUBY_PLATFORM =~ /darwin/ && File.exists?('/Applications/VLC.app/Contents/MacOS/VLC') && @bin == 'vlc'
        %x{ /Applications/VLC.app/Contents/MacOS/VLC #{@extra_args} --extraintf=lua --lua-config "rc={host='#{@host}:#{@port}',flatplaylist=0}" >/dev/null 2>&1 & }
      else
        %x{ #{@bin} #{@extra_args} --lua-config "rc={host='#{@host}:#{@port}',flatplaylist=0}" >/dev/null 2>&1 & }
      end
      # TODO pre-lua rc interface (VLC version detection?)
      true
    end
=end


#song_id = "Tra.65319668" #Bad track for testing
song_id = "Tra.70625786" #New Bowie track
user = Member.new
user.sign_in

running = true
answer = ""

while running
  puts "Type d to download the song, q to quit"
  answer = ask("") do |q|
           q.echo      = false
           q.character = true
           #q.validate  = /\A[#{choices}]\Z/
         end
  #say("You typed: #{answer}")
  #puts "You typed #{answer}"
  if answer == "q" 
    puts "KTHXBYE"
    running = false
  elsif answer == "d"
    song = Song.new(user.get_token, song_id)
    x = song.process
    puts "Download failed. Press \"d\" to try again" if !x
  else
    puts "Command not recognized."
  end
end


#play_mp3(song_id)
