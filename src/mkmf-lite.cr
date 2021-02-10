require "ecr/macros"

module Mkmf::Lite
  VERSION = "0.1.0"

  def cpp_command
    cmd = Process.find_executable("cc") || Process.find_executable("gcc")
    raise "No compiler found" unless cmd
    cmd
  end

  def cpp_source_file : String
    "conftest.c"
  end

  def cpp_out_file : String
    "-o conftest.exe"
  end

  def cpp_libraries : String
    "-lrt -ldl -lcrypt -lm"
  end

  def have_header(header : String, directories = [] of String)
    io = IO::Memory.new
    ECR.embed("src/templates/have_header.ecr", io)
    template = io.to_s

    if directories.empty?
      options = nil
    else
      options = ""
      directories.each{ |dir| options += "-I#{dir} " }
      options = options.rstrip
    end

    try_to_compile(template, options)
  end

  def try_to_compile(code, command_options = nil)
    boolean = false

    Dir.cd(Dir.tempdir){
      File.write(cpp_source_file, code)

      command = if command_options
        cpp_command + " " + command_options + " "
      else
        cpp_command + " "
      end

      command += cpp_out_file + " "
      command += cpp_source_file

      boolean = system(command)
    }
  end
end

class Stuff
  include Mkmf::Lite
end

stuff = Stuff.new
stuff.have_header("sys/uname.h")
