#!/usr/bin/env ruby

require 'net/ftp'
require 'fileutils'
require 'getoptlong'
#require 'rdoc/usage'

# == Usage
    #
    # worker.rb [OPTION]
    #
    # -h, --help:
    #    show help

opts = GetoptLong.new(
  [ '--check', '-c', GetoptLong::NO_ARGUMENT ]
)

check_only = false

opts.each do |opt, arg|
 case opt
   # when '--help'
   #   RDoc::usage
   when '--check'
     check_only = true
 end
end


class RevAppConnect
  
  attr_reader :server, :username, :password
  attr_accessor :ftp

  def initialize
    # @server = 'jan.webware.info'
    # @username = 'janlogin'
    # @password = 'janpass'
    @server = 'endemol.revapp.de'
    @username = 'endemol'
    @password = 'gg28kUhebbfo9'
    
    @in_folders = %w(xmlout)
    @out_folders = %w(videos thumbs xmlin)  
    @textfiles = %w(txt xml)
    
    @local_folder = File.dirname(__FILE__)
    connect
  end
  
  def get
    get_files
  end
  
  def put
    put_files
  end
  
  def get_files
    for folder in @in_folders
      @ftp.chdir("/#{folder}")
      for file in @ftp.nlst
        puts "receiving: #{folder}/#{file}"
        get_file(file, folder)
        @ftp.delete(file)
      end
    end
  end
  
  def put_files
    for folder in @out_folders
      @ftp.chdir("/#{folder}")
      for file in Dir[File.join(@local_folder, folder, '*.*')]
        puts "sending: #{file}"
        if wait_until_complete(file) == true
          put_file(file)
          FileUtils.rm(file)
        end
      end
    end
  end
  
  def exit
    @ftp.close
  end
  
  private
  
    def connect
      puts "Connecting to #{@username}@#{@server}..."
      @ftp = Net::FTP.new(@server)
      @ftp.passive = true
      @ftp.debug_mode = true 
      @ftp.login(@username, @password)
    end
    
    def get_file(file, folder)
      local_path = File.join(@local_folder, folder, file)
      textfile?(file) ? @ftp.gettextfile(file, local_path) : @ftp.getbinaryfile(file, local_path)
    end
    
    def put_file(file)
      basename = File.basename(file)
      textfile?(file) ? @ftp.puttextfile(file, basename) : @ftp.putbinaryfile(file, basename)
    end
    
    def textfile?(file)
      file =~ /\.(.+)$/
      @textfiles.include?($1)
    end
    
    # Waits until local file is complete
    def wait_until_complete(path, timeout = 10)
      return unless path.is_a?(String)
      wait = 1 # seconds to wait for file size to change
      time = 0
      size = 0
      while true
        return false if time >= timeout
        s = File.size(path)
        return true if s == size and size > 0
        size = s
        sleep(wait)
        time += wait
      end
    end
end

revapp = RevAppConnect.new
revapp.get 
revapp.put unless check_only
revapp.exit

puts 'Done!'
