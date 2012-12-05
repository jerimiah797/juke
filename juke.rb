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
    #puts ("Logging you in with "+@logon+" and "+@password+".")
    #puts ("Validating user "+@logon+" ...")
    my_url = "http://rds-accountmgmt.internal.rhapsody.com/rhapsodydirectaccountmgmt/data/methods/authenticateMember.js?developerKey=#{$developerKey}&cobrandId=#{$cobrandId}&logon=#{URI.escape(@logon,Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&password=#{URI.escape(@password,Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}"
    my_hash = JSON.parse(RestClient.get(my_url))
    if my_hash["emailAddress"]==@logon
      @logged_in=true
      #puts "Login Successful for "+my_hash["emailAddress"]
      print "Login Successful. "
      puts "Welcome to Rhapsody!"
      puts my_hash
    else
      puts "Login Error: "+my_hash["localizedMessage"]
    end

  end
end


def initializeUser
  user = Member.new

  puts 'Welcome to Juke, the Rhapsody shell client'
  print 'Enter your username: '
  user.set_logon(gets().chomp)
  print 'Enter your password: '
  #user.set_password(gets().chomp)
  #user.set_password(STDIN.noecho(&:gets))
  user.set_password(ask("") { |q| q.echo = false })
  user.login_member()
end


#password_test = ask("Enter password: ") { |q| q.echo = false }
#print(password_test)
initializeUser






