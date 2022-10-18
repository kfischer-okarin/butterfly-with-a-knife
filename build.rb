#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'

require 'rubygems'
require 'bundler/setup'
require 'zip'

GAME_FOLDER_NAME = 'game'.freeze

def main
  build_game
  remove_build_directories
end

def build_game
  build_with_smaug
  ZipCreator.new.create_zips
end

def build_with_smaug
  system "smaug build -p #{game_folder}"
end

# Create release zip files
class ZipCreator
  def initialize
    metadata = read_metadata
    @version = metadata[:version]
    @gameid = metadata[:gameid]
  end

  def create_zips
    reset_output_directory
    create_windows_zip
    create_macos_zip
    create_linux_zip
    create_html5_zip
  end

  private

  def read_metadata
    metadata_lines = File.readlines(game_folder / 'metadata' / 'game_metadata.txt', chomp: true)

    {}.tap { |metadata|
      %i[version gameid].each do |key|
        line = metadata_lines.find { |l| l.include? key.to_s }
        metadata[key] = line.split('=')[1].strip
      end
    }
  end

  def reset_output_directory
    FileUtils.rm_rf 'dist'
    FileUtils.mkdir_p 'dist'
  end

  def create_windows_zip
    zip_file = dist_file("#{@gameid}-windows-v#{@version}.zip")
    Zip::File.open(zip_file, Zip::File::CREATE) do |zipfile|
      zipfile.add("#{@gameid}.exe", built_file("#{@gameid}-windows-amd64.exe"))
    end
  end

  def create_macos_zip
    FileUtils.mv(
      built_file("#{@gameid}-macos.zip"),
      dist_file("#{@gameid}-macos-v#{@version}.zip")
    )
  end

  def create_linux_zip
    zip_file = dist_file("#{@gameid}-linux-v#{@version}.zip")
    Zip::File.open(zip_file, Zip::File::CREATE) do |zipfile|
      zipfile.add("#{@gameid}.bin", built_file("#{@gameid}-linux-amd64.bin"))
    end
  end

  def create_html5_zip
    FileUtils.mv(
      built_file("#{@gameid}-html5.zip"),
      dist_file("#{@gameid}-html5.zip")
    )
  end
end

def remove_build_directories
  FileUtils.rm_rf Pathname(GAME_FOLDER_NAME) / 'builds'
  FileUtils.rm_rf 'tmp/demo'
end

def built_file(filename)
  game_folder / 'builds' / filename
end

def dist_file(filename)
  Pathname('dist') / filename
end

def game_folder
  Pathname(GAME_FOLDER_NAME)
end

main if $PROGRAM_NAME == __FILE__
