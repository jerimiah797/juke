require "highline/import"

running = true

puts "Welcome to the test"
puts "type \"q\" to exit"
answer = ""
choices = "ynaq"

while running
	answer = ask("") do |q|
           q.echo      = false
           q.character = true
           #q.validate  = /\A[#{choices}]\Z/
         end
	#say("You typed: #{answer}")
	puts "You typed #{answer}"
	if answer == "q" 
		puts "Shutting down"
		running = false
	end
end


