require "ecr/macros"

module Mkmf::Lite
  VERSION = "0.2.0"

  @cpp_command : String?
  @cpp_libraries : String?
  @cpp_library_paths : String?
  @mkmf_lite_cache : Hash(String, Bool | Int32)?

  def cpp_command
    @cpp_command ||= Process.find_executable("cc") || Process.find_executable("gcc") || Process.find_executable("clang") || Process.find_executable("cl") || raise("No compiler found")
  end

  def cpp_source_file : String
    "conftest.c"
  end

  def cpp_executable : String
    "conftest.exe"
  end

  def cpp_out_file : String
    "-o #{cpp_executable}"
  end

  def cpp_libraries : String?
    return nil if windows_with_cl_compiler? || darwin?

    @cpp_libraries ||= "-lrt -ldl -lcrypt -lm"
  end

  def cpp_library_paths : String?
    @cpp_library_paths ||= begin
      paths = [] of String
      paths << "-L/opt/homebrew/lib" if File.directory?("/opt/homebrew/lib")
      paths << "-L/usr/local/lib" if File.directory?("/usr/local/lib")
      paths.empty? ? nil : paths.join(" ")
    end
  end

  def cpp_defs : String?
    nil
  end

  def common_headers : Array(String)
    ["stdio.h", "stdlib.h"]
  end

  # Returns the sizeof `type` using `headers`, or common headers if no
  # headers are specified.
  #
  # If this method fails an error is raised. This could happen if the type
  # can't be found and/or the header files do not include the indicated type.
  #
  # You may optionally provide include `directories` to search.
  #
  # Example:
  #
  #   class Foo
  #     include Mkmf::Lite
  #     utsname = check_sizeof("struct utsname", "sys/utsname.h")
  #   end
  def check_sizeof(type, headers : String | Array(String) = [] of String, directories = [] of String)
    headers = get_header_string(headers)

    memoize("check_sizeof:#{type}:#{headers.join(",")}:#{normalize_directories(directories).join(",")}") do
      io = IO::Memory.new
      ECR.embed("src/templates/check_sizeof.ecr", io)
      code = io.to_s

      try_to_execute(code, build_directory_options(directories))
    end.as(Int32)
  end

  # Returns the value of the given `constant` (which could also be a macro)
  # using `headers`, or common headers if no headers are specified.
  #
  # If this method fails an error is raised. This could happen if the constant
  # can't be found and/or the header files do not include the indicated constant.
  #
  # You may optionally provide include `directories` to search.
  def check_valueof(constant, headers : String | Array(String) = [] of String, directories = [] of String)
    headers = get_header_string(headers)

    memoize("check_valueof:#{constant}:#{headers.join(",")}:#{normalize_directories(directories).join(",")}") do
      io = IO::Memory.new
      ECR.embed("src/templates/check_valueof.ecr", io)
      code = io.to_s

      try_to_execute(code, build_directory_options(directories))
    end.as(Int32)
  end

  # Returns the offset of `field` within `struct_type` using `headers`,
  # or common headers, plus `stddef.h`, if no headers are specified.
  #
  # If this method fails an error is raised. This could happen if the field
  # can't be found and/or the header files do not include the indicated type.
  # It will also fail if the field is a bit field.
  #
  # You may optionally provide include `directories` to search.
  #
  # Example:
  #
  #   class Foo
  #     include Mkmf::Lite
  #     utsname = check_offsetof("struct utsname", "release", "sys/utsname.h")
  #   end
  def check_offsetof(struct_type, field, headers : String | Array(String) = [] of String, directories = [] of String)
    headers = get_header_string(headers)

    memoize("check_offsetof:#{struct_type}:#{field}:#{headers.join(",")}:#{normalize_directories(directories).join(",")}") do
      io = IO::Memory.new
      ECR.embed("src/templates/check_offsetof.ecr", io)
      code = io.to_s

      try_to_execute(code, build_directory_options(directories))
    end.as(Int32)
  end

  # Check for the presence of the given `function` in the common header
  # files, or within any `headers` that you provide.
  #
  # Returns `true` if found, or `false` if not found.
  def have_func(function, headers : String | Array(String) = [] of String) : Bool
    headers = get_header_string(headers)

    memoize("have_func:#{function}:#{headers.join(",")}") do
      io_ptr = IO::Memory.new
      io_func = IO::Memory.new

      ECR.embed("src/templates/have_func_pointer.ecr", io_ptr)
      ECR.embed("src/templates/have_func.ecr", io_func)

      try_to_compile(io_ptr.to_s) || try_to_compile(io_func.to_s)
    end.as(Bool)
  end

  # Check for the presence of the given `header` file. You may optionally
  # provide a list of include `directories` to search.
  #
  # Returns `true` if found, or `false` if not found.
  def have_header(header : String, directories = [] of String) : Bool
    memoize("have_header:#{header}:#{normalize_directories(directories).join(",")}") do
      io = IO::Memory.new
      ECR.embed("src/templates/have_header.ecr", io)
      code = io.to_s

      try_to_compile(code, build_directory_options(directories))
    end.as(Bool)
  end

  # Check for the presence of the given `library`. You may optionally
  # provide a `function` name to check for within that library, as well
  # as any additional `headers`.
  #
  # Returns `true` if the library can be linked, or `false` otherwise.
  #
  # Note: The library name should not include the `lib` prefix or file
  # extension. For example, use `xerces-c` not `libxerces-c` or
  # `libxerces-c.dylib`. However, if the `lib` prefix is provided,
  # it will be automatically stripped on non-Windows compilers.
  def have_library(library, function = nil, headers : String | Array(String) = [] of String) : Bool
    library = library.sub(/^lib/, "") unless windows_with_cl_compiler?
    headers = get_header_string(headers)

    memoize("have_library:#{library}:#{function}:#{headers.join(",")}") do
      io = IO::Memory.new
      ECR.embed("src/templates/have_library.ecr", io)
      code = io.to_s
      library_option = windows_with_cl_compiler? ? "#{library}.lib" : "-l#{library}"

      try_to_compile(code, nil, library_option)
    end.as(Bool)
  end

  # Checks whether or not the struct of type `struct_type` contains the
  # `struct_member`. If it does not, or the struct type cannot be found,
  # then `false` is returned.
  #
  # An optional list of `headers` may be specified, in addition to the
  # common header files that are already searched.
  #
  # Example:
  #
  #   class Foo
  #     include Mkmf::Lite
  #     st_uid = have_struct_member("struct stat", "st_uid", "sys/stat.h")
  #   end
  def have_struct_member(struct_type, struct_member, headers : String | Array(String) = [] of String) : Bool
    headers = get_header_string(headers)

    memoize("have_struct_member:#{struct_type}:#{struct_member}:#{headers.join(",")}") do
      io = IO::Memory.new
      ECR.embed("src/templates/have_struct_member.ecr", io)
      code = io.to_s

      try_to_compile(code)
    end.as(Bool)
  end

  # Create a temporary bit of C source code in the temp directory, and
  # try to compile it. If it succeeds, return `true`. Otherwise, return
  # `false`.
  def try_to_compile(code, command_options = nil, library_options = nil) : Bool
    boolean = true

    begin
      Dir.cd(Dir.tempdir) {
        File.write(cpp_source_file, code)

        command = build_compile_command(command_options, library_options)

        begin
          result = Process.run(command, shell: true, output: Process::Redirect::Close, error: Process::Redirect::Close)
          boolean = result.exit_code == 0
        rescue
          boolean = false
        end
      }
    ensure
      File.delete(cpp_source_file) if File.exists?(cpp_source_file)
      File.delete(cpp_executable) if File.exists?(cpp_executable)
    end

    boolean
  end

  # Create a temporary bit of C source code in the temp directory, and
  # try to compile it. If it succeeds, attempt to run the generated code.
  # The code generated is expected to print a number to STDOUT, which
  # is then returned as an integer.
  #
  # If compilation fails, an error is raised.
  def try_to_execute(code, command_options = nil) : Int32
    result = 0

    begin
      Dir.cd(Dir.tempdir) {
        File.write(cpp_source_file, code)

        command = build_compile_command(command_options)

        first_command = Process.run(command, shell: true, output: Process::Redirect::Close, error: Process::Redirect::Close)
        unless first_command.exit_code == 0
          raise "Failed to compile source code with command '#{command}':\n===\n#{code}\n==="
        end

        io = IO::Memory.new
        next_command = Process.run("./#{cpp_executable}", shell: true, output: io, error: Process::Redirect::Close)
        if next_command.exit_code == 0
          result = io.to_s.to_i
        end
      }
    ensure
      File.delete(cpp_source_file) if File.exists?(cpp_source_file)
      File.delete(cpp_executable) if File.exists?(cpp_executable)
    end

    result
  end

  private def memoize(key : String, &)
    cache = (@mkmf_lite_cache ||= {} of String => Bool | Int32)
    return cache[key] if cache.has_key?(key)

    value = yield
    cache[key] = value
    value
  end

  private def build_compile_command(command_options = nil, library_options = nil) : String
    parts = [] of String
    parts << cpp_command
    parts << command_options if command_options

    if library_paths = cpp_library_paths
      parts << library_paths
    end

    if libraries = cpp_libraries
      parts << libraries
    end

    if defs = cpp_defs
      parts << defs
    end

    parts << cpp_out_file
    parts << cpp_source_file
    parts << library_options if library_options
    parts.join(" ")
  end

  private def build_directory_options(directories) : String?
    dirs = normalize_directories(directories)
    return nil if dirs.empty?

    dirs.map { |dir| "-I#{dir}" }.join(" ")
  end

  private def normalize_directories(directories) : Array(String)
    case directories
    when String
      [directories]
    when Array(String)
      directories
    else
      [] of String
    end
  end

  private def get_header_string(headers : String | Array(String) = [] of String) : Array(String)
    headers = [headers] if headers.is_a?(String)
    headers = common_headers if headers.empty?
    headers.flatten.uniq
  end

  private def windows_with_cl_compiler? : Bool
    command = cpp_command
    command.ends_with?("cl") || command.ends_with?("cl.exe")
  end

  private def darwin? : Bool
    {% if flag?(:darwin) %}
      true
    {% else %}
      false
    {% end %}
  end
end
