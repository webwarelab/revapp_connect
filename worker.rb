#!/usr/bin/env ruby

# == Synopsis
#
#   Synchronizes local directories with RevApp.
#   These folders will be created, if missing, and used for synchronizing:
#
#   videos: Contains videos to be uploaded to RevApp.
#   thumbs: Contains thumbnails of videos to be uploaded to RevApp.
#   xmlin: Contains xml files of videos to be uploaded to RevApp.
#   xmlout: Contains modified xml files downloaded from RevApp.
#
#
# == Usage
#
#   worker.rb [OPTION]
#
#   -h, --help                            show help
#   -c, --check                           downloads files only, no upload
#   -s [location], --server [location]    ftp location to connect to
#   -u [user], --user [user]              ftp user
#   -p [password], --password [password]  ftp password
#
#
# == Example
#
#   worker.rb -s myaccount.revapp.de -u myuser -p mypass

require "net/ftp"
require "fileutils"
require "getoptlong"
require "rdoc/usage"

opts = GetoptLong.new(
  [ "--help", "-h", GetoptLong::NO_ARGUMENT ],
  [ "--check", "-c", GetoptLong::NO_ARGUMENT ],
  [ "--server", "-s", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--user", "-u", GetoptLong::OPTIONAL_ARGUMENT ],
  [ "--password", "-p", GetoptLong::OPTIONAL_ARGUMENT ]
)

check_only = false
server ||= nil
user ||= nil
password ||= nil
opts.each do |opt, arg|
  case opt
    when "--help"
      RDoc::usage
    when "--check"
      check_only = true
    when "--server"
      server = arg
    when "--user"
      user = arg
    when "--password"
      password = arg
  end
end

class RevAppConnect
  class ConfigurationError < StandardError; end

  IN_FOLDERS = %w[xmlout]
  OUT_FOLDERS = %w[videos thumbs xmlin]
  TEXTFILES = %w[txt xml]
  DIR = File.dirname(__FILE__)

  attr_accessor :server, :user, :password, :ftp

  def initialize(attrs)
    self.server = attrs[:server]
    self.user = attrs[:user]
    self.password = attrs[:password]
    connect
  end

  def self.ensure_local_folders
    for folder in IN_FOLDERS + OUT_FOLDERS
      path = File.expand_path(File.join(DIR, folder))
      unless File.directory?(path)
        Dir.mkdir(path)
        puts "created folder #{path}"
      end
    end
  end

  def get_files
    for folder in IN_FOLDERS
      @ftp.chdir("/#{folder}")
      for file in @ftp.nlst
        puts "receiving: #{folder}/#{file}"
        get_file(file, folder)
        @ftp.delete(file)
      end
    end
  end
  alias :get :get_files

  def put_files
    for folder in OUT_FOLDERS
      @ftp.chdir("/#{folder}")
      for file in Dir[File.join(DIR, folder, "*.*")]
        puts "sending: #{file}"
        if wait_until_complete(file) == true
          put_file(file)
          FileUtils.rm(file)
        end
      end
    end
  end
  alias :put :put_files

  def exit
    @ftp.close
  end

  private

  def connect
    raise ConfigurationError, "FTP server location is missing! Provide option '-s [location]' when calling this script." unless server
    raise ConfigurationError, "FTP user is missing! Provide option '-u [user]' when calling this script." unless user
    raise ConfigurationError, "FTP password is missing! Provide option '-p [password]' when calling this script." unless password
    puts "Connecting to #{user}@#{server}..."
    @ftp = Net::FTP.new(server)
    @ftp.login(user, password)
  end

  def get_file(file, folder)
    local_path = File.join(DIR, folder, file)
    textfile?(file) ? @ftp.gettextfile(file, local_path) : @ftp.getbinaryfile(file, local_path)
  end

  def put_file(file)
    basename = File.basename(file)
    textfile?(file) ? @ftp.puttextfile(file, basename) : @ftp.putbinaryfile(file, basename)
  end

  def textfile?(file)
    file =~ /\.(.+)$/
    TEXTFILES.include?($1)
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

begin
  RevAppConnect.ensure_local_folders
  revapp = RevAppConnect.new(:server => server, :user => user, :password => password)
  revapp.get
  revapp.put unless check_only
  revapp.exit
  puts "Done!"
rescue RevAppConnect::ConfigurationError => e
  puts e.message
end
