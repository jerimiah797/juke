=begin
This program is an attempt to interface with the Rhapsody APIs for basic playback from the command shell.
I have no idea what I'm doing.

=end

require 'json'
require 'rest-client'
require 'uri'
require 'highline/import'
#require 'io/console'


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
      puts "Data returned for "+@auth_hash["emailAddress"]
      print "Login Successful. "
      puts "Welcome to Rhapsody!"
      puts @auth_hash
      puts "*****************"
      @token = @token_hash["value"]
      puts "token = #{@token}"
      puts "encoded token = #{encode(@token)}"
    else
      puts "Login Error: "+@auth_hash["localizedMessage"]
    end
  end
  def get_track
    get_track_url = "https://playback.rhapsody.com/getContent.json?token=#{encode(@token)}&trackId=Tra.12276919&pcode=rn&nimdax=true&mid=123"
    
    @track_hash = JSON.parse(RestClient.get(get_track_url))
    puts @track_hash
  end
end

def encode(thing)
  URI.escape(thing,Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
end
  
def initializeUser
  @user = Member.new

  puts 'Welcome to Juke, the Rhapsody shell client'
  print 'Enter your username: '
  @user.set_logon(gets().chomp)
  print 'Enter your password: '
  @user.set_password(ask("") { |q| q.echo = false })
  @user.login_member()
end



initializeUser
@user.get_track





