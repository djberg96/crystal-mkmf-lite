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
    "-o #{cpp_executable}"
  end

  def cpp_libraries : String
    "-lrt -ldl -lcrypt -lm"
  end

  def cpp_executable : String
    "conftest.exe"
  end

  def common_headers : Array
    ["stdio.h", "stdlib.h"]
  end

  # Returns the sizeof `type` using `headers`, or common headers if no
  # headers are specified.
  #
  # If this method fails an error is raised. This could happen if the type
  # can't be found and/or the header files do not include the indicated type.
  #
  # Example:
  #
  #   class Foo
  #     include Mkmf::Lite
  #     utsname = check_sizeof('struct utsname', 'sys/utsname.h')
  #   end
  #
  def check_sizeof(type, headers : String | Array(String) = [] of String)
    headers = [headers] if headers.is_a?(String)
    headers = ["stdlib.h"] if headers.empty?

    io = IO::Memory.new
    ECR.embed("src/templates/check_sizeof.ecr", io)
    code = io.to_s

    try_to_execute(code)
  end

  # Check for the presence of the given +function+ in the common header
  # files, or within any +headers+ that you provide.
  #
  # Returns true if found, or false if not found.
  #
  def have_func(function, headers : String | Array(String) = [] of String)
    headers = [headers] if headers.is_a?(String)
    headers = common_headers if headers.empty?

    io_ptr = IO::Memory.new
    io_func = IO::Memory.new

    ptr_code = ECR.embed("src/templates/have_func_pointer.ecr", io_ptr)
    func_code = ECR.embed("src/templates/have_func.ecr", io_func)

    # Check for just the function pointer first. If that fails, then try
    # to compile with the function declaration.
    try_to_compile(ptr_code.to_s) || try_to_compile(func_code.to_s)
  end

  # Check for the presence of the given `header` file. You may optionally
  # provide a list of directories to search.
  #
  # Returns true if found, or false if not found.
  #
  def have_header(header : String, directories = [] of String) : Bool
    io = IO::Memory.new
    ECR.embed("src/templates/have_header.ecr", io)
    code = io.to_s

    if directories.empty?
      options = nil
    else
      options = ""
      directories.each{ |dir| options += "-I#{dir} " }
      options = options.rstrip
    end

    try_to_compile(code, options)
  end

  # Create a temporary bit of C source code in the temp directory, and
  # try to compile it. If it succeeds, return true. Otherwise, return
  # false.
  #
  def try_to_compile(code, command_options = nil)
    boolean = true

    puts code

    begin
      Dir.cd(Dir.tempdir){
        File.write(cpp_source_file, code)

        command = if command_options
          cpp_command + " " + command_options + " "
        else
          cpp_command + " "
        end

        command += cpp_out_file + " "
        command += cpp_source_file

        begin
          result = Process.run(command, shell: true, output: Process::Redirect::Close, error: Process::Redirect::Close)
          boolean = result.exit_code == 0
        rescue
          boolean = false
        end
      }
    ensure
      File.delete(cpp_source_file) if File.exists?(cpp_source_file)
    end

    boolean
  end

  # Create a temporary bit of C source code in the temp directory, and
  # try to compile it. If it succeeds attempt to run the generated code.
  # The code generated is expected to print a number to STDOUT, which
  # is then grabbed and returned as an integer.
  #
  # If the attempt to execute fails for any reason, then 0 is returned.
  #
  def try_to_execute(code)
    result = 0

    begin
      Dir.cd(Dir.tempdir){
        File.write(cpp_source_file, code)

        command  = cpp_command + " "
        command += cpp_out_file + " "
        command += cpp_source_file

        begin
          first_command = Process.run(command, shell: true, output: Process::Redirect::Close, error: Process::Redirect::Close)
          if first_command.exit_code == 0
            io = IO::Memory.new
            next_command = Process.run("./#{cpp_executable}", shell: true, output: io)
            if next_command.exit_code == 0
              result = io.to_s.to_i
            end
          end
        end
      }
    ensure
      File.delete(cpp_source_file) if File.exists?(cpp_source_file)
      File.delete(cpp_out_file) if File.exists?(cpp_out_file)
      File.delete(cpp_executable) if File.exists?(cpp_executable)
    end

    result
  end
end
