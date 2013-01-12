
require 'json'
require 'rest-client'


=begin
class Dog
  def set_name( aName )
    @myname = aName
  end
  def get_name
    return @myname
  end
  def talk
    return 'woof!'
  end
end

mydog = Dog.new
yourdog = Dog.new
mydog.set_name( 'Fido')
yourdog.set_name('Bonzo')

puts ("My dog is named "+mydog.get_name)
puts ("My dog says "+mydog.talk)
puts ("Your dog is named "+yourdog.get_name)
puts ("Your dog says "+yourdog.talk)
=end

login = "jham@rhapsody.com"
pass = "$ust9*ru"

puts(URI.encode(login,Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")))
puts(URI.encode(pass,Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")))





  # Start playing a file
  puts "starting playback"
  vlc.media = "media/#{song_id}.mp3"

  #wait
  puts "waiting 15 sec"
  sleep 15

  # Stop the file
  puts "stopping playback"
  vlc.playing = false

  # Close VLC
  puts "closing vlc instance"
  vlc.exit