# encoding: utf-8

require 'mkmf'
require 'pathname'

def sys(cmd, err_msg)
  p cmd
  system(cmd) || fail(err_msg)
end

def fail(msg)
  STDERR.puts msg
  exit(1)
end

RbConfig::MAKEFILE_CONFIG['CC'] = ENV['CC'] if ENV['CC']

# XXX fallbacks specific to Darwin for JRuby (does not set these values in RbConfig::CONFIG)
LIBEXT = RbConfig::CONFIG['LIBEXT'] || 'a'
DLEXT = RbConfig::CONFIG['DLEXT'] || 'bundle'

cwd = Pathname(File.expand_path(File.dirname(__FILE__)))
dst_path = cwd + 'dst'
libs_path = dst_path + 'lib'
vendor_path = cwd + '..'
zmq_path = vendor_path + 'zeromq'
czmq_path = vendor_path + 'czmq'
libsodium_path = vendor_path + 'libsodium'
zmq_include_path = zmq_path + 'include'
czmq_include_path = czmq_path + 'include'
libsodium_include_path = libsodium_path + 'src/libsodium/include'

# Fail early if we don't meet the following dependencies.

# Courtesy of EventMachine and @tmm1
def check_libs libs = [], fatal = false
  libs.all? { |lib| have_library(lib) || (abort("could not find library: #{lib}") if fatal) }
end

def check_heads heads = [], fatal = false
  heads.all? { |head| have_header(head) || (abort("could not find header: #{head}") if fatal)}
end

CZMQ_CFLAGS = %w(-g)

# Disable depricated declarations error for gcc 6
CZMQ_CFLAGS << "-Wno-deprecated-declarations"

out = `gcc -dumpversion`
if $?.exitstatus == 0
    # It is constructed as follows MAJOR.MINOR.PATCH
    major_gcc_ver = out.chomp.split(".").first

    # Disable format-truncation warnings treated as errors - gcc 7 and higher
    CZMQ_CFLAGS << "-Wno-error=format-truncation=" if major_gcc_ver.to_i >= 7
end

case RUBY_PLATFORM
when /mswin32/, /mingw32/, /bccwin32/
  check_heads(%w[windows.h winsock.h], true)
  check_libs(%w[kernel32 rpcrt4 gdi32], true)

  if GNU_CHAIN
    CONFIG['LDSHARED'] = "$(CXX) -shared -lstdc++"
  else
    $defs.push "-EHs"
    $defs.push "-GR"
  end

when /solaris/

  if CONFIG['CC'] == 'cc' and `cc -flags 2>&1` =~ /Sun/ # detect SUNWspro compiler
    # SUN CHAIN
    $preload = ["\nCXX = CC"] # hack a CXX= line into the makefile
    $CFLAGS = CONFIG['CFLAGS'] = "-KPIC"
    CONFIG['CCDLFLAGS'] = "-KPIC"
    CONFIG['LDSHARED'] = "$(CXX) -G -KPIC -lCstd"
  else
    # GNU CHAIN
    # on Unix we need a g++ link, not gcc.
    CONFIG['LDSHARED'] = "$(CXX) -shared"
  end
  CZMQ_CFLAGS << "-fPIC"

when /openbsd/
  # OpenBSD branch contributed by Guillaume Sellier.

  # on Unix we need a g++ link, not gcc. On OpenBSD, linking against libstdc++ have to be explicitly done for shared libs
  CONFIG['LDSHARED'] = "$(CXX) -shared -lstdc++ -fPIC"
  CONFIG['LDSHAREDXX'] = "$(CXX) -shared -lstdc++ -fPIC"

when /darwin/
  # on Unix we need a g++ link, not gcc.
  # Ff line contributed by Daniel Harple.
  CONFIG['LDSHARED'] = "$(CXX) " + CONFIG['LDSHARED'].split[1..-1].join(' ')

when /aix/
  CONFIG['LDSHARED'] = "$(CXX) -shared -Wl,-G -Wl,-brtl"

when /linux/
  CZMQ_CFLAGS << "-fPIC"

else
  # on Unix we need a g++ link, not gcc.
  CONFIG['LDSHARED'] = "$(CXX) -shared"
end

# if bundling from git, do a git checkout:
unless File.exist?(zmq_path + 'autogen.sh')
  sys "cd ../.. && git submodule update --init", "Checking out git submodules error!"
end

# build libsodium
if with_config('system-libs')
  $stderr.puts "Warning -- using system version of libsodium."
else
  lib = libs_path + "libsodium.#{LIBEXT}"
  Dir.chdir libsodium_path do
    sys "pwd", "pwd"
    sys "./autogen.sh", "LibSodium autogen failed!" unless File.exist?(libsodium_path + 'configure')
    sys "./configure --prefix=#{dst_path} --without-documentation --enable-shared",
        "LibSodium configure failed" unless File.exist?(libsodium_path + 'Makefile')
    sys "make -j && make install", "LibSodium compile error!"
  end #unless File.exist?(lib)
end

# build libzmq
if with_config('system-libs')
  $stderr.puts "Warning -- using system version of libzmq."
else
  lib = libs_path + "libzmq.#{LIBEXT}"
  Dir.chdir zmq_path do
    sys "pwd", "pwd"
    sys "./autogen.sh", "ZeroMQ autogen failed!" unless File.exist?(zmq_path + 'configure')
    sys "./configure --prefix=#{dst_path} --without-documentation --enable-shared --without-libsodium ",
        "ZeroMQ configure failed" unless File.exist?(zmq_path + 'Makefile')
    sys "make -j && make install", "ZeroMQ compile error!"
  end #unless File.exist?(lib)
end

# build libczmq
if with_config('system-libs')
  $stderr.puts "Warning -- using system version of libczmq."
else
  lib = libs_path + "libczmq.#{LIBEXT}"
  Dir.chdir czmq_path do
    sys "pwd", "pwd"
    sys "./autogen.sh", "CZMQ autogen failed!" unless File.exist?(czmq_path + 'configure')
    sys "./configure LDFLAGS=-L#{libs_path} CFLAGS='#{CZMQ_CFLAGS.join(" ")}' --prefix=#{dst_path} --with-libzmq=#{dst_path} --disable-shared --without-libsodium", #--with-libsodium=#{dst_path}
        "CZMQ configure error!" unless File.exist?(czmq_path + 'Makefile')
    sys "make -j all && make install", "CZMQ compile error!"
  end #unless File.exist?(lib)
end

dir_config('rbczmq')

have_header('ruby/thread.h')
have_func('rb_thread_blocking_region')
have_func('rb_thread_call_without_gvl')

$INCFLAGS << " -I#{zmq_include_path}" if find_header("zmq.h", zmq_include_path)
$INCFLAGS << " -I#{czmq_include_path}" if find_header("czmq.h", czmq_include_path)

$LIBPATH << libs_path.to_s

# Special case to prevent Rubinius compile from linking system libzmq if present
if defined?(RUBY_ENGINE) && RUBY_ENGINE =~ /rbx/ && RUBY_PLATFORM =~ /linux/
  CONFIG['LDSHARED'] = "#{CONFIG['LDSHARED']} -Wl,-rpath=#{libs_path.to_s}"
end

fail "Error compiling and linking libzmq" unless have_library("zmq")
fail "Error compiling and linking libczmq" unless have_library("czmq")

$CFLAGS << ' -Wall -funroll-loops -std=c99 -Wno-error=format-security -Wno-pedantic'
$CFLAGS << ' -Wextra -O0 -ggdb3' if ENV['DEBUG']

create_makefile('rbczmq_ext')
