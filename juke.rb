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
require 'open3'
require 'streamio-ffmpeg'
require 'mp3info'
require 'thread'
require 'gst'

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
      
      puts "\nLogin Successful. "
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
  attr_accessor :song_id
  attr_accessor :track_title
  attr_accessor :track_artist
  attr_accessor :track_album
  attr_accessor :track_num
  attr_accessor :disc_num
  attr_accessor :mediaUrl
  attr_accessor :playbackSessionId
  attr_accessor :success
  attr_accessor :stream_pid
  
  def initialize( song_id )
    self.song_id = song_id
    self.success = true
    self.stream_pid = ""
  end
  def get_track_mediaurl (token)
    url = "https://playback.rhapsody.com/getContent.json?token=#{encode(token)}&trackId=#{self.song_id}&pcode=rn&nimdax=true&mid=123"    
    #puts "Trying #{url}"
    @track_hash = JSON.parse(RestClient.get(url))
    #puts @track_hash
    if !@track_hash["data"]["mediaUrl"]
      puts @track_hash["status"]["errorMessage"]
      self.success = false
      puts "Setting false for get_track_mediaurl"
      return
    end
    self.mediaUrl = @track_hash["data"]["mediaUrl"]
    self.playbackSessionId = @track_hash["data"]["playbackSessionId"]
  end
  def get_track_metadata
    url = "http://direct.rhapsody.com/metadata/data/methods/getLiteTrack.js?developerKey=#{$developerKey}&cobrandId=#{$cobrandId}&filterRightsKey=0&trackId=#{self.song_id}"
    @metadata_hash = JSON.parse(RestClient.get(url))
    self.track_title = @metadata_hash["name"]
    self.track_artist = @metadata_hash["displayArtistName"]
    self.track_album = @metadata_hash["displayAlbumName"]
    self.track_num = @metadata_hash["trackIndex"]
  end
  def put_track_metadata
    if !File.exists?("media/#{self.song_id}.mp3") 
      puts "Error: No file to add metadata to. Aborting"
      self.success = false
      return
    end
    Mp3Info.open("media/#{self.song_id}.mp3") do |mp3|
    	mp3.tag.title = self.track_title
    	mp3.tag.artist = self.track_artist
    	mp3.tag.album = self.track_album
    	mp3.tag.tracknum = self.track_num
    end
  end

  def fetch_flv
    puts "Downloading...."
    if self.mediaUrl
      for i in 1..5
        platform = "WIN 11,4,402,287"
        mpswf = "http://www.rhapsody.com/assets/flash/MiniPlayer.swf"
        uri = Addressable::URI.parse(self.mediaUrl)
        pathsub1 = uri.path[1..8]
        pathsub2 = uri.path[10..-1]
        seg1 = "#{uri.scheme}://#{uri.host}/#{pathsub1}"
        seg2 = pathsub1
        seg3 = "mp3:#{pathsub2}?#{uri.query}"
        cmdstring = %Q(rtmpdump -r "#{seg1}" -a "#{seg2}" -f "#{platform}" -W "#{mpswf}" -y "#{seg3}" -o "media/#{self.song_id}.flv")
        puts cmdstring

        # format for using rtmpgw to stream instead of download
        # rtmpgw -r "rtmpte://rhapsodyev-831.fcod.llnwd.net/a4376/v2" -a "a4376/v2" -f "WIN 11,4,402,287" -W "http://www.rhapsody.com/assets/flash/MiniPlayer.swf" -y "mp3:s/1/3/8/6/6/883266831?e=1358299355&h=f38fd1aa39ed5cbc6635f419f1f8b6f6" --sport 8902
        
        # connect to stream at http://0.0.0.0:8902
        status = Open4::popen4("sh") do |pid, stdin, stdout, stderr|
          stdin.puts(cmdstring)
          stdin.close

          log = "stderr : #{stderr.read.strip }"
 
        end
        #puts "Status: #{status.inspect}"
        if !File.zero?("media/#{self.song_id}.flv")
          #puts !File.zero?("media/#{@song_id}.flv")
          puts "Download successful!"
          return
        end
        puts "Unsuccessful attempt. Trying again..."
      end
      self.success = false
      puts "Five attempts failed"
    else
      puts "Error: Can't fetch track without mediaUrl"
      self.success = false
    end
  end
  def stream_flv
    puts "Connecting...."
    if self.mediaUrl
      
      platform = "WIN 11,4,402,287"
      mpswf = "http://www.rhapsody.com/assets/flash/MiniPlayer.swf"
      uri = Addressable::URI.parse(self.mediaUrl)
      pathsub1 = uri.path[1..8]
      pathsub2 = uri.path[10..-1]
      seg1 = "#{uri.scheme}://#{uri.host}/#{pathsub1}"
      seg2 = pathsub1
      seg4 = encode_amp(uri.query)
      
      seg3 = "mp3:#{pathsub2}?#{seg4}"
      cmdstring = %Q(r="#{seg1}"&a=#{seg2}&f="#{platform}"&b=20000000&W=#{mpswf}&y=#{seg3})
      
      string2 = URI.escape(cmdstring)
      string3 = %Q(mplayer -slave -cache 8192 -cache-min 5 "http://127.0.0.1:8902/?#{string2}")
      MPlayer.play_stream(string3)
    else
      puts "Error: Can't fetch track without mediaUrl"
      self.success = false
    end
  end
  def strip_mp3
    puts "Transcoding..."
    if File.exists?("media/#{self.song_id}.flv") && !File.zero?("media/#{self.song_id}.flv")

      cmdstring = %Q(ffmpeg -i media/#{self.song_id}.flv -y -acodec copy media/#{self.song_id}.mp3)
      status = Open4::popen4("sh") do |pid, stdin, stdout, stderr|
        stdin.puts(cmdstring)
        stdin.close

        log = "stderr : #{stderr.read.strip }"
      end
      
      return
    end
    puts "Error: Zero length file. Aborting transcode"
    self.success = false
  end
  def process
    get_track_mediaurl ( $user.get_token) if self.success == true
    fetch_flv if self.success == true
    strip_mp3 if self.success == true
    put_track_metadata if self.success == true
    File.delete("media/#{self.song_id}.flv") if File.exists?("media/#{self.song_id}.flv")
    self.success
  end
  def play_stream
    puts "Getting mediaurl"
    get_track_mediaurl ( $user.get_token) if self.success == true
    puts "Got mediaurl"
    puts "Launching stream"
    stream_flv if self.success == true
    self.success
  end
  def pause
    MPlayer.pause
  end
end

def encode(thing)
  URI.escape(thing,Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
end
def encode_amp(thing)
  URI.escape(thing, "&")
end
def launch_rtmpgw
  @pid, @stdin, @stdout, @stderr = Open4::popen4("rtmpgw -g 8902")
  

  #log_out = "stdout : #{@stdout.read.strip }"
  #log_err = "stdout : #{@stdout.read.strip }"
  puts "Re-streamer launched!"
  @pid
  #@ignored, @status = Process::waitpid2 @pid
  #puts "show this text"
  #puts "exit status: #{@status.exitstatus} "
  #puts "Status: #{@status.inspect}"
end

class MPlayer 
  def MPlayer.play_stream(launcher)
    #return false if connected?
    puts RUBY_PLATFORM
    # initialize open4
    puts "Entering launch function"
    
    pid, stdin, stdout, stderr = Open4::popen4("sh")
    if RUBY_PLATFORM =~ /(win|w)(32|64)$/
      %x{ start #{@bin} #{@extra_args} --lua-config "rc={host='#{@host}:#{@port}',flatplaylist=0}" >nul 2>&1 }
    elsif RUBY_PLATFORM =~ /darwin/ && File.exists?('/usr/local/bin/mplayer') 
      
      system launcher
      #pid, stdin, stdout, stderr = Open4::popen4("sh")
      #stdin.puts(launcher)
      #puts "MPlayer should be playing"
      
      
      #log = "stdout: #{stdout.read.strip}"
    
      #puts @pid
      #@ignored, @status = Process::waitpid2 @pid
      #puts "show this text"
      #puts "exit status: #{@status.exitstatus} "
    else
      @stdin.puts "vlc -I rc"
      puts "VLC Linux standing by!"
      
      #puts "stdout: #{@stdout.read.strip}"
      # system "vlc -I rc"
    end
    true
  end
  def MPlayer.play_file(song)
    #return false if connected?
    puts RUBY_PLATFORM
    # initialize open4
    #puts "Entering launch function"
    pid, stdin, stdout, stderr = Open4::popen4 "sh"

    if RUBY_PLATFORM =~ /(win|w)(32|64)$/
      %x{ start #{@bin} #{@extra_args} --lua-config "rc={host='#{@host}:#{@port}',flatplaylist=0}" >nul 2>&1 }
    elsif RUBY_PLATFORM =~ /darwin/ && File.exists?('/usr/local/bin/mplayer') 
      stdin.puts "mplayer -slave -quiet media/#{song.song_id}.mp3"
      puts "Playing #{song.track_title}."
      #puts "stdout: #{@stdout.read.strip}"
    else
      @stdin.puts "vlc -I rc"
      puts "VLC Linux standing by!"
      
      #puts "stdout: #{@stdout.read.strip}"
      # system "vlc -I rc"
    end
    true
  end
  def MPlayer.pause
    @stdin.puts "pause"
    puts "Pause / Play"
  end
  def MPlayer.stop
    @stdin.puts "stop"
    puts "Pause / Play"
  end
end

class Album
  def initialize (album_id)
    @album_id = album_id
    @tracklist = []
  end
  def get_tracks
    url = "http://direct.rhapsody.com/metadata/data/methods/getAlbum.js?developerKey=#{$developerKey}&albumId=#{@album_id}&cobrandId=#{$cobrandId}&filterRightsKey=0"
    @metadata_obj = JSON.parse(RestClient.get(url))
    #puts JSON.pretty_generate(@metadata_obj)
    #puts @metadata_obj["displayName"]
    #puts @metadata_obj["releaseYear"]
    #print "Total number of tracks: "
    #puts @metadata_obj["trackMetadatas"].length
    for i in 0..@metadata_obj["trackMetadatas"].length-1
      x = Song.new(@metadata_obj["trackMetadatas"][i]["trackId"])
      x.track_title = @metadata_obj["trackMetadatas"][i]["name"]
      x.track_num = @metadata_obj["trackMetadatas"][i]["trackIndex"]
      x.disc_num = @metadata_obj["trackMetadatas"][i]["discIndex"]
      x.track_artist = @metadata_obj["primaryArtist"]["name"]
      x.track_album = @metadata_obj["displayName"]
      x.success = true
      @tracklist << x
      
    end
    #puts @tracklist
    #puts @tracklist.length
    count = 0
    @tracklist.each do |a| 
      
      count += 1
      print "Get track #{count}) "
      puts a.track_title  
      a.process    
    end
    #puts @tracklist[0].inspect
    #puts @tracklist[0].track_album
  end
  def play
    vlc.play
  end
end


#song_id = "Tra.65319668" #Bad track for testing
#song_id = "Tra.70625786" #New Bowie track
song_id = "Tra.51845000" #Zeldo techno
#song_id = "Tra.53550123" #short track for stream test
album_id = "Alb.27479292" # Radiohead OK computer

$user = Member.new
$user.sign_in
#server_pid = launch_rtmpgw


$current_song = Song.new( song_id )

running = true
answer = ""

while running
  answer = ask("Type a command or press 'h' for help") do |q|
           q.echo      = false
           q.character = true
           #q.validate  = /\A[#{choices}]\Z/
         end
  if answer == "q" 
    #system "kill #{server_pid}"
    puts "KTHXBYE"
    running = false
  elsif answer == "d"
    $current_song.get_track_metadata
    x = $current_song.process
    puts "Download failed. Press \"d\" to try again" if !x
    puts "Ready to play: #{$current_song.track_title}"
  elsif answer == "p"
    $current_song.play_stream
  elsif answer == " "
    $current_song.pause
  elsif answer == "a"
    album = Album.new(album_id)
    album.get_tracks
    #album.play
  else
    puts "Command not recognized."
  end
end

