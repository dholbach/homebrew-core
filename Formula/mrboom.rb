class Mrboom < Formula
  desc "Eight player Bomberman clone"
  homepage "http://mrboom.mumblecore.org/"
  url "https://github.com/Javanaise/mrboom-libretro/archive/4.8.tar.gz"
  sha256 "ca41016ced65840d364556ba7477f1d1af2d5b72c98dd1bdf406bea75ad28b71"

  bottle do
    cellar :any
    sha256 "154f40d61ea23fa239392be94ebfa6387edc23693eb1be741da2857f749d3e30" => :catalina
    sha256 "4ba2c8e5e221b0caede7a888554151b21f66cf1dcb0a656b6f311f62f406a788" => :mojave
    sha256 "1508a8b273950f25e649b809a696a58b2fdc17a8cf13114ff117719d8bf1f95a" => :high_sierra
    sha256 "171552ccf311dddbcf124c8f17d424f10d54e48312dffdd8fc3b906e6c700e87" => :sierra
  end

  depends_on "cmake" => :build
  depends_on "libmodplug"
  depends_on "minizip"
  depends_on "sdl2"
  depends_on "sdl2_mixer"

  def install
    system "make", "mrboom", "LIBSDL2=1"
    system "make", "install", "PREFIX=#{prefix}"
  end

  test do
    require "pty"
    require "expect"
    require "timeout"
    PTY.spawn(bin/"mrboom", "-m", "-f 0", "-z") do |r, _w, pid|
      sleep 1
      Process.kill "SIGINT", pid
      assert_match "monster", r.expect(/monster/, 10)[0]
    ensure
      begin
        Timeout.timeout(10) do
          Process.wait pid
        end
      rescue Timeout::Error
        Process.kill "KILL", pid
      end
    end
  end
end
