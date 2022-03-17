Do you write much throwaway code? I do. I often find myself needing to think in code for a bit to become familiar with a new API, or dig out some odd data in a system. This isn't necessarily code I'll ever share, and I may only use it for the next hour or the next few weeks. This is ad-hoc, workbench, junkbox code.

Since our company often works with Rails stack applications, I tend to write this throwaway code in Ruby. It's also a neat way to sneak ahead and try the latest Ruby releases and language features or try out a gem.

My key for throwaway code is to keep it a single source file, if possible. If the task is more complicated than a single file can hold for the moment then it might not be actual throwaway code. I've found Ruby to be nice for this: it's interpreted and scriptable. The Ruby ecosystem has lots of libraries packaged up as Rubygems. The first I reach for after installing Ruby is the Bundler gem, which manages dependencies for Ruby projects.

But wait, a single file with dependencies to manage? Using dependency managers usually imply additional package files and lock files, right? Well, Bundler provides a really nice [inlining feature](https://bundler.io/guides/bundler_in_a_single_file_ruby_script.html) that dispenses with shareable locking and separate package specifications in order to do just what we need here: keep it all in one file. Most importantly, reaching out to leverage other preexisting libraries is exactly how fit the functionalty you need into one file.

Most of the time my standline files pull in the following gems:

* Lightly, for local caching
* Pry, for debugging
* Sequel, for connecting to databases

I'd love to show you some of the throwaway code I've generated but unfortunately it's often heavily entangled with a customer's proprietary information. So, I've had to contrive something: let's, um, let's pull in a list of all US postal codes and play around.

First, of course, I had to _find_ a list of US postal codes. After for Google and Github searches, I found most libraries seemed to source their info from the http://www.geonames.org/ data set. So I'm going to the source here.

A plan comes together:

* pull the data from https://download.geonames.org/export/zip/
* extract it and import it
* do some data munging to stand in for really important use cases

Next is Googling about how to crack into this zip file (`[stream unzip ruby]`). Searching leads to a [nice Stack Overflow answer](https://stackoverflow.com/questions/33173266/ruby-download-zip-file-and-extract) which in turn led to the first version of our quick one-off file.

So, after some research:

* I ensure latest ruby is installed (3.1.1, I use asdf to manage that fwiw), cause single files are a chance to play with the latest.
* It's one file, but I still make a directory for this file to live in, so `mkdir ~/Projects/junk/fetchpostalcodes`
  * a containing directory for the file allows me to add source control later, gives me a place to throw related data files, etc
  * sometimes I have a special junk folder for a project and keep a collection of one-off tools in there
* `gem install bundler`
* and finally, edit the `fetchpostalcodes.rb` file

```ruby
require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'rubyzip', require: 'zip'
  gem 'pry'
end

require 'open-uri'

def get_zip_codes
  codes = []
  URI.open('https://download.geonames.org/export/zip/US.zip') do |content|
    Zip::File.open_buffer(content) do |zip|
      zip.each do |entry|
        if entry.name == 'US.txt'
          entry.get_input_stream do |is|
            is.each_line { codes << _1 }
          end
        end
      end
    end
  end

  codes
end

codes = get_zip_codes

puts codes.map { _1.split("\t")[4] }.uniq.sort.join(", ")

# google [stream unzip ruby]
# https://stackoverflow.com/questions/33173266/ruby-download-zip-file-and-extract

# https://download.geonames.org/export/zip/
# country code      : iso country code, 2 characters
# postal code       : varchar(20)
# place name        : varchar(180)
# admin name1       : 1. order subdivision (state) varchar(100)
# admin code1       : 1. order subdivision (state) varchar(20)
# admin name2       : 2. order subdivision (county/province) varchar(100)
# admin code2       : 2. order subdivision (county/province) varchar(20)
# admin name3       : 3. order subdivision (community) varchar(100)
# admin code3       : 3. order subdivision (community) varchar(20)
# latitude          : estimated latitude (wgs84)
# longitude         : estimated longitude (wgs84)
# accuracy          : accuracy of lat/lng from 1=estimated, 4=geonameid, 6=centroid of addresses or shape
# US      99553   Akutan  Alaska  AK      Aleutians East  013                     54.143  -165.7854       1
```

You'll notice I'm throwing a bunch of comments at the bottom, cause, well, this is quick throwaway code and keeping notes in the file itself means less switching.

I'm adding Pry so it's easy to play around and include a repl sandbox into my code. For example, when putting this together I wasn't sure what object that `zip.each do |entry|` was passing to me, so, I threw in a `binding.pry` to see what was up:

```ruby
    Zip::File.open_buffer(content) do |zip|
      zip.each do |entry|
        binding.pry
        if entry.name == 'US.txt'
```

That gives me a breakpoint to jump into the running system to play:

```
$ ruby fetchpostalcodes.rb 

From: /Users/darrend/Projects/journal/journal-single-file-ruby/fetchpostalcodes/fetchpostalcodes.rb:17 Object#get_zip_codes:

    16:       zip.each do |entry|
 => 17:         binding.pry
    18:         if entry.name == 'US.txt'

[1] pry(main)> entry.class
=> Zip::Entry
```

From there I can research the rubyzip docs and figure out how to use `Zip::Entry`. I can throw in a `binding.pry` after the `codes = get_zip_codes` line. This allows me to inspect the actual data I'm receiving:

```
[1] pry(main)> codes.first
=> "US\t99553\tAkutan\tAlaska\tAK\tAleutians East\t013\t\t\t54.143\t-165.7854\t1\n"
[2] pry(main)> codes.last
=> "US\t96863\tFPO AA\t\t\t\t\t\t\t21.4505\t-157.768\t4\n"
[3] pry(main)> puts codes.first
US      99553   Akutan  Alaska  AK      Aleutians East  013                     54.143  -165.7854       1
```

As you can see this is a very iterative process for me. I'll figure out one step, then move to the next. To speed up the runtime and to avoid hammering resources like databases or apis or the geonames.org website in this case, it's handy to pin results in place. In other words, cache results. I've found the [Lightly gem](https://github.com/DannyBen/lightly) to be a great simple local quick caching solution. Adding Lightly into our one-off code is easy: add the gem dependency, and then use it:

```ruby
  gemfile do
    source 'https://rubygems.org'
    gem 'lightly' 
```

```ruby
   codes = Lightly.get("get_zip_codes") { get_zip_codes }
```

It speeds up our code nicely as well

```
 $ time ruby fetchpostalcodes.rb 
, AK, AL, AR, AZ, CA, CO, CT, DC, DE, FL, GA...

real    0m2.699s
user    0m0.917s
sys     0m0.424s

0]darrend:fetchpostalcodes $ time ruby fetchpostalcodes.rb 
, AK, AL, AR, AZ, CA, CO, CT, DC, DE, FL, GA...

real    0m0.750s
user    0m0.506s
sys     0m0.269s
```

So, now I have an array of tab-separated values. How many? Hmm, one second:

```ruby
puts "#{codes.size} entries to be exact"
```

```
$ ruby fetchpostalcodes.rb
, AK, AL, AR, AZ, CA, CO, CT, DC, DE, FL, GA...
41483 entries to be exact
```

Apparently 41,483 entries to be exact. Maybe I turn these into structs for further filtering, or include the `sqlite` and `sequel` gems and push them into a database. All easy enough. 

Actually, what's that blank at the beginning of the list? I'll add a pry and see.

```
0]darrend:fetchpostalcodes $ ruby fetchpostalcodes.rb
From: /Users/darrend/Projects/journal/journal-single-file-ruby/fetchpostalcodes/fetchpostalcodes.rb:32 :

    31: puts "#{codes.size} entries to be exact"
 => 32: binding.pry

[1] pry(main)> codes.map { _1.split("\t")[4] }.uniq.sort.first
=> ""
[2] pry(main)> codes.map { _1.split("\t") }.select { _1[4] == ""}.first
=> ["US", "09001", "APO AA", "", "", "", "", "", "", "38.1105", "15.6613", "\n"]
[3] pry(main)> codes.map { _1.split("\t") }.select { _1[4] == ""}.last
=> ["US", "96863", "FPO AA", "", "", "", "", "", "", "21.4505", "-157.768", "4\n"]
```

That's interesting, I wonder what those are. Military bases? I'm off to Google...
