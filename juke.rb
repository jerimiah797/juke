=begin
This program is an attempt to interface with the Rhapsody APIs for basic playback from the command shell.
I have no idea what I'm doing.

=end

require 'json'
require 'rest-client'
require 'uri'
require 'highline/import'
require 'addressable/uri'
require 'open4'
require 'streamio-ffmpeg'
require 'mp3info'
require 'base64'
require 'yaml'
require 'easy_mplayer'

#require_relative 'lib/mplayer.rb'

class Member
  
  attr_accessor :logon
  attr_accessor :password
  attr_accessor :token
  attr_accessor :apiServer
  attr_accessor :logged_in
  attr_accessor :info
  attr_accessor :filename
  attr_accessor :guid
  
  def initialize
    self.apiServer = "http://api-gateway-beta.rhapsody.com/v0"
    self.logged_in = false
    self.info = {}
    self.filename = ".juke-user"
  end

  def login_member ()
    url = "#{self.apiServer}/members/auth?username=#{$app.encode(self.logon)}&password=#{$app.encode(self.password)}"
    puts url
    auth_hash = JSON.parse(RestClient.post url, :headers => {"Authorization" => "Basic #{Base64.encode64("#{self.logon}:#{self.password}")}"})
    if auth_hash["username"]==self.logon
      self.logged_in=true
      puts "\n[i] Login Successful. "
      puts "[i] Welcome to Rhapsody!"
      puts auth_hash
      self.token = auth_hash["token"]
      self.guid = auth_hash["guid"]
      self.save_userinfo
    else
      puts "[!] Login Error: "+auth_hash["localizedMessage"]
    end
  end

  def sign_in
    puts '[i] Welcome to Juke, the Rhapsody shell client'
    if File.exists?(self.filename)
      puts "[i] Account info loaded from disk"
      self.info = YAML.load File.read(self.filename)
      self.logon = self.info["name"]
      self.password = self.info["pass"]
      self.token = self.info["token"]
      self.guid = self.info["guid"]
      return
    else
      print '[?] Enter your username: '
      self.logon = gets().chomp
      print '[?] Enter your password: '
      self.password = ask("") { |q| q.echo = false }
      login_member()
    end
  end
  
  def save_userinfo
    self.info = {"name" => self.logon,"pass" => self.password, "guid" => self.guid, "token" => self.token}
    File.write self.filename, YAML.dump(self.info)
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
  attr_accessor :track_length
  
  def initialize( song_id )
    self.song_id = song_id
    self.success = true
    self.stream_pid = ""
  end
  
  def get_track_mediaurl (token)
    url = "https://playback.rhapsody.com/getContent.json?token=#{$app.encode(token)}&trackId=#{self.song_id}&pcode=rn&nimdax=true&mid=123"    
    @track_hash = JSON.parse(RestClient.get(url))
    if !@track_hash["data"]["mediaUrl"]
      puts @track_hash["status"]["errorMessage"]
      self.success = false
      puts "Setting false for get_track_mediaurl"
      return
    end
    self.mediaUrl = @track_hash["data"]["mediaUrl"]
    self.playbackSessionId = @track_hash["data"]["playbackSessionId"]
  end
  
  def start_session
    url = "http://rds-playback-prod-1201.sea2.rhapsody.com:8080/rhapsodydirectplayback/data/methods/startPlaybackSession.js?developerKey=#{$app.developerKey}&clientType=sonos&cobrandId=#{$app.cobrandId}&logon=#{$app.encode($app.user.logon)}&password=#{$app.encode($app.user.password)}"
    #http://rds-playback-prod-1201.sea2.rhapsody.com:8080/rhapsodydirectplayback/data/methods/startPlaybackSession.js?developerKey=4B8C5B7B5B7B5I4H&clientType=sonos&cobrandId=40134&logon=qa_5rrbrg%40rhapsody.lan&password=rhap123
    session_hash = JSON.parse(RestClient.get(url))
    puts session_hash
  end
  
  def get_radio_track
    url = "https://playback.rhapsody.com/nextTrack.json?channelId=#{$app.encode($app.current_station_id)}"    
    #token=&channelId=ps.8647878&playbackSessionId=&pcode=rn&nimdax=true
    track_hash = JSON.parse(RestClient.get(url))
    puts track_hash
=begin
    if !track_hash["data"]["mediaUrl"]
      puts track_hash["status"]["errorMessage"]
      self.success = false
      puts "Setting false for get_track_mediaurl"
      return
    end
    self.mediaUrl = @track_hash["data"]["mediaUrl"]
    self.playbackSessionId = @track_hash["data"]["playbackSessionId"]
=end
  end
  
  def get_track_metadata
    url = "http://direct.rhapsody.com/metadata/data/methods/getLiteTrack.js?developerKey=#{$app.developerKey}&cobrandId=#{$app.cobrandId}&filterRightsKey=0&trackId=#{self.song_id}"
    @metadata_hash = JSON.parse(RestClient.get(url))
    self.track_title = @metadata_hash["name"]
    self.track_artist = @metadata_hash["displayArtistName"]
    self.track_album = @metadata_hash["displayAlbumName"]
    self.track_num = @metadata_hash["trackIndex"]
    self.track_length = @metadata_hash["playbackSeconds"]
    puts "Track length is #{self.track_length} seconds"
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
        status = Open4::popen4("sh") do |pid, stdin, stdout, stderr|
          stdin.puts(cmdstring)
          stdin.close
          log = "stderr : #{stderr.read.strip }"
        end
        if !File.zero?("media/#{self.song_id}.flv")
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
      seg4 = $app.encode_amp(uri.query)
      seg3 = "mp3:#{pathsub2}?#{seg4}"
      cmdstring = %Q(r="#{seg1}"&a=#{seg2}&f="#{platform}"&b=20000000&W=#{mpswf}&y=#{seg3})
      string2 = URI.escape(cmdstring)
      #string3 = %Q(Mplayer_OLD -slave -cache 8192 -cache-min 4 "http://127.0.0.1:8902/?#{string2}")
      string4 = "http://127.0.0.1:8902/?#{string2}"
      #Mplayer_OLD::playstream(string4)
      #Mplayer_OLD = Mplayer_OLD.new(:path => string4, :message_style => :debug)
      #Mplayer_OLD.play
      #Mplayer_OLD.stop
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
    get_track_mediaurl ( $app.user.token) if self.success == true
    fetch_flv if self.success == true
    strip_mp3 if self.success == true
    put_track_metadata if self.success == true
    File.delete("media/#{self.song_id}.flv") if File.exists?("media/#{self.song_id}.flv")
    self.success
  end
  
  def play_stream
    puts "Getting mediaurl"
    get_track_mediaurl ( $app.user.token) if self.success == true
    puts "Got mediaurl"
    puts "Launching stream"
    stream_flv if self.success == true
    self.success
  end
  
  def download_and_play
    self.process
    #Mplayer_OLD.play("media/#{self.song_id}.mp3")
  end
  
  def pause
    #Mplayer_OLD.pause
  end
end

class Album
  
  attr_accessor :album_id
  attr_accessor :tracklist
  
  def initialize (album_id)
    self.album_id = album_id
    self.tracklist = []
  end
  
  def get_tracks
    url = "http://direct.rhapsody.com/metadata/data/methods/getAlbum.js?developerKey=#{$app.developerKey}&albumId=#{self.album_id}&cobrandId=#{$app.cobrandId}&filterRightsKey=0"
    metadata_obj = JSON.parse(RestClient.get(url))
    for i in 0..metadata_obj["trackMetadatas"].length-1
      x = Song.new(metadata_obj["trackMetadatas"][i]["trackId"])
      x.track_title = metadata_obj["trackMetadatas"][i]["name"]
      x.track_num = metadata_obj["trackMetadatas"][i]["trackIndex"]
      x.disc_num = metadata_obj["trackMetadatas"][i]["discIndex"]
      x.track_length = metadata_obj["trackMetadatas"][i]["playbackSeconds"]
      x.track_artist = metadata_obj["primaryArtist"]["name"]
      x.track_album = metadata_obj["displayName"]
      x.success = true
      self.tracklist << x      
    end
    count = 0
    self.tracklist.each do |a|       
      count += 1
      print "Get track #{"%02d" % count}) "
      puts "#{a.track_title} - #{a.track_length/60}:#{"%02d" % (a.track_length%60)}"  
      #a.process
    end
  end
  
  def play
    #vlc.play
    puts "need a player command here"
  end
end

class Station
  
  attr_accessor :station_id
  
  def initialize(id)
    self.station_id = id
  end
  
  def play
    $app.current_song = self.get_radio_track
    $app.next_song = self.get_radio_track
    #play current song
    #when song ends
    $app.current_song = $app.next_song
    $app.next_song = self.get_radio_track
    #play current song
  end
  
  def get_radio_track
    return
  end
    
end 
  

class Player
  def show(msg)
    #puts 'EXAMPLE<callbacks> ' + msg
  end


  def process_key(key)
    case key
    when 'q', 'Q' then @mplayer.stop
    when " "      then @mplayer.pause_or_unpause
    when "\e[A"   then @mplayer.seek_forward(60)     #    UP arrow
    when "\e[B"   then @mplayer.seek_reverse(60)     #  DOWN arrow
    when "\e[C"   then @mplayer.seek_forward         # RIGHT arrow
    when "\e[D"   then @mplayer.seek_reverse         #  LEFT arrow
    end
  end

  def read_keys
    x = IO.select([$stdin], nil, nil, 0.1)
    return if !x or x.empty?
    @key ||= ''
    @key << $stdin.read(1)
    if @key[0,1] != "\e" or @key.length >= 3
      process_key(@key)
      @key = ''
    end
  end
  


  def run!
    begin
      @mplayer.play
      
      tty_state = `stty -g`
      system "stty cbreak -echo"  
      read_keys while @mplayer.running?
    ensure
      system "stty #{tty_state}"
    end
  end
  
  def initialize(file)
    @mplayer = MPlayer.new( :path => file, :program => '/usr/local/bin/mplayer', :message_style => :quiet )

    @mplayer.callback :audio_stats do
      show "Audio is: "
      show "  ->    sample_rate: #{@mplayer.stats[:audio_sample_rate]} Hz"
      show "  -> audio_channels: #{@mplayer.stats[:audio_channels]}"
      show "  ->   audio_format: #{@mplayer.stats[:audio_format]}"
      show "  ->      data_rate: #{@mplayer.stats[:audio_data_rate]} kb/s"
    end
    
    @mplayer.callback :video_stats do
      show "Video is: "
      show "  -> fourCC: #{@mplayer.stats[:video_fourcc]}"
      show "  -> x_size: #{@mplayer.stats[:video_x_size]}"
      show "  -> y_size: #{@mplayer.stats[:video_y_size]}"
      show "  ->    bpp: #{@mplayer.stats[:video_bpp]}"
      show "  ->    fps: #{@mplayer.stats[:video_fps]}"
    end

    @mplayer.callback :position do |position|
      show "Song position percent: #{position}%"
    end

    @mplayer.callback :played_seconds do |val|
      total  = @mplayer.stats[:total_time]
      show "song position in seconds: #{val} / #{total}"
    end


    @mplayer.callback :pause, :unpause do |pause_state|
      show "song state: " + (pause_state ? "PAUSED!" : "RESUMED!") + "pause_state= #{pause_state}"
    end

    @mplayer.callback :play do
      show "song started!"
    end

    @mplayer.callback :stop do
      show "song ended!"
      #qputs "final stats were: #{@mplayer.stats.inspect}"
    end
  end
end


class App
  
  attr_accessor :user
  attr_accessor :song_id
  attr_accessor :album_id
  attr_accessor :current_song
  attr_accessor :next_song
  attr_accessor :running
  attr_accessor :answer
  attr_accessor :old_stty
  attr_accessor :appId
  attr_accessor :client_type
  attr_accessor :cobrandId
  attr_accessor :developerKey
  attr_accessor :menus
  attr_accessor :root_genres
  attr_accessor :current_menu
  attr_accessor :current_genre_id
  attr_accessor :current_station_id
  
  def initialize
    #self.song_id = "Tra.65319668" #Bad track for testing
    #self.song_id = "Tra.70625786" #New Bowie track
    self.song_id = "Tra.51845000" #Zeldo techno
    #self.song_id = "Tra.53550123" #Short Air track
    self.album_id = "Alb.53550113"
    self.user = Member.new
    self.current_song = Song.new(song_id)
    self.next_song = ""
    self.running = true
    self.answer = ""
    self.developerKey = "9H9H9E6G1E4I5E0I"
    self.cobrandId = "40134"
    self.client_type = "sonos"
    self.appId = "evans-awesome-app"
    self.old_stty = `stty -g` # store the current terminal settings
    self.menus = ["Genre Radio", "My Library", "My Playlists", "My Favorites", "My Radio", "Search for Artist, Album, or Track"]
    self.root_genres = JSON.parse(RestClient.get("http://direct.rhapsody.com/metadata/data/methods/getRootGenre.js?developerKey=#{self.developerKey}&cobrandId=#{self.cobrandId}&filterRightsKey=0"))
    self.current_menu = "main"
    self.current_genre_id = ""
    self.current_station_id = ""
  end
  
  def launch
    self.user.sign_in
    self.launch_rtmpgw
    self.encode("jham@rhapsody.com")
    self.encode("$ust9*ru")
    self.main_loop
  end
  
  def launch_mplayer
    player = Player.new
  end
  
  def launch_rtmpgw
    cmd_out = system "nohup rtmpgw -g 8902 > /dev/null 2>&1 & exit"
    puts"[i] Restreamer Ready..."
  end
  
  def encode(thing)
    URI.escape(thing,Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
  end

  def encode_amp(thing)
    URI.escape(thing, "&")
  end
  
=begin  
  def main_loop
    while self.running
      answer = ask("Type a command or press 'h' for help") do |q|
               q.echo      = false
               q.character = true
               #q.validate  = /\A[#{choices}]\Z/
             end
      if answer == "q" 
        #system "stty #{$app.old_stty}" # restore stty settings
        puts "Shutting down background processes..."
        puts 'Restreamer: kill!'
        puts "Mplayer_OLD: kill!"
        #Mplayer_OLD::kill()
        puts "KTHXBYE"
        self.running = false
      elsif answer == "d"
        self.current_song.get_track_metadata
        x = self.current_song.process
        puts "Download failed. Press \"d\" to try again" if !x
        puts "Ready to play: #{self.current_song.track_title}"
      elsif answer == "p"
        self.current_song.play_stream
      elsif answer == "s"
        puts "Mplayer_OLD: stop!"
        #Mplayer_OLD::stop()
      elsif answer == "t"
        #puts "player_test: play!"
        #Mplayer_OLD::play('Tra.70625786')
        Player.new('media/Tra.70625786.mp3').run!
      elsif answer == " "
        puts "Mplayer_OLD: toggle pause!"
        #Mplayer_OLD::toggle_pause()
      elsif answer == "a"
        album = Album.new(album_id)
        album.get_tracks
        #album.play
      else
        puts "Command not recognized."
      end
    end
  end
=end
  def main_loop
    while self.running
      case self.current_menu
        when 'main' then self.main_menu
        when 'genre_radio' then self.radio_menu
        when 'library' then self.library_menu
        when 'playlists' then self.playlists_menu
        when 'stations' then self.stations_menu
        when 'station_detail' then self.station_detail_menu
        else puts "[!] Can't find the menu you requested. Sorry."
      end
    end
  end
  
  def main_menu
    self.menus.each_index { |index| puts "    #{index+1}) #{self.menus[index]}"}
    print "[?] Enter Choice: "
    self.answer = gets().chomp
    case self.answer
      when '1' then self.current_menu = 'genre_radio'
      when '2' then self.current_menu = 'library'
      when '3' then self.current_menu = 'playlists'
      when '4' then puts "you hit #{self.answer}"
      when '5' then puts "you hit #{self.answer}"
      when '6' then puts "you hit #{self.answer}"
      when 'q' then self.running = false
      when 't' then self.current_song.start_session
      else          puts "[!] Not a valid choice. Try again"
    end
  end
  
  def radio_menu
    puts "[i] ...."
    puts "[i] Getting genre list..."
    puts "[i] ...."
    self.root_genres["childGenres"].each_index { |index| puts "    #{index+1}) #{self.root_genres["childGenres"][index]["name"]}"}
    print "[?] Select Genre: "
    self.answer = gets().chomp.to_i
    puts "[i] ...."
    puts "[i] Getting streaming stations in #{self.root_genres["childGenres"][self.answer-1]["name"]} "
    puts "[i] ...."
    self.current_genre_id = self.root_genres["childGenres"][self.answer-1]["genreId"]
    self.current_menu = 'stations'
  end
  
  def stations_menu
    list = JSON.parse(RestClient.get("http://direct.rhapsody.com/metadata/data/methods/getProgrammedStationsForGenre.js?developerKey=#{self.developerKey}&cobrandId=#{self.cobrandId}&end=&filterRightsKey=0&genreId=#{self.current_genre_id}&start="))
    list["stations"].each_index { |index| puts "    #{index+1}) #{list["stations"][index]["name"]}"}
    print "[?] Select Station: "
    self.answer = gets().chomp.to_i
    puts "[i] You selected #{list["stations"][self.answer-1]["name"]}"
    self.current_station_id = list["stations"][self.answer-1]["stationId"]
    self.current_menu = 'station_detail'
  end
  
  def station_detail_menu
    puts "    Okay play the station already! Station ID is #{self.current_station_id}"
    radio = Station.new(self.current_station_id)
    puts "Radio object id: "+radio.station_id
    self.answer = gets().chomp.to_i
    self.current_menu = 'main'
  end
  
  def library_menu
    puts "[i] This is the radio menu. Enter any key to go back to the main menu."
    self.answer = gets().chomp.to_i
    self.current_menu = 'main'
  end
  
  def playlists_menu
    puts "[i] This is the playlists menu. Enter any key to go back to the main menu."
    self.answer = gets().chomp.to_i
    self.current_menu = 'main'
  end
  
end

$app = App.new
$app.launch
